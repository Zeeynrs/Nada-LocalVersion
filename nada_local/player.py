"""Local Hi-Fi playback state and queue controller backed by libmpv."""

import colorsys
import random
import time
from pathlib import Path
from urllib.parse import unquote

from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot
from PySide6.QtGui import QImage

from .mpv_engine import MpvEngine
from .scanner import LibraryDB

DEFAULT_ACCENT = "#9ecaff"


def read_art_bytes(uri: str) -> bytes:
    if not uri:
        return b""
    if uri.startswith("file://"):
        p = Path(unquote(uri[7:]))
        if p.is_file():
            return p.read_bytes()
    return b""


def accent_from_image(data: bytes) -> str:
    """Pick a lively, readable-on-dark colour from album art."""
    if not data:
        return DEFAULT_ACCENT
    img = QImage.fromData(data)
    if img.isNull():
        return DEFAULT_ACCENT
    img = img.scaled(24, 24)
    bins = [[0.0, 0.0, 0.0, 0.0] for _ in range(12)]
    for y in range(img.height()):
        for x in range(img.width()):
            c = img.pixelColor(x, y)
            r, g, b = c.redF(), c.greenF(), c.blueF()
            h, s, v = colorsys.rgb_to_hsv(r, g, b)
            w = s * s * v + 0.002
            slot = bins[int(h * 12) % 12]
            slot[0] += w
            slot[1] += r * w
            slot[2] += g * w
            slot[3] += b * w
    w, r, g, b = max(bins, key=lambda b: b[0])
    h, s, v = colorsys.rgb_to_hsv(r / w, g / w, b / w)
    s = min(max(s, 0.35), 0.75) if s > 0.08 else s
    v = max(v, 0.82)
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return "#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255))


class Player(QObject):
    stateChanged = Signal()
    positionChanged = Signal()
    devicesChanged = Signal()
    queueChanged = Signal()
    accentChanged = Signal()
    trackChanged = Signal()
    likedChanged = Signal(str, bool)
    dspChanged = Signal()
    sleepChanged = Signal()

    def __init__(self, db: LibraryDB, worker, settings, parent=None):
        super().__init__(parent)
        self.db = db
        self.worker = worker
        self.settings = settings
        self.mpv = MpvEngine(settings)

        self._playlist: list[dict] = []
        self._original_playlist: list[dict] = []
        self._manual_queue: list[dict] = []
        self._index: int = -1
        self._context_uri: str = ""
        self._position_ms: int = 0
        self._accent: str = DEFAULT_ACCENT
        self._devices: list[dict] = []
        self._switching_track: bool = False

        self._sleep_mode: str = "off"
        self._sleep_deadline: float = 0.0
        self._sleep_remaining: int = 0
        self._sleep_pre_fade_vol: int | None = None

        self._state = {
            "hasTrack": False,
            "isPlaying": False,
            "shuffle": bool(settings.get("shuffle", False)),
            "repeat": settings.get("repeat", "off"),
            "volume": int(settings.get("volume", 85)),
            "supportsVolume": True,
            "deviceId": settings.get("audio_device", "auto"),
            "deviceName": "Output Sistem",
            "deviceType": "computer",
            "contextUri": "",
            "liked": False,
        }

        self.tick_timer = QTimer(self)
        self.tick_timer.setInterval(120)
        self.tick_timer.timeout.connect(self._tick)

    # ---- properties -----------------------------------------------------

    @Property("QVariantMap", notify=stateChanged)
    def state(self):
        return self._state

    @Property(int, notify=positionChanged)
    def position(self):
        return self._position_ms

    @Property("QVariantList", notify=devicesChanged)
    def devices(self):
        return self._devices

    @Property("QVariantList", notify=queueChanged)
    def queue(self):
        upcoming = list(self._manual_queue)
        if 0 <= self._index < len(self._playlist):
            upcoming.extend(self._playlist[self._index + 1:self._index + 31])
        return upcoming[:30]

    @Property(str, notify=accentChanged)
    def accent(self):
        return self._accent

    @Property(bool, constant=True)
    def mpvAvailable(self):
        return self.mpv.available

    @Property(str, constant=True)
    def mpvVersion(self):
        return self.mpv.version

    # ---- Equalizer & Tempo/Pitch properties -----------------------------

    @Property(bool, notify=dspChanged)
    def eqEnabled(self):
        return bool(self.settings["eq_enabled"])

    @Property(str, notify=dspChanged)
    def eqPreset(self):
        return str(self.settings["eq_preset"])

    @Property("QVariantList", notify=dspChanged)
    def eqBands(self):
        return list(self.settings["eq_bands"])

    @Property(float, notify=dspChanged)
    def tempo(self):
        return float(self.settings["tempo"])

    @Property(bool, notify=dspChanged)
    def keepPitch(self):
        return bool(self.settings["keep_pitch"])

    @Slot(bool)
    def setEqEnabled(self, on: bool):
        self.settings["eq_enabled"] = bool(on)
        self.mpv.set_equalizer(bool(on), self.settings["eq_bands"])
        self.dspChanged.emit()

    @Slot(int, float)
    def setEqBand(self, index: int, val: float):
        bands = list(self.settings["eq_bands"])
        if 0 <= index < len(bands):
            bands[index] = max(-1.0, min(1.0, float(val)))
            self.settings["eq_bands"] = bands
            self.settings["eq_preset"] = "Custom"
            self.mpv.set_equalizer(self.settings["eq_enabled"], bands)
            self.dspChanged.emit()

    @Slot(str, "QVariantList")
    def setEqPreset(self, name: str, bands: list):
        clean = [max(-1.0, min(1.0, float(b))) for b in bands[:6]]
        while len(clean) < 6:
            clean.append(0.0)
        self.settings["eq_preset"] = name
        self.settings["eq_bands"] = clean
        self.mpv.set_equalizer(self.settings["eq_enabled"], clean)
        self.dspChanged.emit()

    @Slot(float)
    def setTempo(self, val: float):
        t = round(max(0.5, min(2.0, float(val))) * 20) / 20
        self.settings["tempo"] = t
        self.mpv.set_speed(t, self.settings["keep_pitch"])
        self.dspChanged.emit()

    @Slot(bool)
    def setKeepPitch(self, on: bool):
        self.settings["keep_pitch"] = bool(on)
        self.mpv.set_speed(self.settings["tempo"], bool(on))
        self.dspChanged.emit()

    # ---- Sleep Timer + Smooth Volume Fade-Out ---------------------------

    @Property(str, notify=sleepChanged)
    def sleepMode(self):
        return self._sleep_mode

    @Property(int, notify=sleepChanged)
    def sleepRemainingSec(self):
        return self._sleep_remaining

    @Property(str, notify=sleepChanged)
    def sleepLabel(self):
        if self._sleep_mode == "off":
            return ""
        if self._sleep_mode == "end_of_track":
            return "Akhir lagu"
        m, s = divmod(max(0, self._sleep_remaining), 60)
        return f"{m}:{s:02d}"

    @Slot(str)
    def setSleepTimer(self, mode: str):
        # Restore original volume if cancelling during a fade
        if self._sleep_pre_fade_vol is not None:
            self.mpv.set_volume(self._sleep_pre_fade_vol)
            self._sleep_pre_fade_vol = None

        mode = (mode or "off").strip()
        if mode in ("15", "30", "45", "60"):
            mins = int(mode)
            self._sleep_mode = mode
            self._sleep_deadline = time.monotonic() + mins * 60
            self._sleep_remaining = mins * 60
            self.worker.error.emit(f"Sleep Timer diatur: {mins} menit")
        elif mode == "end_of_track":
            self._sleep_mode = "end_of_track"
            self._sleep_deadline = 0.0
            self._sleep_remaining = 0
            self.worker.error.emit("Sleep Timer: berhenti setelah lagu ini selesai")
        else:
            self._sleep_mode = "off"
            self._sleep_deadline = 0.0
            self._sleep_remaining = 0
        self.sleepChanged.emit()

    def _check_sleep_timer(self):
        if self._sleep_mode not in ("15", "30", "45", "60") or self._sleep_deadline <= 0:
            return
        rem = self._sleep_deadline - time.monotonic()
        sec = max(0, int(rem))
        if sec != self._sleep_remaining:
            self._sleep_remaining = sec
            self.sleepChanged.emit()

        # Smooth fade out over the final 10 seconds
        if 0 < rem <= 10.0 and self._state.get("isPlaying"):
            if self._sleep_pre_fade_vol is None:
                self._sleep_pre_fade_vol = int(self._state.get("volume", 85))
            faded_vol = max(1, int(self._sleep_pre_fade_vol * (rem / 10.0)))
            self.mpv.set_volume(faded_vol)
        elif rem <= 0:
            orig_vol = self._sleep_pre_fade_vol if self._sleep_pre_fade_vol is not None else int(self._state.get("volume", 85))
            self._sleep_pre_fade_vol = None
            self._sleep_mode = "off"
            self._sleep_deadline = 0.0
            self._sleep_remaining = 0
            self.mpv.set_pause(True)
            self.mpv.set_volume(orig_vol)
            self._patch(isPlaying=False)
            self.sleepChanged.emit()
            self.worker.error.emit("Sleep Timer selesai — pemutaran dijeda")

    # ---- lifecycle & tick -----------------------------------------------

    def start(self):
        self.refreshDevices()
        self.tick_timer.start()

    def stop(self):
        self.tick_timer.stop()
        self.mpv.stop_playback()
        self.mpv.shutdown()

    @Slot(bool)
    def setFastPolling(self, fast: bool):
        self.tick_timer.setInterval(100 if fast else 300)

    def _tick(self):
        self._check_sleep_timer()
        loaded, eof, err_msg = self.mpv.poll_events()
        if err_msg:
            self.worker.error.emit(err_msg)
        if loaded and self._state.get("hasTrack"):
            dur = self.mpv.get_duration_ms()
            if dur > 0 and dur != self._state.get("durationMs"):
                self._patch(durationMs=dur)
        if eof and not self._switching_track:
            self._on_track_finished()
            return
        if self._state.get("hasTrack") and self._state.get("isPlaying"):
            pos = self.mpv.get_position_ms()
            if pos != self._position_ms:
                self._position_ms = pos
                self.positionChanged.emit()

    def _on_track_finished(self):
        if self._sleep_mode == "end_of_track":
            self._sleep_mode = "off"
            self._sleep_remaining = 0
            self.mpv.stop_playback()
            self._position_ms = 0
            self._patch(isPlaying=False)
            self.positionChanged.emit()
            self.sleepChanged.emit()
            self.worker.error.emit("Sleep Timer selesai — berhenti di akhir lagu")
            return
        rep = self._state.get("repeat", "off")
        if rep == "track" and self._state.get("hasTrack"):
            self.seek(0)
            self.mpv.set_pause(False)
            self._patch(isPlaying=True)
            return
        self._advance(auto=True)

    # ---- playback commands ----------------------------------------------

    def _load_current_track(self, track: dict):
        self._switching_track = True
        old_uri = self._state.get("uri")
        filepath = track.get("path") or ""
        if not filepath and track.get("uri", "").startswith("file://"):
            filepath = unquote(track["uri"][7:])

        self.mpv.play_file(filepath)
        self._position_ms = 0
        self._state = {
            **self._state,
            **track,
            "hasTrack": True,
            "isPlaying": True,
            "contextUri": self._context_uri,
            "liked": self.db.is_liked(track["uri"]),
        }
        self._switching_track = False
        self.stateChanged.emit()
        self.positionChanged.emit()
        self.queueChanged.emit()

        if track.get("uri") != old_uri:
            self.trackChanged.emit()
            self.worker.run(lambda: self.db.record_play(track["uri"]), lambda _: None, lambda e: None)
            art_uri = track.get("image") or ""
            if art_uri:
                self.worker.run(
                    lambda: read_art_bytes(art_uri),
                    lambda data: self._set_accent(accent_from_image(data)),
                    lambda e: None,
                )
            else:
                self._set_accent(DEFAULT_ACCENT)

    def _set_accent(self, color: str):
        if color != self._accent:
            self._accent = color
            self.accentChanged.emit()

    def _patch(self, **values):
        self._state = {**self._state, **values}
        self.stateChanged.emit()

    def _advance(self, auto: bool = False):
        if self._manual_queue:
            nxt_track = self._manual_queue.pop(0)
            self._load_current_track(nxt_track)
            return
        if not self._playlist:
            self._patch(isPlaying=False)
            return
        nxt_idx = self._index + 1
        if nxt_idx >= len(self._playlist):
            if self._state.get("repeat") == "context" or not auto:
                nxt_idx = 0
            else:
                self.mpv.stop_playback()
                self._position_ms = 0
                self._patch(isPlaying=False)
                self.positionChanged.emit()
                return
        self._index = nxt_idx
        self._load_current_track(self._playlist[self._index])

    @Slot()
    def togglePlay(self):
        if not self._state.get("hasTrack"):
            all_tracks = self.db.get_all_tracks()
            if all_tracks:
                self._start_playlist(all_tracks, 0, "local:playlist:all")
            else:
                self.worker.error.emit("Belum ada lagu di pustaka lokal. Tambahkan folder musik di Pengaturan.")
            return
        playing = not self._state.get("isPlaying", False)
        self.mpv.set_pause(not playing)
        self._patch(isPlaying=playing)

    @Slot()
    def next(self):
        self._advance(auto=False)

    @Slot(int)
    def skip(self, count: int):
        count = max(1, int(count))
        while count > 0 and self._manual_queue:
            nxt = self._manual_queue.pop(0)
            count -= 1
            if count == 0:
                self._load_current_track(nxt)
                return
        if self._playlist:
            self._index = min(len(self._playlist) - 1, self._index + count)
            self._load_current_track(self._playlist[self._index])

    @Slot()
    def previous(self):
        if self.position > 3500:
            self.seek(0)
            return
        if not self._playlist:
            self.seek(0)
            return
        self._index = (self._index - 1) % len(self._playlist)
        self._load_current_track(self._playlist[self._index])

    @Slot(int)
    def seek(self, ms: int):
        ms = max(0, int(ms))
        self._position_ms = ms
        self.mpv.seek_ms(ms)
        self.positionChanged.emit()

    @Slot(int)
    def setVolume(self, pct: int):
        vol = max(0, min(100, int(pct)))
        self.settings["volume"] = vol
        self.mpv.set_volume(vol)
        self._patch(volume=vol)

    @Slot()
    def toggleShuffle(self):
        shuf = not self._state.get("shuffle", False)
        self.settings["shuffle"] = shuf
        self._patch(shuffle=shuf)
        if not self._playlist or self._index < 0:
            return
        cur_track = self._playlist[self._index]
        if shuf:
            rest = [t for i, t in enumerate(self._playlist) if i != self._index]
            random.shuffle(rest)
            self._playlist = [cur_track] + rest
            self._index = 0
        else:
            self._playlist = list(self._original_playlist)
            for i, t in enumerate(self._playlist):
                if t.get("uri") == cur_track.get("uri"):
                    self._index = i
                    break
        self.queueChanged.emit()

    @Slot()
    def cycleRepeat(self):
        nxt = {"off": "context", "context": "track", "track": "off"}.get(self._state.get("repeat", "off"), "off")
        self.settings["repeat"] = nxt
        self._patch(repeat=nxt)

    def _start_playlist(self, tracks: list[dict], start_index: int = 0, context_uri: str = ""):
        if not tracks:
            self.worker.error.emit("Tidak ada lagu untuk diputar.")
            return
        self._context_uri = context_uri
        self._original_playlist = list(tracks)
        start_index = max(0, min(len(tracks) - 1, int(start_index)))
        target = tracks[start_index]
        if self._state.get("shuffle"):
            rest = [t for i, t in enumerate(tracks) if i != start_index]
            random.shuffle(rest)
            self._playlist = [target] + rest
            self._index = 0
        else:
            self._playlist = list(tracks)
            self._index = start_index
        self._load_current_track(self._playlist[self._index])

    @Slot(str, str)
    def playContext(self, context_uri: str, offset_uri: str = ""):
        tracks = self.db.get_context_tracks(context_uri)
        idx = 0
        if offset_uri:
            for i, t in enumerate(tracks):
                if t.get("uri") == offset_uri:
                    idx = i
                    break
        self._start_playlist(tracks, idx, context_uri)

    @Slot("QVariantList", int)
    def playUris(self, uris: list, index: int = 0):
        clean_uris = [str(u) for u in uris if u]
        tracks = self.db.get_tracks_by_uris(clean_uris)
        self._start_playlist(tracks, index, "")

    @Slot("QVariantList")
    def playFiles(self, paths: list):
        clean = [unquote(str(p)[7:]) if str(p).startswith("file://") else str(p) for p in paths if p]
        tracks = self.db.ingest_files(clean)
        if tracks:
            self._start_playlist(tracks, 0, "")

    @Slot(str)
    def shufflePlay(self, context_uri: str):
        if not self._state.get("shuffle"):
            self.settings["shuffle"] = True
            self._patch(shuffle=True)
        tracks = self.db.get_context_tracks(context_uri)
        if tracks:
            start_idx = random.randint(0, len(tracks) - 1)
            self._start_playlist(tracks, start_idx, context_uri)

    @Slot(str)
    def addToQueue(self, uri: str):
        t = self.db.get_track(uri)
        if t:
            self._manual_queue.append(t)
            self.queueChanged.emit()
            self.worker.error.emit("Ditambahkan ke antrean")

    @Slot()
    def toggleLike(self):
        uri = self._state.get("uri")
        if uri:
            self.setLiked(uri, not self._state.get("liked", False))

    @Slot(str, bool)
    def setLiked(self, uri: str, liked: bool):
        self.db.set_liked(uri, bool(liked))
        if uri == self._state.get("uri"):
            self._patch(liked=bool(liked))
        self.likedChanged.emit(uri, bool(liked))

    # ---- Audio output devices & queue -----------------------------------

    @Slot()
    def refreshDevices(self):
        active_id = self.settings.get("audio_device", "auto")
        devs = self.mpv.get_audio_devices(active_id)
        self._devices = devs
        active_dev = next((d for d in devs if d.get("active")), devs[0] if devs else {})
        self._patch(
            deviceId=active_dev.get("id", "auto"),
            deviceName=active_dev.get("name", "Otomatis"),
            deviceType=active_dev.get("type", "computer"),
        )
        self.devicesChanged.emit()

    @Slot(str)
    def transfer(self, device_id: str):
        device_id = device_id or "auto"
        self.settings["audio_device"] = device_id
        self.mpv.set_audio_device(device_id)
        self.refreshDevices()

    @Slot()
    def refreshQueue(self):
        self.queueChanged.emit()
