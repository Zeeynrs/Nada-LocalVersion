"""User-facing settings and desktop integration exposed to QML."""

import os
from pathlib import Path
from urllib.parse import unquote

from PySide6.QtCore import Property, QObject, QUrl, Signal, Slot
from PySide6.QtGui import QDesktopServices, QGuiApplication


class Session(QObject):
    changed = Signal()
    toast = Signal(str)

    def __init__(self, settings, player, library, worker, parent=None):
        super().__init__(parent)
        self.settings = settings
        self.player = player
        self.library = library
        self.worker = worker
        worker.error.connect(self.toast)
        library.toast.connect(self.toast)

    @Property(bool, constant=True)
    def authenticated(self):
        return True

    @Slot(str)
    def copy(self, text):
        QGuiApplication.clipboard().setText(text)
        self.toast.emit("Disalin ke clipboard")

    @Slot(str)
    def openUrl(self, url):
        QDesktopServices.openUrl(QUrl(url))

    @Slot(str)
    def openContainingFolder(self, filepath):
        if filepath.startswith("file://"):
            filepath = unquote(filepath[7:])
        p = Path(filepath)
        folder = p.parent if p.is_file() else p
        if folder.exists():
            QDesktopServices.openUrl(QUrl.fromLocalFile(str(folder)))

    # ---- Music folder management -----------------------------------------

    @Property("QVariantList", notify=changed)
    def musicDirs(self):
        return list(self.settings["music_dirs"])

    @Slot(str)
    def addMusicDir(self, raw_path: str):
        raw_path = raw_path.strip()
        if not raw_path:
            return
        if raw_path.startswith("file://"):
            raw_path = unquote(raw_path[7:])
        expanded = str(Path(os.path.expanduser(raw_path)).resolve())
        if not Path(expanded).is_dir():
            self.toast.emit(f"Folder tidak ditemukan: {expanded}")
            return
        dirs = list(self.settings["music_dirs"])
        if expanded not in dirs:
            dirs.append(expanded)
            self.settings["music_dirs"] = dirs
            self.changed.emit()
            self.library.refreshAll()
            self.toast.emit(f"Folder ditambahkan: {expanded}")

    @Slot(str)
    def removeMusicDir(self, path: str):
        dirs = [d for d in self.settings["music_dirs"] if d != path]
        if not dirs:
            self.toast.emit("Minimal satu folder musik harus dipertahankan")
            return
        self.settings["music_dirs"] = dirs
        self.changed.emit()
        self.library.refreshAll()
        self.toast.emit("Folder dihapus dari pustaka")

    # ---- Audio & visual settings -----------------------------------------

    @Property(str, notify=changed)
    def gapless(self):
        return str(self.settings["gapless"])

    @gapless.setter
    def gapless(self, value: str):
        self.settings["gapless"] = value
        self.player.mpv.set_gapless(value)
        self.changed.emit()

    @Property(str, notify=changed)
    def replaygain(self):
        return str(self.settings["replaygain"])

    @replaygain.setter
    def replaygain(self, value: str):
        self.settings["replaygain"] = value
        self.player.mpv.set_replaygain(value)
        self.changed.emit()

    @Property(bool, notify=changed)
    def onlineLyrics(self):
        return bool(self.settings["online_lyrics"])

    @onlineLyrics.setter
    def onlineLyrics(self, value: bool):
        self.settings["online_lyrics"] = bool(value)
        self.changed.emit()

    @Property(bool, notify=changed)
    def visualizerEnabled(self):
        return bool(self.settings["visualizer"])

    @visualizerEnabled.setter
    def visualizerEnabled(self, value: bool):
        self.settings["visualizer"] = bool(value)
        self.changed.emit()

    @Property(str, notify=changed)
    def visualizerStyle(self):
        return str(self.settings["visualizer_style"])

    @visualizerStyle.setter
    def visualizerStyle(self, value: str):
        self.settings["visualizer_style"] = str(value)
        self.changed.emit()
