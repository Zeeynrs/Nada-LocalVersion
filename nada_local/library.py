"""Local library browsing: home, playlists, albums, artists, liked songs, and search."""

import getpass
from PySide6.QtCore import Property, QObject, Signal, Slot

from .scanner import LibraryDB


class Library(QObject):
    meChanged = Signal()
    playlistsChanged = Signal()
    homeChanged = Signal()
    scanningChanged = Signal()
    loaded = Signal(str, "QVariantMap")
    searchFinished = Signal(str, "QVariantMap")
    toast = Signal(str)

    def __init__(self, db: LibraryDB, settings, worker, parent=None):
        super().__init__(parent)
        self.db = db
        self.settings = settings
        self.worker = worker
        self._scanning = False
        self._stats = {"tracks": 0, "albums": 0, "artists": 0}
        username = getpass.getuser().capitalize()
        self._me = {"id": "local", "name": username, "image": ""}
        self._playlists = []
        self._home = {"recent": [], "topTracks": [], "topArtists": []}

    @Property("QVariantMap", notify=meChanged)
    def me(self):
        return self._me

    @Property("QVariantList", notify=playlistsChanged)
    def playlists(self):
        return self._playlists

    @Property("QVariantMap", notify=homeChanged)
    def home(self):
        return self._home

    @Property(bool, notify=scanningChanged)
    def scanning(self):
        return self._scanning

    @Property("QVariantMap", notify=meChanged)
    def stats(self):
        return self._stats

    def _set_scanning(self, val: bool):
        if self._scanning != val:
            self._scanning = val
            self.scanningChanged.emit()

    @Slot()
    def refreshAll(self):
        if self._scanning:
            return
        self._set_scanning(True)
        dirs = list(self.settings["music_dirs"])

        def job():
            scan_res = self.db.scan_directories(dirs)
            st = self.db.stats()
            pls = self.db.get_playlists()
            hm = self.db.get_home()
            return scan_res, st, pls, hm

        def done(res):
            self._set_scanning(False)
            _, st, pls, hm = res
            self._stats = st
            self._playlists = pls
            self._home = hm
            self.meChanged.emit()
            self.playlistsChanged.emit()
            self.homeChanged.emit()

        def failed(e):
            self._set_scanning(False)
            self.toast.emit(f"Gagal memindai folder musik: {e}")

        self.worker.run(job, done, failed)

    def reloadMetadataOnly(self):
        def job():
            return self.db.stats(), self.db.get_playlists(), self.db.get_home()

        def done(res):
            st, pls, hm = res
            self._stats = st
            self._playlists = pls
            self._home = hm
            self.meChanged.emit()
            self.playlistsChanged.emit()
            self.homeChanged.emit()

        self.worker.run(job, done, lambda e: None)

    # ---- pages ------------------------------------------------------------

    @Slot(str, str)
    def load(self, kind: str, item_id: str):
        key = f"{kind}:{item_id}"

        def fetch():
            if kind == "playlist":
                return self.db.get_playlist(item_id or "all")
            if kind == "album":
                return self.db.get_album(item_id)
            if kind == "artist":
                return self.db.get_artist(item_id)
            if kind == "liked":
                tracks = self.db.get_liked_tracks()
                img = next((t["image"] for t in tracks if t.get("image")), "")
                return {
                    "kind": "liked",
                    "name": "Lagu yang Disukai",
                    "typeLabel": "Koleksi Favorit",
                    "subtitle": f"{len(tracks)} lagu disimpan secara lokal",
                    "image": img,
                    "imageSmall": img,
                    "imageLarge": img,
                    "tracks": tracks,
                    "playUri": "local:liked",
                }
            return {"error": f"Halaman tidak dikenal: {kind}"}

        self.worker.run(
            fetch,
            lambda data: self.loaded.emit(key, data),
            lambda e: self.loaded.emit(key, {"error": str(e)}),
        )

    # ---- playlists management ---------------------------------------------

    @Slot(str)
    def createPlaylist(self, name: str):
        name = name.strip()
        if not name:
            return
        self.db.create_playlist(name)
        self.reloadMetadataOnly()
        self.toast.emit(f"Playlist '{name}' dibuat")

    @Slot(str)
    def deletePlaylist(self, pid: str):
        if not pid or pid == "all":
            return
        self.db.delete_playlist(pid)
        self.reloadMetadataOnly()
        self.toast.emit("Playlist dihapus")

    @Slot(str, str)
    def addToPlaylist(self, pid: str, uri: str):
        self.db.add_to_playlist(pid, uri)
        self.reloadMetadataOnly()
        self.toast.emit("Ditambahkan ke playlist")

    # ---- search -----------------------------------------------------------

    @Slot(str)
    def search(self, query: str):
        query = query.strip()
        if not query:
            return
        self.worker.run(
            lambda: self.db.search(query),
            lambda r: self.searchFinished.emit(query, r),
            lambda e: self.searchFinished.emit(query, {"error": str(e)}),
        )
