import os
import signal
import sys
from pathlib import Path

from PySide6.QtCore import QTimer
from PySide6.QtGui import QFont, QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle

from .config import Settings
from .library import Library
from .lyrics import Lyrics
from .player import Player
from .scanner import LibraryDB
from .session import Session
from .visualizer import Visualizer
from .worker import Async

ROOT = Path(__file__).resolve().parent.parent


def main():
    os.environ.setdefault("QT_QPA_PLATFORM", "wayland;xcb")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Nada Local")
    app.setOrganizationName("nada-local")
    app.setDesktopFileName("nada-local")
    app.setWindowIcon(QIcon(str(ROOT / "data" / "nada-local.svg")))
    app.setFont(QFont(["Google Sans Flex", "Google Sans", "Noto Sans", "sans-serif"], 10))
    QQuickStyle.setStyle("Basic")

    signal.signal(signal.SIGINT, lambda *_: app.quit())
    keepalive = QTimer()
    keepalive.timeout.connect(lambda: None)
    keepalive.start(500)

    settings = Settings()
    worker = Async()
    db = LibraryDB()
    player = Player(db, worker, settings)
    library = Library(db, settings, worker)
    lyrics = Lyrics(player, settings, worker)
    visualizer = Visualizer()
    session = Session(settings, player, library, worker)

    engine = QQmlApplicationEngine()
    engine.warnings.connect(lambda ws: [print("QML:", w.toString(), file=sys.stderr) for w in ws])
    ctx = engine.rootContext()
    for name, obj in (
        ("session", session),
        ("player", player),
        ("library", library),
        ("lyrics", lyrics),
        ("visualizer", visualizer),
    ):
        ctx.setContextProperty(name, obj)

    engine.load(str(ROOT / "qml" / "Main.qml"))
    if not engine.rootObjects():
        sys.exit("Nada Local: gagal memuat antarmuka (lihat pesan QML di atas)")

    window = engine.rootObjects()[0]
    try:
        from .mpris import Mpris
        mpris = Mpris(player, lambda: (window.show(), window.raise_(), window.requestActivate()), app.quit)
    except Exception as e:
        print(f"MPRIS tidak aktif: {e}", file=sys.stderr)
        mpris = None

    player.start()
    library.refreshAll()

    # Support opening audio files passed via CLI / file manager
    cli_files = [a for a in sys.argv[1:] if not a.startswith("-")]
    if cli_files:
        QTimer.singleShot(250, lambda: player.playFiles(cli_files))

    def shutdown():
        player.stop()
        visualizer.stop()
        worker.shutdown()

    app.aboutToQuit.connect(shutdown)
    code = app.exec()
    del window, engine
    sys.exit(code)


if __name__ == "__main__":
    main()
