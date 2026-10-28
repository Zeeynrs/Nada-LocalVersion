"""Fast local audio metadata & cover art scanner with SQLite caching."""

import hashlib
import json
import os
import shutil
import sqlite3
import struct
import subprocess
import time
from pathlib import Path
from urllib.parse import quote

from .config import COVERS_DIR, DB_FILE

AUDIO_EXTS = {
    ".flac", ".mp3", ".opus", ".ogg", ".m4a", ".aac",
    ".wav", ".wv", ".ape", ".alac", ".dsf", ".dff", ".oga",
}
PLAYLIST_EXTS = {".m3u", ".m3u8"}
COVER_FILENAMES = (
    "cover.jpg", "cover.jpeg", "cover.png", "cover.webp",
    "folder.jpg", "folder.jpeg", "folder.png",
    "front.jpg", "front.png", "album.jpg", "album.png",
)


def file_uri(path: str | Path) -> str:
    p = str(Path(path).resolve())
    return "file://" + quote(p, safe="/:@!$&'()*+,;=-._~")


def stable_id(prefix: str, text: str) -> str:
    h = hashlib.sha1(text.strip().lower().encode("utf-8", errors="ignore")).hexdigest()[:16]
    return f"{prefix}_{h}"


def _save_cover_bytes(data: bytes, key_hint: str) -> str:
    if not data or len(data) < 64:
        return ""
    COVERS_DIR.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha1(data[:4096] + str(len(data)).encode()).hexdigest()[:20]
    ext = ".png" if data[:8] == b"\x89PNG\r\n\x1a\n" else ".jpg"
    out = COVERS_DIR / f"{digest}{ext}"
    if not out.exists():
        try:
            out.write_bytes(data)
        except OSError:
            return ""
    return file_uri(out)


def _find_folder_cover(folder: Path) -> str:
    try:
        entries = {p.name.lower(): p for p in folder.iterdir() if p.is_file()}
    except OSError:
        return ""
    for candidate in COVER_FILENAMES:
        if candidate in entries:
            return file_uri(entries[candidate])
    for name, p in entries.items():
        if name.endswith((".jpg", ".jpeg", ".png", ".webp")):
            return file_uri(p)
    return ""


# ---- Native fast binary parsers (FLAC & ID3v2) + Mutagen + ffprobe ----------

def _parse_flac_native(path: Path) -> dict | None:
    try:
        with open(path, "rb") as f:
            if f.read(4) != b"fLaC":
                return None
            meta = {"tags": {}, "duration_ms": 0, "sample_rate": 0, "bits_per_sample": 0, "cover": b""}
            while True:
                hdr = f.read(4)
                if len(hdr) < 4:
                    break
                is_last = (hdr[0] & 0x80) != 0
                block_type = hdr[0] & 0x7F
                length = int.from_bytes(hdr[1:4], "big")
                body = f.read(length)
                if len(body) < length:
                    break
                if block_type == 0 and length >= 34:  # STREAMINFO
                    sr_ch_bps = int.from_bytes(body[10:18], "big")
                    sample_rate = (sr_ch_bps >> 44) & 0xFFFFF
                    bps = ((sr_ch_bps >> 36) & 0x1F) + 1
                    total_samples = sr_ch_bps & 0xFFFFFFFFF
                    meta["sample_rate"] = sample_rate
                    meta["bits_per_sample"] = bps
                    if sample_rate > 0 and total_samples > 0:
                        meta["duration_ms"] = int((total_samples * 1000) / sample_rate)
                elif block_type == 4 and length >= 8:  # VORBIS_COMMENT
                    pos = 0
                    vendor_len = struct.unpack_from("<I", body, pos)[0]
                    pos += 4 + vendor_len
                    if pos + 4 <= len(body):
                        count = struct.unpack_from("<I", body, pos)[0]
                        pos += 4
                        for _ in range(count):
                            if pos + 4 > len(body):
                                break
                            clen = struct.unpack_from("<I", body, pos)[0]
                            pos += 4
                            raw = body[pos:pos + clen].decode("utf-8", errors="replace")
                            pos += clen
                            if "=" in raw:
                                k, v = raw.split("=", 1)
                                meta["tags"][k.strip().upper()] = v.strip()
                elif block_type == 6 and not meta["cover"] and length > 32:  # PICTURE
                    pos = 4  # picture type
                    mime_len = struct.unpack_from(">I", body, pos)[0]
                    pos += 4 + mime_len
                    if pos + 4 <= len(body):
                        desc_len = struct.unpack_from(">I", body, pos)[0]
                        pos += 4 + desc_len + 16
                        if pos + 4 <= len(body):
                            data_len = struct.unpack_from(">I", body, pos)[0]
                            pos += 4
                            meta["cover"] = body[pos:pos + data_len]
                if is_last:
                    break
            return meta
    except Exception:
        return None


def _extract_with_mutagen(path: Path) -> dict | None:
    try:
        import mutagen
    except ImportError:
        return None
    try:
        audio = mutagen.File(str(path), easy=False)
        if audio is None:
            return None
        info = getattr(audio, "info", None)
        duration_ms = int(getattr(info, "length", 0) * 1000) if info else 0
        bitrate = int(getattr(info, "bitrate", 0) // 1000) if info and getattr(info, "bitrate", 0) else 0
        sample_rate = int(getattr(info, "sample_rate", 0)) if info else 0
        tags = {}
        cover_bytes = b""

        if hasattr(audio, "pictures") and audio.pictures:
            cover_bytes = audio.pictures[0].data

        raw_tags = getattr(audio, "tags", None)
        if raw_tags:
            # ID3 frames
            if hasattr(raw_tags, "values"):
                for k, v in raw_tags.items():
                    ku = str(k).upper()
                    if ku.startswith("APIC") and hasattr(v, "data") and not cover_bytes:
                        cover_bytes = v.data
                    elif ku == "TIT2":
                        tags["TITLE"] = str(v)
                    elif ku == "TPE1":
                        tags["ARTIST"] = str(v)
                    elif ku == "TPE2":
                        tags["ALBUMARTIST"] = str(v)
                    elif ku == "TALB":
                        tags["ALBUM"] = str(v)
                    elif ku in ("TDRC", "TYER"):
                        tags["DATE"] = str(v)
                    elif ku == "TRCK":
                        tags["TRACKNUMBER"] = str(v)
                    elif ku.startswith("USLT"):
                        tags["LYRICS"] = getattr(v, "text", str(v))
                    elif ku == "covr" and v and not cover_bytes:
                        cover_bytes = bytes(v[0])
                    elif isinstance(v, list) and v:
                        tags[ku] = str(v[0])
        return {
            "tags": tags,
            "duration_ms": duration_ms,
            "bitrate": bitrate,
            "sample_rate": sample_rate,
            "cover": cover_bytes,
        }
    except Exception:
        return None


def _extract_with_ffprobe(path: Path) -> dict:
    meta = {"tags": {}, "duration_ms": 0, "bitrate": 0, "sample_rate": 0, "cover": b""}
    if not shutil.which("ffprobe"):
        return meta
    try:
        res = subprocess.run(
            [
                "ffprobe", "-v", "quiet",
                "-print_format", "json",
                "-show_format", "-show_streams",
                str(path),
            ],
            capture_output=True,
            text=True,
            timeout=6,
        )
        if res.returncode != 0 or not res.stdout:
            return meta
        data = json.loads(res.stdout)
        fmt = data.get("format") or {}
        if fmt.get("duration"):
            meta["duration_ms"] = int(float(fmt["duration"]) * 1000)
        if fmt.get("bit_rate"):
            meta["bitrate"] = int(int(fmt["bit_rate"]) // 1000)
        for k, v in (fmt.get("tags") or {}).items():
            meta["tags"][k.upper()] = str(v)
        has_attached_pic = False
        for st in data.get("streams") or []:
            if st.get("codec_type") == "audio":
                if st.get("sample_rate") and not meta["sample_rate"]:
                    meta["sample_rate"] = int(st["sample_rate"])
                for k, v in (st.get("tags") or {}).items():
                    meta["tags"].setdefault(k.upper(), str(v))
            elif st.get("codec_type") == "video" and (st.get("disposition") or {}).get("attached_pic"):
                has_attached_pic = True
        if has_attached_pic and shutil.which("ffmpeg"):
            pic = subprocess.run(
                ["ffmpeg", "-v", "quiet", "-i", str(path), "-an", "-vcodec", "copy", "-f", "image2pipe", "-"],
                capture_output=True,
                timeout=6,
            )
            if pic.returncode == 0 and pic.stdout:
                meta["cover"] = pic.stdout
    except Exception:
        pass
    return meta


def inspect_audio_file(path: Path) -> dict:
    """Return normalized track metadata dictionary for a single audio file."""
    ext = path.suffix.lower()
    parsed = None
    if ext == ".flac":
        parsed = _parse_flac_native(path)
    if not parsed:
        parsed = _extract_with_mutagen(path)
    if not parsed or not parsed.get("duration_ms"):
        ff = _extract_with_ffprobe(path)
        if parsed:
            parsed["duration_ms"] = parsed.get("duration_ms") or ff["duration_ms"]
            parsed["bitrate"] = parsed.get("bitrate") or ff["bitrate"]
            parsed["sample_rate"] = parsed.get("sample_rate") or ff["sample_rate"]
            for k, v in ff["tags"].items():
                parsed["tags"].setdefault(k, v)
            if not parsed.get("cover") and ff.get("cover"):
                parsed["cover"] = ff["cover"]
        else:
            parsed = ff

    tags = parsed.get("tags") or {}
    stem = path.stem
    # Support "Artist - Title" filename fallback
    default_artist = "Artis Tidak Diketahui"
    default_title = stem
    if " - " in stem and not tags.get("TITLE"):
        parts = stem.split(" - ", 1)
        default_artist, default_title = parts[0].strip(), parts[1].strip()

    title = (tags.get("TITLE") or tags.get("©NAM") or default_title).strip()
    artist = (tags.get("ARTIST") or tags.get("©ART") or tags.get("ALBUMARTIST") or default_artist).strip()
    album_artist = (tags.get("ALBUMARTIST") or tags.get("ALBUM_ARTIST") or artist.split(",")[0]).strip()
    album = (tags.get("ALBUM") or tags.get("©ALB") or path.parent.name or "Album Lokal").strip()
    year_raw = (tags.get("DATE") or tags.get("YEAR") or tags.get("©DAY") or "").strip()
    year = year_raw[:4] if len(year_raw) >= 4 and year_raw[:4].isdigit() else ""

    tr_raw = (tags.get("TRACKNUMBER") or tags.get("TRCK") or "0").split("/")[0].strip()
    track_num = int(tr_raw) if tr_raw.isdigit() else 0

    lyrics_tag = ""
    for lk in ("LYRICS", "UNSYNCEDLYRICS", "USLT", "©LYR"):
        if tags.get(lk):
            lyrics_tag = tags[lk]
            break

    cover_url = ""
    if parsed.get("cover"):
        cover_url = _save_cover_bytes(parsed["cover"], f"{album_artist}:{album}")
    if not cover_url:
        cover_url = _find_folder_cover(path.parent)

    uri = file_uri(path)
    tid = stable_id("trk", str(path.resolve()))
    aid = stable_id("alb", f"{album_artist}::{album}")
    arid = stable_id("art", album_artist)

    stat = path.stat()
    duration_ms = int(parsed.get("duration_ms") or 0)
    bitrate = int(parsed.get("bitrate") or 0)
    if not bitrate and duration_ms > 0:
        bitrate = int((stat.st_size * 8) / duration_ms)

    return {
        "uri": uri,
        "id": tid,
        "path": str(path.resolve()),
        "mtime": stat.st_mtime,
        "size": stat.st_size,
        "name": title,
        "artists": artist,
        "artistId": arid,
        "album": album,
        "albumId": aid,
        "year": year,
        "trackNum": track_num,
        "durationMs": duration_ms,
        "bitrate": bitrate,
        "sampleRate": int(parsed.get("sample_rate") or 0),
        "format": ext.lstrip(".").upper(),
        "image": cover_url,
        "imageSmall": cover_url,
        "imageLarge": cover_url,
        "embeddedLyrics": lyrics_tag,
    }


class LibraryDB:
    """Thread-safe SQLite store for local tracks, playlists, likes, and play history."""

    def __init__(self, db_path: Path = DB_FILE):
        self.db_path = db_path
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_schema()

    def _connect(self):
        conn = sqlite3.connect(str(self.db_path), timeout=15)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_schema(self):
        with self._connect() as conn:
            conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS tracks (
                    uri TEXT PRIMARY KEY,
                    id TEXT,
                    path TEXT UNIQUE,
                    mtime REAL,
                    size INTEGER,
                    name TEXT,
                    artists TEXT,
                    artistId TEXT,
                    album TEXT,
                    albumId TEXT,
                    year TEXT,
                    trackNum INTEGER,
                    durationMs INTEGER,
                    bitrate INTEGER,
                    sampleRate INTEGER,
                    format TEXT,
                    image TEXT,
                    embeddedLyrics TEXT,
                    addedAt REAL
                );
                CREATE INDEX IF NOT EXISTS idx_tracks_album ON tracks(albumId);
                CREATE INDEX IF NOT EXISTS idx_tracks_artist ON tracks(artistId);

                CREATE TABLE IF NOT EXISTS liked_tracks (
                    uri TEXT PRIMARY KEY,
                    likedAt REAL
                );

                CREATE TABLE IF NOT EXISTS play_stats (
                    uri TEXT PRIMARY KEY,
                    playCount INTEGER DEFAULT 0,
                    lastPlayed REAL DEFAULT 0
                );

                CREATE TABLE IF NOT EXISTS playlists (
                    id TEXT PRIMARY KEY,
                    name TEXT,
                    subtitle TEXT,
                    m3uPath TEXT,
                    createdAt REAL
                );

                CREATE TABLE IF NOT EXISTS playlist_items (
                    playlistId TEXT,
                    position INTEGER,
                    uri TEXT,
                    PRIMARY KEY (playlistId, position)
                );
                """
            )

    def scan_directories(self, dirs: list[str]) -> dict:
        """Scan music directories incrementally and return summary statistics."""
        found_audio: list[Path] = []
        found_m3u: list[Path] = []
        seen_paths: set[str] = set()

        for raw_dir in dirs:
            root = Path(os.path.expanduser(raw_dir))
            if not root.exists():
                continue
            if root.is_file():
                if root.suffix.lower() in AUDIO_EXTS:
                    found_audio.append(root)
                continue
            for dirpath, dirnames, filenames in os.walk(root):
                dirnames[:] = [d for d in dirnames if not d.startswith(".")]
                for fn in filenames:
                    if fn.startswith("."):
                        continue
                    p = Path(dirpath) / fn
                    ext = p.suffix.lower()
                    if ext in AUDIO_EXTS:
                        rp = str(p.resolve())
                        if rp not in seen_paths:
                            seen_paths.add(rp)
                            found_audio.append(p)
                    elif ext in PLAYLIST_EXTS:
                        found_m3u.append(p)

        with self._connect() as conn:
            existing = {
                row["path"]: (row["mtime"], row["size"])
                for row in conn.execute("SELECT path, mtime, size FROM tracks")
            }

        to_inspect = []
        for p in found_audio:
            try:
                st = p.stat()
                rp = str(p.resolve())
            except OSError:
                continue
            old = existing.get(rp)
            if not old or abs(old[0] - st.st_mtime) > 0.01 or old[1] != st.st_size:
                to_inspect.append(p)

        new_records = [inspect_audio_file(p) for p in to_inspect]
        now = time.time()

        with self._connect() as conn:
            # Remove tracks that no longer exist on disk
            stale = set(existing.keys()) - seen_paths
            if stale:
                conn.executemany("DELETE FROM tracks WHERE path = ?", [(s,) for s in stale])

            for r in new_records:
                conn.execute(
                    """
                    INSERT INTO tracks (
                        uri, id, path, mtime, size, name, artists, artistId,
                        album, albumId, year, trackNum, durationMs, bitrate,
                        sampleRate, format, image, embeddedLyrics, addedAt
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(uri) DO UPDATE SET
                        mtime=excluded.mtime, size=excluded.size, name=excluded.name,
                        artists=excluded.artists, artistId=excluded.artistId,
                        album=excluded.album, albumId=excluded.albumId, year=excluded.year,
                        trackNum=excluded.trackNum, durationMs=excluded.durationMs,
                        bitrate=excluded.bitrate, sampleRate=excluded.sampleRate,
                        format=excluded.format, image=excluded.image,
                        embeddedLyrics=excluded.embeddedLyrics
                    """,
                    (
                        r["uri"], r["id"], r["path"], r["mtime"], r["size"],
                        r["name"], r["artists"], r["artistId"], r["album"], r["albumId"],
                        r["year"], r["trackNum"], r["durationMs"], r["bitrate"],
                        r["sampleRate"], r["format"], r["image"], r["embeddedLyrics"], now,
                    ),
                )

            # Sync M3U playlists found on disk
            for m3u in found_m3u:
                self._import_m3u(conn, m3u)

            total = conn.execute("SELECT COUNT(*) FROM tracks").fetchone()[0]
        return {"total": total, "updated": len(new_records), "removed": len(stale)}

    def ingest_files(self, paths: list[str]) -> list[dict]:
        """Ensure arbitrary audio file paths are indexed and return their track dicts."""
        uris = []
        now = time.time()
        with self._connect() as conn:
            for raw in paths:
                p = Path(os.path.expanduser(raw))
                if not p.is_file() or p.suffix.lower() not in AUDIO_EXTS:
                    continue
                r = inspect_audio_file(p)
                conn.execute(
                    """
                    INSERT INTO tracks (
                        uri, id, path, mtime, size, name, artists, artistId,
                        album, albumId, year, trackNum, durationMs, bitrate,
                        sampleRate, format, image, embeddedLyrics, addedAt
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(uri) DO UPDATE SET
                        mtime=excluded.mtime, size=excluded.size, image=excluded.image
                    """,
                    (
                        r["uri"], r["id"], r["path"], r["mtime"], r["size"],
                        r["name"], r["artists"], r["artistId"], r["album"], r["albumId"],
                        r["year"], r["trackNum"], r["durationMs"], r["bitrate"],
                        r["sampleRate"], r["format"], r["image"], r["embeddedLyrics"], now,
                    ),
                )
                uris.append(r["uri"])
        return self.get_tracks_by_uris(uris)

    def _import_m3u(self, conn, m3u_path: Path):
        pid = stable_id("pl_m3u", str(m3u_path.resolve()))
        try:
            lines = m3u_path.read_text(encoding="utf-8", errors="ignore").splitlines()
        except OSError:
            return
        uris = []
        for line in lines:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("file://"):
                uris.append(line)
            else:
                candidate = (m3u_path.parent / line).resolve()
                if candidate.exists():
                    uris.append(file_uri(candidate))
        conn.execute(
            """
            INSERT INTO playlists (id, name, subtitle, m3uPath, createdAt)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET name=excluded.name, subtitle=excluded.subtitle
            """,
            (pid, m3u_path.stem, f"M3U • {len(uris)} lagu", str(m3u_path.resolve()), time.time()),
        )
        conn.execute("DELETE FROM playlist_items WHERE playlistId = ?", (pid,))
        for idx, u in enumerate(uris):
            conn.execute(
                "INSERT INTO playlist_items (playlistId, position, uri) VALUES (?, ?, ?)",
                (pid, idx, u),
            )

    def _row_to_track(self, row, liked_set: set[str] | None = None) -> dict:
        img = row["image"] or ""
        uri = row["uri"]
        fmt = row["format"] or ""
        br = row["bitrate"] or 0
        sr = row["sampleRate"] or 0
        quality = " • ".join(
            x for x in (fmt, f"{sr / 1000:g} kHz" if sr else "", f"{br} kbps" if br else "") if x
        )
        return {
            "uri": uri,
            "id": row["id"],
            "path": row["path"],
            "name": row["name"],
            "artists": row["artists"],
            "artistId": row["artistId"],
            "album": row["album"],
            "albumId": row["albumId"],
            "year": row["year"] or "",
            "trackNum": row["trackNum"] or 0,
            "durationMs": row["durationMs"] or 0,
            "bitrate": br,
            "sampleRate": sr,
            "format": fmt,
            "quality": quality,
            "image": img,
            "imageSmall": img,
            "imageLarge": img,
            "Explicit": False,
            "explicit": False,
            "playable": True,
            "liked": (uri in liked_set) if liked_set is not None else False,
            "embeddedLyrics": row["embeddedLyrics"] or "",
        }

    def _liked_set(self, conn) -> set[str]:
        return {r["uri"] for r in conn.execute("SELECT uri FROM liked_tracks")}

    def get_track(self, uri: str) -> dict | None:
        with self._connect() as conn:
            liked = self._liked_set(conn)
            row = conn.execute("SELECT * FROM tracks WHERE uri = ?", (uri,)).fetchone()
            return self._row_to_track(row, liked) if row else None

    def get_tracks_by_uris(self, uris: list[str]) -> list[dict]:
        if not uris:
            return []
        with self._connect() as conn:
            liked = self._liked_set(conn)
            placeholders = ",".join("?" for _ in uris)
            rows = conn.execute(f"SELECT * FROM tracks WHERE uri IN ({placeholders})", uris).fetchall()
            by_uri = {r["uri"]: self._row_to_track(r, liked) for r in rows}
            return [by_uri[u] for u in uris if u in by_uri]

    def get_all_tracks(self) -> list[dict]:
        with self._connect() as conn:
            liked = self._liked_set(conn)
            rows = conn.execute(
                "SELECT * FROM tracks ORDER BY artists COLLATE NOCASE, album COLLATE NOCASE, trackNum, name COLLATE NOCASE"
            ).fetchall()
            return [self._row_to_track(r, liked) for r in rows]

    def get_context_tracks(self, context_uri: str) -> list[dict]:
        if not context_uri or context_uri == "local:all":
            return self.get_all_tracks()
        if context_uri == "local:liked":
            return self.get_liked_tracks()
        if context_uri.startswith("local:album:"):
            aid = context_uri.split(":", 2)[2]
            return self.get_album(aid).get("tracks", [])
        if context_uri.startswith("local:artist:"):
            arid = context_uri.split(":", 2)[2]
            return self.get_artist(arid).get("tracks", [])
        if context_uri.startswith("local:playlist:"):
            pid = context_uri.split(":", 2)[2]
            return self.get_playlist(pid).get("tracks", [])
        return self.get_all_tracks()

    def record_play(self, uri: str):
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO play_stats (uri, playCount, lastPlayed)
                VALUES (?, 1, ?)
                ON CONFLICT(uri) DO UPDATE SET
                    playCount = playCount + 1,
                    lastPlayed = excluded.lastPlayed
                """,
                (uri, time.time()),
            )

    def is_liked(self, uri: str) -> bool:
        with self._connect() as conn:
            row = conn.execute("SELECT 1 FROM liked_tracks WHERE uri = ?", (uri,)).fetchone()
            return bool(row)

    def set_liked(self, uri: str, liked: bool):
        with self._connect() as conn:
            if liked:
                conn.execute(
                    "INSERT OR REPLACE INTO liked_tracks (uri, likedAt) VALUES (?, ?)",
                    (uri, time.time()),
                )
            else:
                conn.execute("DELETE FROM liked_tracks WHERE uri = ?", (uri,))

    def get_liked_tracks(self) -> list[dict]:
        with self._connect() as conn:
            liked = self._liked_set(conn)
            rows = conn.execute(
                """
                SELECT t.* FROM tracks t
                JOIN liked_tracks l ON l.uri = t.uri
                ORDER BY l.likedAt DESC
                """
            ).fetchall()
            return [self._row_to_track(r, liked) for r in rows]

    def get_playlists(self) -> list[dict]:
        with self._connect() as conn:
            total_tracks = conn.execute("SELECT COUNT(*) FROM tracks").fetchone()[0]
            first_img_row = conn.execute("SELECT image FROM tracks WHERE image != '' LIMIT 1").fetchone()
            first_img = first_img_row["image"] if first_img_row else ""

            items = [
                {
                    "kind": "playlist",
                    "id": "all",
                    "uri": "local:playlist:all",
                    "name": "Semua Lagu Lokal",
                    "description": "Seluruh koleksi audio di folder musikmu",
                    "subtitle": f"{total_tracks} lagu",
                    "image": first_img,
                    "imageSmall": first_img,
                    "imageLarge": first_img,
                }
            ]
            rows = conn.execute("SELECT * FROM playlists ORDER BY createdAt DESC").fetchall()
            for r in rows:
                pid = r["id"]
                cnt = conn.execute(
                    "SELECT COUNT(*) FROM playlist_items WHERE playlistId = ?", (pid,)
                ).fetchone()[0]
                cov_row = conn.execute(
                    """
                    SELECT t.image FROM playlist_items pi
                    JOIN tracks t ON t.uri = pi.uri
                    WHERE pi.playlistId = ? AND t.image != ''
                    ORDER BY pi.position LIMIT 1
                    """,
                    (pid,),
                ).fetchone()
                cov = cov_row["image"] if cov_row else ""
                items.append({
                    "kind": "playlist",
                    "id": pid,
                    "uri": f"local:playlist:{pid}",
                    "name": r["name"],
                    "description": r["subtitle"] or "",
                    "subtitle": f"{cnt} lagu",
                    "image": cov,
                    "imageSmall": cov,
                    "imageLarge": cov,
                })
            return items

    def create_playlist(self, name: str) -> str:
        name = name.strip() or "Playlist Baru"
        pid = stable_id("pl", f"{name}_{time.time()}")
        with self._connect() as conn:
            conn.execute(
                "INSERT INTO playlists (id, name, subtitle, m3uPath, createdAt) VALUES (?, ?, ?, '', ?)",
                (pid, name, "Playlist Lokal", time.time()),
            )
        return pid

    def delete_playlist(self, pid: str):
        if pid == "all":
            return
        with self._connect() as conn:
            conn.execute("DELETE FROM playlists WHERE id = ?", (pid,))
            conn.execute("DELETE FROM playlist_items WHERE playlistId = ?", (pid,))

    def add_to_playlist(self, pid: str, uri: str):
        if pid == "all" or not uri:
            return
        with self._connect() as conn:
            row = conn.execute(
                "SELECT COALESCE(MAX(position), -1) + 1 AS next_pos FROM playlist_items WHERE playlistId = ?",
                (pid,),
            ).fetchone()
            pos = row["next_pos"] if row else 0
            conn.execute(
                "INSERT OR REPLACE INTO playlist_items (playlistId, position, uri) VALUES (?, ?, ?)",
                (pid, pos, uri),
            )

    def get_playlist(self, pid: str) -> dict:
        if pid == "all":
            tracks = self.get_all_tracks()
            img = next((t["image"] for t in tracks if t.get("image")), "")
            return {
                "kind": "playlist",
                "id": "all",
                "uri": "local:playlist:all",
                "playUri": "local:playlist:all",
                "name": "Semua Lagu Lokal",
                "typeLabel": "Koleksi Lokal",
                "description": "Seluruh lagu yang terindeks dari folder musik lokal",
                "subtitle": "Koleksi Offline",
                "image": img,
                "imageSmall": img,
                "imageLarge": img,
                "tracks": tracks,
                "note": "" if tracks else "Belum ada file musik. Tambahkan folder di Pengaturan atau taruh lagu di ~/Music.",
            }
        with self._connect() as conn:
            liked = self._liked_set(conn)
            p = conn.execute("SELECT * FROM playlists WHERE id = ?", (pid,)).fetchone()
            if not p:
                return {"kind": "playlist", "id": pid, "name": "Playlist", "tracks": [], "error": "Playlist tidak ditemukan"}
            rows = conn.execute(
                """
                SELECT t.* FROM playlist_items pi
                JOIN tracks t ON t.uri = pi.uri
                WHERE pi.playlistId = ?
                ORDER BY pi.position
                """,
                (pid,),
            ).fetchall()
            tracks = [self._row_to_track(r, liked) for r in rows]
            img = next((t["image"] for t in tracks if t.get("image")), "")
            return {
                "kind": "playlist",
                "id": pid,
                "uri": f"local:playlist:{pid}",
                "playUri": f"local:playlist:{pid}",
                "name": p["name"],
                "typeLabel": "Playlist Lokal",
                "description": p["subtitle"] or "",
                "subtitle": p["subtitle"] or "Playlist",
                "image": img,
                "imageSmall": img,
                "imageLarge": img,
                "tracks": tracks,
                "note": "" if tracks else "Playlist ini masih kosong. Klik kanan lagu untuk menambahkan ke playlist.",
            }

    def get_album(self, aid: str) -> dict:
        with self._connect() as conn:
            liked = self._liked_set(conn)
            rows = conn.execute(
                "SELECT * FROM tracks WHERE albumId = ? ORDER BY trackNum, name COLLATE NOCASE",
                (aid,),
            ).fetchall()
            if not rows:
                return {"kind": "album", "id": aid, "name": "Album", "tracks": []}
            tracks = [self._row_to_track(r, liked) for r in rows]
            first = tracks[0]
            sub = " • ".join(x for x in (first["artists"], first["year"], f"{len(tracks)} lagu", first["format"]) if x)
            return {
                "kind": "album",
                "id": aid,
                "uri": f"local:album:{aid}",
                "playUri": f"local:album:{aid}",
                "name": first["album"],
                "typeLabel": "Album Lokal",
                "subtitle": sub,
                "artistId": first["artistId"],
                "year": first["year"],
                "image": first["image"],
                "imageSmall": first["image"],
                "imageLarge": first["image"],
                "tracks": tracks,
            }

    def get_artist(self, arid: str) -> dict:
        with self._connect() as conn:
            liked = self._liked_set(conn)
            rows = conn.execute(
                "SELECT * FROM tracks WHERE artistId = ? ORDER BY album COLLATE NOCASE, trackNum, name COLLATE NOCASE",
                (arid,),
            ).fetchall()
            if not rows:
                return {"kind": "artist", "id": arid, "name": "Artis", "tracks": [], "albums": []}
            tracks = [self._row_to_track(r, liked) for r in rows]
            first = tracks[0]
            albums_map = {}
            for t in tracks:
                aid = t["albumId"]
                if aid not in albums_map:
                    albums_map[aid] = {
                        "kind": "album",
                        "id": aid,
                        "uri": f"local:album:{aid}",
                        "name": t["album"],
                        "subtitle": t["artists"],
                        "year": t["year"],
                        "image": t["image"],
                        "imageSmall": t["image"],
                        "imageLarge": t["image"],
                    }
            return {
                "kind": "artist",
                "id": arid,
                "uri": f"local:artist:{arid}",
                "playUri": f"local:artist:{arid}",
                "name": first["artists"].split(",")[0].strip(),
                "typeLabel": "Artis Lokal",
                "genres": f"{len(tracks)} lagu • {len(albums_map)} album di pustaka lokal",
                "image": first["image"],
                "imageSmall": first["image"],
                "imageLarge": first["image"],
                "tracks": tracks[:20],
                "albums": list(albums_map.values()),
            }

    def get_home(self) -> dict:
        with self._connect() as conn:
            liked = self._liked_set(conn)
            # Recently played or recently added albums
            recent_rows = conn.execute(
                """
                SELECT t.* FROM tracks t
                LEFT JOIN play_stats ps ON ps.uri = t.uri
                ORDER BY COALESCE(ps.lastPlayed, 0) DESC, t.addedAt DESC
                LIMIT 60
                """
            ).fetchall()
            recent_albums = []
            seen_alb = set()
            for r in recent_rows:
                aid = r["albumId"]
                if aid not in seen_alb:
                    seen_alb.add(aid)
                    recent_albums.append({
                        "kind": "album",
                        "id": aid,
                        "uri": f"local:album:{aid}",
                        "name": r["album"],
                        "subtitle": r["artists"],
                        "year": r["year"] or "",
                        "image": r["image"] or "",
                        "imageSmall": r["image"] or "",
                        "imageLarge": r["image"] or "",
                    })
                if len(recent_albums) >= 12:
                    break

            # Top tracks (most played, fallback to first tracks in library)
            top_rows = conn.execute(
                """
                SELECT t.* FROM tracks t
                LEFT JOIN play_stats ps ON ps.uri = t.uri
                ORDER BY COALESCE(ps.playCount, 0) DESC, t.addedAt DESC, t.name COLLATE NOCASE
                LIMIT 10
                """
            ).fetchall()
            top_tracks = [self._row_to_track(r, liked) for r in top_rows]

            # Top artists
            art_rows = conn.execute(
                """
                SELECT artistId, artists, image, COUNT(*) AS cnt
                FROM tracks
                GROUP BY artistId
                ORDER BY cnt DESC, artists COLLATE NOCASE
                LIMIT 12
                """
            ).fetchall()
            top_artists = [
                {
                    "kind": "artist",
                    "id": r["artistId"],
                    "uri": f"local:artist:{r['artistId']}",
                    "name": r["artists"].split(",")[0].strip(),
                    "subtitle": f"{r['cnt']} lagu",
                    "image": r["image"] or "",
                    "imageSmall": r["image"] or "",
                    "imageLarge": r["image"] or "",
                }
                for r in art_rows
            ]

            return {
                "recent": recent_albums,
                "topTracks": top_tracks,
                "topArtists": top_artists,
            }

    def search(self, query: str) -> dict:
        q = f"%{query.strip()}%"
        with self._connect() as conn:
            liked = self._liked_set(conn)
            t_rows = conn.execute(
                """
                SELECT * FROM tracks
                WHERE name LIKE ? OR artists LIKE ? OR album LIKE ?
                ORDER BY name COLLATE NOCASE
                LIMIT 25
                """,
                (q, q, q),
            ).fetchall()
            tracks = [self._row_to_track(r, liked) for r in t_rows]

            alb_rows = conn.execute(
                """
                SELECT albumId, album, artists, year, image
                FROM tracks
                WHERE album LIKE ? OR artists LIKE ?
                GROUP BY albumId
                LIMIT 12
                """,
                (q, q),
            ).fetchall()
            albums = [
                {
                    "kind": "album",
                    "id": r["albumId"],
                    "uri": f"local:album:{r['albumId']}",
                    "name": r["album"],
                    "subtitle": r["artists"],
                    "year": r["year"] or "",
                    "image": r["image"] or "",
                    "imageSmall": r["image"] or "",
                    "imageLarge": r["image"] or "",
                }
                for r in alb_rows
            ]

            art_rows = conn.execute(
                """
                SELECT artistId, artists, image, COUNT(*) AS cnt
                FROM tracks
                WHERE artists LIKE ?
                GROUP BY artistId
                LIMIT 12
                """,
                (q,),
            ).fetchall()
            artists = [
                {
                    "kind": "artist",
                    "id": r["artistId"],
                    "uri": f"local:artist:{r['artistId']}",
                    "name": r["artists"].split(",")[0].strip(),
                    "subtitle": f"{r['cnt']} lagu",
                    "image": r["image"] or "",
                    "imageSmall": r["image"] or "",
                    "imageLarge": r["image"] or "",
                }
                for r in art_rows
            ]

            pl_rows = conn.execute(
                "SELECT * FROM playlists WHERE name LIKE ? LIMIT 10", (q,)
            ).fetchall()
            playlists = [
                {
                    "kind": "playlist",
                    "id": r["id"],
                    "uri": f"local:playlist:{r['id']}",
                    "name": r["name"],
                    "subtitle": r["subtitle"] or "Playlist Lokal",
                    "image": "",
                    "imageSmall": "",
                    "imageLarge": "",
                }
                for r in pl_rows
            ]

            return {
                "tracks": tracks,
                "artists": artists,
                "albums": albums,
                "playlists": playlists,
            }

    def stats(self) -> dict:
        with self._connect() as conn:
            tracks = conn.execute("SELECT COUNT(*) FROM tracks").fetchone()[0]
            albums = conn.execute("SELECT COUNT(DISTINCT albumId) FROM tracks").fetchone()[0]
            artists = conn.execute("SELECT COUNT(DISTINCT artistId) FROM tracks").fetchone()[0]
            return {"tracks": tracks, "albums": albums, "artists": artists}
