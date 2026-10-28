"""Audio spectrum bars from cava (reads the PipeWire output monitor)."""

import shutil

from PySide6.QtCore import Property, QObject, QProcess, Signal, Slot

from .config import CACHE_DIR

BARS = 64
CAVA_CONFIG = f"""
[general]
bars = {BARS}
framerate = 60
autosens = 1
lower_cutoff_freq = 35
higher_cutoff_freq = 14000

[input]
method = pipewire
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59
frame_delimiter = 10
channels = mono

[smoothing]
noise_reduction = 62
"""


class Visualizer(QObject):
    barsChanged = Signal()
    activeChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._bars = [0.0] * BARS
        self._active = False
        self._buf = b""
        self.proc = QProcess(self)
        self.proc.readyReadStandardOutput.connect(self._read)

    @Property(bool, constant=True)
    def available(self):
        return shutil.which("cava") is not None

    @Property(int, constant=True)
    def count(self):
        return BARS

    @Property("QVariantList", notify=barsChanged)
    def bars(self):
        return self._bars

    def _get_active(self):
        return self._active

    @Slot(bool)
    def _set_active(self, on):
        on = bool(on) and self.available
        if on == self._active:
            return
        self._active = on
        if on:
            CACHE_DIR.mkdir(parents=True, exist_ok=True)
            conf = CACHE_DIR / "cava.conf"
            conf.write_text(CAVA_CONFIG)
            self.proc.start(shutil.which("cava"), ["-p", str(conf)])
        else:
            self.stop()
            self._bars = [0.0] * BARS
            self.barsChanged.emit()
        self.activeChanged.emit()

    active = Property(bool, _get_active, _set_active, notify=activeChanged)

    def _read(self):
        self._buf += bytes(self.proc.readAllStandardOutput())
        frames = self._buf.split(b"\n")
        self._buf = frames[-1]
        if len(frames) < 2:
            return
        last = frames[-2].decode(errors="ignore").strip(";").split(";")
        if len(last) == BARS:
            try:
                self._bars = [int(v) / 1000 for v in last]
            except ValueError:
                return
            self.barsChanged.emit()

    def stop(self):
        if self.proc.state() != QProcess.NotRunning:
            self.proc.terminate()
            if not self.proc.waitForFinished(1000):
                self.proc.kill()
