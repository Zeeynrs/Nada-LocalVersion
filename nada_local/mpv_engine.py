"""Direct libmpv audio engine wrapper (zero external pip dependencies required)."""

import ctypes
import ctypes.util
import json
import locale

MPV_EVENT_NONE = 0
MPV_EVENT_END_FILE = 7
MPV_EVENT_FILE_LOADED = 8

MPV_END_FILE_REASON_EOF = 0
MPV_END_FILE_REASON_ERROR = 4

EQ_FREQS = (60, 150, 400, 1000, 2000, 15000)


class _MpvEventEndFile(ctypes.Structure):
    _fields_ = [
        ("reason", ctypes.c_int),
        ("error", ctypes.c_int),
        ("playlist_entry_id", ctypes.c_int64),
        ("playlist_insert_id", ctypes.c_int64),
        ("playlist_insert_num_entries", ctypes.c_int),
    ]


class _MpvEvent(ctypes.Structure):
    _fields_ = [
        ("event_id", ctypes.c_int),
        ("error", ctypes.c_int),
        ("reply_userdata", ctypes.c_uint64),
        ("data", ctypes.c_void_p),
    ]


def _load_libmpv():
    for candidate in ("libmpv.so.2", "libmpv.so", ctypes.util.find_library("mpv")):
        if not candidate:
            continue
        try:
            lib = ctypes.CDLL(candidate)
            lib.mpv_create.restype = ctypes.c_void_p
            lib.mpv_initialize.argtypes = [ctypes.c_void_p]
            lib.mpv_initialize.restype = ctypes.c_int
            lib.mpv_set_option_string.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
            lib.mpv_set_option_string.restype = ctypes.c_int
            lib.mpv_set_property_string.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
            lib.mpv_set_property_string.restype = ctypes.c_int
            lib.mpv_get_property_string.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
            lib.mpv_get_property_string.restype = ctypes.c_void_p
            lib.mpv_command.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_char_p)]
            lib.mpv_command.restype = ctypes.c_int
            lib.mpv_wait_event.argtypes = [ctypes.c_void_p, ctypes.c_double]
            lib.mpv_wait_event.restype = ctypes.POINTER(_MpvEvent)
            lib.mpv_free.argtypes = [ctypes.c_void_p]
            lib.mpv_terminate_destroy.argtypes = [ctypes.c_void_p]
            return lib
        except OSError:
            continue
    return None


class MpvEngine:
    """High-level audio controller backed by libmpv."""

    def __init__(self, settings):
        locale.setlocale(locale.LC_NUMERIC, "C")
        self._lib = _load_libmpv()
        self._ctx = None
        self.version = ""
        self._seg_start_ms = 0
        self._seg_end_ms = 0
        self._pending_seek_ms = 0
        if not self._lib:
            return

        ctx = self._lib.mpv_create()
        if not ctx:
            return
        self._ctx = ctx

        self._set_opt("vo", "null")
        self._set_opt("vid", "no")
        self._set_opt("audio-display", "no")
        self._set_opt("audio-client-name", "Nada Local")
        self._set_opt("volume-max", "100")
        self._set_opt("keep-open", "no")
        self._set_opt("gapless-audio", str(settings.get("gapless", "weak")))
        self._set_opt("replaygain", str(settings.get("replaygain", "no")))

        dev = settings.get("audio_device", "auto")
        if dev and dev != "auto":
            self._set_opt("audio-device", str(dev))

        if self._lib.mpv_initialize(ctx) < 0:
            self._lib.mpv_terminate_destroy(ctx)
            self._ctx = None
            return

        self.version = self.get_str("mpv-version") or "libmpv"
        self.set_volume(settings.get("volume", 85))
        self.set_speed(settings.get("tempo", 1.0), settings.get("keep_pitch", True))
        self.set_equalizer(settings.get("eq_enabled", False), settings.get("eq_bands", [0.0] * 6))

    @property
    def available(self) -> bool:
        return self._ctx is not None

    def _set_opt(self, name: str, value: str):
        if self._ctx:
            self._lib.mpv_set_option_string(self._ctx, name.encode("utf-8"), value.encode("utf-8"))

    def set_prop(self, name: str, value: str):
        if self._ctx:
            self._lib.mpv_set_property_string(self._ctx, name.encode("utf-8"), value.encode("utf-8"))

    def get_str(self, name: str) -> str:
        if not self._ctx:
            return ""
        ptr = self._lib.mpv_get_property_string(self._ctx, name.encode("utf-8"))
        if not ptr:
            return ""
        try:
            return ctypes.string_at(ptr).decode("utf-8", errors="replace")
        finally:
            self._lib.mpv_free(ptr)

    def command(self, *args: str):
        if not self._ctx:
            return
        arr_type = ctypes.c_char_p * (len(args) + 1)
        arr = arr_type(*(a.encode("utf-8") for a in args), None)
        self._lib.mpv_command(self._ctx, arr)

    # ---- Playback control ------------------------------------------------

    def play_file(self, filepath: str, start_ms: int = 0, end_ms: int = 0):
        if not self._ctx:
            return
        self._seg_start_ms = max(0, int(start_ms or 0))
        self._seg_end_ms = max(0, int(end_ms or 0))
        self._pending_seek_ms = self._seg_start_ms
        self.command("loadfile", filepath, "replace")
        self.set_prop("pause", "no")

    def stop_playback(self):
        self._seg_start_ms = 0
        self._seg_end_ms = 0
        self._pending_seek_ms = 0
        if self._ctx:
            self.command("stop")

    def set_pause(self, paused: bool):
        self.set_prop("pause", "yes" if paused else "no")

    def is_paused(self) -> bool:
        return self.get_str("pause") == "yes"

    def seek_ms(self, ms: int):
        abs_ms = self._seg_start_ms + max(0, int(ms))
        if self._seg_end_ms > 0:
            abs_ms = min(abs_ms, self._seg_end_ms)
        sec = max(0.0, abs_ms / 1000.0)
        self.command("seek", f"{sec:.3f}", "absolute")

    def set_volume(self, pct: int):
        self.set_prop("volume", str(max(0, min(100, int(pct)))))

    def _raw_position_ms(self) -> int:
        val = self.get_str("time-pos")
        try:
            return max(0, int(float(val) * 1000))
        except ValueError:
            return 0

    def get_position_ms(self) -> int:
        return max(0, self._raw_position_ms() - self._seg_start_ms)

    def get_duration_ms(self) -> int:
        if self._seg_end_ms > self._seg_start_ms > 0 or self._seg_end_ms > 0:
            return max(0, self._seg_end_ms - self._seg_start_ms)
        val = self.get_str("duration")
        try:
            raw_dur = max(0, int(float(val) * 1000))
            return max(0, raw_dur - self._seg_start_ms)
        except ValueError:
            return 0

    # ---- Audio DSP: Equalizer, Speed & Pitch, ReplayGain, Devices ---------

    def set_speed(self, tempo: float, keep_pitch: bool):
        tempo = max(0.5, min(2.0, float(tempo)))
        self.set_prop("audio-pitch-correction", "yes" if keep_pitch else "no")
        self.set_prop("speed", f"{tempo:.3f}")

    def set_equalizer(self, enabled: bool, bands: list):
        if not self._ctx:
            return
        if not enabled or not bands or all(abs(float(b)) < 0.005 for b in bands):
            self.set_prop("af", "")
            return
        parts = []
        for freq, norm_gain in zip(EQ_FREQS, bands):
            db = max(-12.0, min(12.0, float(norm_gain) * 12.0))
            if abs(db) >= 0.05:
                parts.append(f"equalizer=f={freq}:width_type=o:w=1.8:g={db:.2f}")
        af_str = f"lavfi=[{','.join(parts)}]" if parts else ""
        self.set_prop("af", af_str)

    def set_gapless(self, mode: str):
        if mode in ("no", "weak", "yes"):
            self.set_prop("gapless-audio", mode)

    def set_replaygain(self, mode: str):
        if mode in ("no", "track", "album"):
            self.set_prop("replaygain", mode)

    def set_audio_device(self, dev_id: str):
        self.set_prop("audio-device", dev_id or "auto")

    def get_audio_devices(self, active_id: str = "auto") -> list:
        raw = self.get_str("audio-device-list")
        if not raw:
            return [{"id": "auto", "name": "Otomatis (Sistem)", "type": "computer", "active": True, "local": True}]
        try:
            items = json.loads(raw)
        except ValueError:
            items = []

        has_pipewire = any(str(d.get("name", "")).startswith("pipewire/") for d in items)
        result = []
        seen_desc = set()
        for d in items:
            name = d.get("name") or ""
            desc = d.get("description") or name
            if name == "auto":
                result.append({
                    "id": "auto",
                    "name": "Otomatis (Default Sistem)",
                    "type": "computer",
                    "active": active_id == "auto",
                    "local": True,
                    "restricted": False,
                })
                continue
            # Prefer pipewire sinks on modern Linux; skip duplicate pulse/alsa entries
            if has_pipewire and not name.startswith("pipewire/"):
                continue
            if not has_pipewire and not (name.startswith("pulse/") or name.startswith("alsa/")):
                continue
            if desc in seen_desc:
                continue
            seen_desc.add(desc)
            dev_type = "speaker"
            low = desc.lower()
            if "headphone" in low or "headset" in low or "earbud" in low:
                dev_type = "smartphone"
            elif "built-in" in low or "analog" in low:
                dev_type = "computer"
            result.append({
                "id": name,
                "name": desc,
                "type": dev_type,
                "active": active_id == name,
                "local": True,
                "restricted": False,
            })
        return result

    # ---- Event polling ---------------------------------------------------

    def poll_events(self):
        """Drain pending libmpv events without blocking.

        Returns (file_loaded: bool, eof_reached: bool, error_msg: str).
        """
        if not self._ctx:
            return False, False, ""
        loaded = False
        eof = False
        err_msg = ""
        while True:
            ev_ptr = self._lib.mpv_wait_event(self._ctx, 0.0)
            if not ev_ptr:
                break
            ev_id = ev_ptr.contents.event_id
            if ev_id == MPV_EVENT_NONE:
                break
            if ev_id == MPV_EVENT_FILE_LOADED:
                loaded = True
                if self._pending_seek_ms > 0:
                    sec = self._pending_seek_ms / 1000.0
                    self.command("seek", f"{sec:.3f}", "absolute")
                    self._pending_seek_ms = 0
            elif ev_id == MPV_EVENT_END_FILE and ev_ptr.contents.data:
                end = ctypes.cast(ev_ptr.contents.data, ctypes.POINTER(_MpvEventEndFile)).contents
                if end.reason == MPV_END_FILE_REASON_EOF:
                    eof = True
                elif end.reason == MPV_END_FILE_REASON_ERROR:
                    err_msg = "Format file audio tidak didukung atau file rusak."
        if not eof and self._seg_end_ms > 0 and self._raw_position_ms() >= self._seg_end_ms:
            eof = True
        return loaded, eof, err_msg

    def shutdown(self):
        if self._ctx and self._lib:
            ctx = self._ctx
            self._ctx = None
            self._lib.mpv_terminate_destroy(ctx)
