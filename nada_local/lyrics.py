"""Hybrid lyrics resolver: local .lrc sidecar -> embedded tag -> LRCLIB fallback."""

import bisect
import hashlib
import json
import re
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from urllib.parse import unquote

from PySide6.QtCore import Property, QObject, Signal

from .config import LYRICS_CACHE_DIR

LRC_LINE = re.compile(r"\[(\d+):(\d+(?:\.\d+)?)\]")
HEADERS = {"User-Agent": "NadaLocal/0.1 (Linux desktop music player)"}


def _get_lrclib(path, **params):
    url = "https://lrclib.net/api" + path + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def parse_lrc(text: str):
    lines = []
    for raw in text.splitlines():
        stamps = LRC_LINE.findall(raw)
        words = LRC_LINE.sub("", raw).strip()
        for m, s in stamps:
            lines.append({"t": int((int(m) * 60 + float(s)) * 1000), "text": words})
    lines.sort(key=lambda l: l["t"])
    return lines


def parse_text_or_lrc(text: str) -> dict:
    if not text or not text.strip():
        return {"synced": False, "lines": []}
    synced_lines = parse_lrc(text)
    if synced_lines:
        return {"synced": True, "lines": synced_lines}
    plain = [{"t": 0, "text": l.strip()} for l in text.splitlines() if l.strip()]
    return {"synced": False, "lines": plain}


def resolve_lyrics(track: dict, allow_online: bool = True) -> dict:
    # 1. Check local .lrc file next to the audio file
    filepath = track.get("path") or ""
    if not filepath and track.get("uri", "").startswith("file://"):
        filepath = unquote(track["uri"][7:])
    if filepath:
        p = Path(filepath)
        for ext in (".lrc", ".LRC", ".txt"):
            candidate = p.with_suffix(ext)
            if candidate.is_file():
                try:
                    content = candidate.read_text(encoding="utf-8", errors="replace")
                    parsed = parse_text_or_lrc(content)
                    if parsed["lines"]:
                        return parsed
                except OSError:
                    pass

    # 2. Check embedded lyrics tag in audio file
    embedded = track.get("embeddedLyrics") or ""
    if embedded.strip():
        parsed = parse_text_or_lrc(embedded)
        if parsed["lines"]:
            return parsed

    # 3. Check local disk cache for previously fetched LRCLIB lyrics
    cache_key = hashlib.sha1(
        f"{track.get('artists', '')}::{track.get('name', '')}".lower().encode("utf-8", errors="ignore")
    ).hexdigest()[:20]
    LYRICS_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache_file = LYRICS_CACHE_DIR / f"{cache_key}.json"
    if cache_file.is_file():
        try:
            cached = json.loads(cache_file.read_text(encoding="utf-8"))
            if cached.get("lines"):
                return cached
        except (OSError, ValueError):
            pass

    if not allow_online:
        return {"synced": False, "lines": []}

    # 4. Fallback to LRCLIB online API
    artist = (track.get("artists") or "").split(",")[0].strip()
    title = (track.get("name") or "").strip()
    if not title:
        return {"synced": False, "lines": []}

    params = {"track_name": title, "artist_name": artist}
    hit = _get_lrclib(
        "/get",
        **params,
        album_name=track.get("album", ""),
        duration=round((track.get("durationMs") or 0) / 1000),
    )
    if not hit or not (hit.get("syncedLyrics") or hit.get("plainLyrics")):
        results = _get_lrclib("/search", **params) or []
        hit = next((r for r in results if r.get("syncedLyrics")), None) or next(
            (r for r in results if r.get("plainLyrics")), None
        )
    if not hit:
        return {"synced": False, "lines": []}

    if hit.get("syncedLyrics"):
        res = {"synced": True, "lines": parse_lrc(hit["syncedLyrics"])}
    elif hit.get("instrumental"):
        res = {"synced": False, "lines": [{"t": 0, "text": "♪ Instrumental ♪"}]}
    else:
        res = {"synced": False, "lines": [{"t": 0, "text": l} for l in hit.get("plainLyrics", "").splitlines()]}

    if res["lines"]:
        try:
            cache_file.write_text(json.dumps(res, ensure_ascii=False), encoding="utf-8")
        except OSError:
            pass
    return res


class Lyrics(QObject):
    changed = Signal()
    currentChanged = Signal()

    def __init__(self, player, settings, worker, parent=None):
        super().__init__(parent)
        self.player = player
        self.settings = settings
        self.worker = worker
        self._cache = {}
        self._uri = ""
        self._lines = []
        self._times = []
        self._synced = False
        self._status = "idle"
        self._current = -1
        player.trackChanged.connect(self._on_track)
        player.positionChanged.connect(self._on_position)

    @Property("QVariantList", notify=changed)
    def lines(self):
        return self._lines

    @Property(bool, notify=changed)
    def synced(self):
        return self._synced

    @Property(str, notify=changed)
    def status(self):
        return self._status  # idle | loading | ready | none | error

    @Property(int, notify=currentChanged)
    def current(self):
        return self._current

    def _set(self, uri, data, status):
        if uri != self._uri:
            return
        self._lines = data.get("lines", [])
        self._times = [l["t"] for l in self._lines]
        self._synced = data.get("synced", False)
        self._status = status if self._lines or status != "ready" else "none"
        self._current = -1
        self.changed.emit()
        self._on_position()

    def _on_track(self):
        st = self.player.state
        self._uri = st.get("uri", "")
        if not self._uri:
            self._set("", {}, "idle")
            return
        if self._uri in self._cache:
            self._set(self._uri, self._cache[self._uri], "ready")
            return
        uri = self._uri
        self._set(uri, {}, "loading")
        track = dict(st)
        allow_online = bool(self.settings.get("online_lyrics", True))

        def done(data):
            self._cache[uri] = data
            self._set(uri, data, "ready")

        self.worker.run(
            lambda: resolve_lyrics(track, allow_online=allow_online),
            done,
            lambda e: self._set(uri, {}, "none"),
        )

    def _on_position(self):
        if not self._synced:
            return
        idx = bisect.bisect_right(self._times, self.player.position + 150) - 1
        if idx != self._current:
            self._current = idx
            self.currentChanged.emit()
