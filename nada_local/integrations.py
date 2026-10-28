"""Native Discord Rich Presence (IPC socket) & Offline-capable Scrobbler (ListenBrainz / Last.fm)."""

import hashlib
import json
import os
import socket
import struct
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

from .config import DEFAULT_DISCORD_CLIENT_ID, SCROBBLE_QUEUE_FILE, read_json, write_private


def _find_discord_ipc_socket() -> str:
    runtime = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    candidates = []
    for i in range(10):
        candidates.extend([
            f"{runtime}/discord-ipc-{i}",
            f"{runtime}/app/com.discordapp.Discord/discord-ipc-{i}",
            f"{runtime}/snap.discord/discord-ipc-{i}",
            f"/tmp/discord-ipc-{i}",
        ])
    for p in candidates:
        if os.path.exists(p):
            return p
    return ""


class DiscordRPC:
    """Zero-dependency Discord IPC Rich Presence client over Unix domain socket."""

    def __init__(self, client_id: str = DEFAULT_DISCORD_CLIENT_ID):
        self.client_id = client_id or DEFAULT_DISCORD_CLIENT_ID
        self.sock: socket.socket | None = None
        self.connected = False

    def connect(self) -> bool:
        if self.connected and self.sock:
            return True
        path = _find_discord_ipc_socket()
        if not path:
            return False
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.settimeout(1.5)
            s.connect(path)
            self.sock = s
            self._send(0, {"v": 1, "client_id": self.client_id})
            op, _ = self._recv()
            if op == 1:
                self.connected = True
                return True
        except OSError:
            pass
        self.close()
        return False

    def _send(self, opcode: int, payload: dict):
        if not self.sock:
            return
        raw = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        header = struct.pack("<II", opcode, len(raw))
        self.sock.sendall(header + raw)

    def _recv(self) -> tuple[int, dict]:
        if not self.sock:
            return -1, {}
        hdr = self.sock.recv(8)
        if len(hdr) < 8:
            return -1, {}
        op, length = struct.unpack("<II", hdr)
        data = b""
        while len(data) < length:
            chunk = self.sock.recv(length - len(data))
            if not chunk:
                break
            data += chunk
        try:
            return op, json.loads(data.decode("utf-8", errors="ignore"))
        except ValueError:
            return op, {}

    def update_activity(self, state: dict, position_ms: int):
        if not state.get("hasTrack"):
            self.clear()
            return
        if not self.connect():
            return

        playing = bool(state.get("isPlaying"))
        title = (state.get("name") or "Lagu Lokal")[:120]
        artists = (state.get("artists") or "Artis Lokal")[:120]
        album = (state.get("album") or "Nada Local")[:120]
        fmt = state.get("format") or "Hi-Fi"
        dur_ms = int(state.get("durationMs") or 0)

        activity = {
            "type": 2,  # Listening
            "details": f"🎵 {title}",
            "state": f"oleh {artists}" + (f" • {album}" if album else ""),
            "assets": {
                "large_text": f"{album} ({fmt}) — Nada Local",
                "small_text": "Sedang Diputar" if playing else "Dijeda",
            },
        }
        if playing and dur_ms > 0:
            now_sec = int(time.time())
            start_sec = now_sec - int(position_ms // 1000)
            end_sec = start_sec + int(dur_ms // 1000)
            activity["timestamps"] = {"start": start_sec, "end": end_sec}

        payload = {
            "cmd": "SET_ACTIVITY",
            "args": {"pid": os.getpid(), "activity": activity},
            "nonce": str(uuid.uuid4()),
        }
        try:
            self._send(1, payload)
            self._recv()
        except OSError:
            self.close()

    def clear(self):
        if not self.connected or not self.sock:
            return
        payload = {
            "cmd": "SET_ACTIVITY",
            "args": {"pid": os.getpid(), "activity": None},
            "nonce": str(uuid.uuid4()),
        }
        try:
            self._send(1, payload)
            self._recv()
        except OSError:
            self.close()

    def close(self):
        self.connected = False
        if self.sock:
            try:
                self.sock.close()
            except OSError:
                pass
            self.sock = None


class Scrobbler:
    """ListenBrainz & Last.fm scrobbler with persistent offline queue."""

    def __init__(self, settings):
        self.settings = settings
        self._queue: list[dict] = self._load_queue()

    def _load_queue(self) -> list[dict]:
        data = read_json(SCROBBLE_QUEUE_FILE)
        items = data.get("items", []) if isinstance(data, dict) else []
        return items if isinstance(items, list) else []

    def _save_queue(self):
        write_private(SCROBBLE_QUEUE_FILE, {"items": self._queue[-200:]})

    @property
    def pending_count(self) -> int:
        return len(self._queue)

    def submit_playing_now(self, track: dict):
        if not self.settings.get("scrobble_enabled"):
            return
        lb_token = (self.settings.get("listenbrainz_token") or "").strip()
        if lb_token:
            payload = {
                "listen_type": "playing_now",
                "payload": [{"track_metadata": self._lb_meta(track)}],
            }
            self._post_listenbrainz(lb_token, payload)

        lfm_key = (self.settings.get("lastfm_api_key") or "").strip()
        lfm_sec = (self.settings.get("lastfm_api_secret") or "").strip()
        lfm_sk = (self.settings.get("lastfm_session_key") or "").strip()
        if lfm_key and lfm_sec and lfm_sk:
            self._post_lastfm(
                lfm_key,
                lfm_sec,
                lfm_sk,
                {
                    "method": "track.updateNowPlaying",
                    "artist": (track.get("artists") or "").split(",")[0].strip(),
                    "track": track.get("name") or "",
                    "album": track.get("album") or "",
                },
            )

    def enqueue_scrobble(self, track: dict, listened_at: int):
        if not self.settings.get("scrobble_enabled"):
            return
        entry = {
            "listened_at": int(listened_at),
            "name": track.get("name") or "",
            "artists": (track.get("artists") or "").split(",")[0].strip(),
            "album": track.get("album") or "",
            "durationMs": int(track.get("durationMs") or 0),
        }
        if not entry["name"] or not entry["artists"]:
            return
        self._queue.append(entry)
        self._save_queue()
        self.flush_queue()

    def flush_queue(self) -> int:
        if not self._queue or not self.settings.get("scrobble_enabled"):
            return 0
        lb_token = (self.settings.get("listenbrainz_token") or "").strip()
        lfm_key = (self.settings.get("lastfm_api_key") or "").strip()
        lfm_sec = (self.settings.get("lastfm_api_secret") or "").strip()
        lfm_sk = (self.settings.get("lastfm_session_key") or "").strip()

        if not lb_token and not (lfm_key and lfm_sec and lfm_sk):
            return 0

        batch = list(self._queue[:25])
        ok = True

        if lb_token:
            payload = {
                "listen_type": "import",
                "payload": [
                    {
                        "listened_at": item["listened_at"],
                        "track_metadata": self._lb_meta(item),
                    }
                    for item in batch
                ],
            }
            if not self._post_listenbrainz(lb_token, payload):
                ok = False

        if lfm_key and lfm_sec and lfm_sk:
            for item in batch:
                sent = self._post_lastfm(
                    lfm_key,
                    lfm_sec,
                    lfm_sk,
                    {
                        "method": "track.scrobble",
                        "artist": item["artists"],
                        "track": item["name"],
                        "album": item["album"],
                        "timestamp": str(item["listened_at"]),
                    },
                )
                if not sent:
                    ok = False
                    break

        if ok:
            self._queue = self._queue[len(batch):]
            self._save_queue()
            return len(batch)
        return 0

    @staticmethod
    def _lb_meta(track: dict) -> dict:
        meta = {
            "artist_name": (track.get("artists") or "").split(",")[0].strip(),
            "track_name": track.get("name") or "",
        }
        if track.get("album"):
            meta["release_name"] = track["album"]
        if track.get("durationMs"):
            meta["additional_info"] = {
                "duration_ms": int(track["durationMs"]),
                "media_player": "Nada Local",
            }
        return meta

    @staticmethod
    def _post_listenbrainz(token: str, payload: dict) -> bool:
        try:
            body = json.dumps(payload).encode("utf-8")
            req = urllib.request.Request(
                "https://api.listenbrainz.org/1/submit-listens",
                data=body,
                headers={
                    "Authorization": f"Token {token}",
                    "Content-Type": "application/json",
                    "User-Agent": "NadaLocal/0.1",
                },
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=8) as resp:
                return 200 <= resp.status < 300
        except Exception:
            return False

    @staticmethod
    def _post_lastfm(api_key: str, api_secret: str, session_key: str, params: dict) -> bool:
        try:
            full = {**params, "api_key": api_key, "sk": session_key}
            sig_base = "".join(f"{k}{full[k]}" for k in sorted(full.keys())) + api_secret
            full["api_sig"] = hashlib.md5(sig_base.encode("utf-8")).hexdigest()
            full["format"] = "json"
            body = urllib.parse.urlencode(full).encode("utf-8")
            req = urllib.request.Request(
                "https://ws.audioscrobbler.com/2.0/",
                data=body,
                headers={"User-Agent": "NadaLocal/0.1"},
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=8) as resp:
                return 200 <= resp.status < 300
        except Exception:
            return False


class Integrations(QObject):
    """Coordinates Discord RPC and Scrobbling based on Player events."""

    changed = Signal()

    def __init__(self, player, settings, worker, parent=None):
        super().__init__(parent)
        self.player = player
        self.settings = settings
        self.worker = worker
        self.discord = DiscordRPC(settings.get("discord_client_id", DEFAULT_DISCORD_CLIENT_ID))
        self.scrobbler = Scrobbler(settings)

        self._current_uri = ""
        self._started_at = 0
        self._scrobbled_current = False

        player.trackChanged.connect(self._on_track_changed)
        player.stateChanged.connect(self._on_state_changed)

        self._timer = QTimer(self)
        self._timer.setInterval(5000)
        self._timer.timeout.connect(self._periodic_check)
        self._timer.start()

    @Property(bool, notify=changed)
    def discordConnected(self):
        return self.discord.connected

    @Property(int, notify=changed)
    def pendingScrobbles(self):
        return self.scrobbler.pending_count

    @Slot()
    def flushScrobbles(self):
        def job():
            return self.scrobbler.flush_queue()

        def done(cnt):
            self.changed.emit()
            if cnt > 0:
                self.worker.error.emit(f"{cnt} scrobble berhasil dikirim")

        self.worker.run(job, done, lambda e: None)

    def _on_track_changed(self):
        st = dict(self.player.state)
        uri = st.get("uri", "")
        self._current_uri = uri
        self._started_at = int(time.time())
        self._scrobbled_current = False
        self._sync_discord()
        if uri and st.get("hasTrack") and self.settings.get("scrobble_enabled"):
            self.worker.run(lambda: self.scrobbler.submit_playing_now(st), lambda _: None, lambda e: None)

    def _on_state_changed(self):
        self._sync_discord()

    def _sync_discord(self):
        if not self.settings.get("discord_rpc", True):
            if self.discord.connected:
                self.worker.run(self.discord.clear, lambda _: self.changed.emit(), lambda e: None)
            return
        st = dict(self.player.state)
        pos = int(self.player.position)
        self.discord.client_id = self.settings.get("discord_client_id") or DEFAULT_DISCORD_CLIENT_ID
        self.worker.run(
            lambda: self.discord.update_activity(st, pos),
            lambda _: self.changed.emit(),
            lambda e: None,
        )

    def _periodic_check(self):
        st = self.player.state
        if not st.get("hasTrack") or not st.get("isPlaying"):
            return
        if self._scrobbled_current or not self._current_uri:
            return
        dur_ms = int(st.get("durationMs") or 0)
        pos_ms = int(self.player.position or 0)
        threshold_ms = min(240_000, max(15_000, dur_ms // 2)) if dur_ms > 0 else 30_000
        if pos_ms >= threshold_ms:
            self._scrobbled_current = True
            track_copy = dict(st)
            started = self._started_at or int(time.time())
            self.worker.run(
                lambda: self.scrobbler.enqueue_scrobble(track_copy, started),
                lambda _: self.changed.emit(),
                lambda e: None,
            )

    def shutdown(self):
        self._timer.stop()
        self.discord.close()
