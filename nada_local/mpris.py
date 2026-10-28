"""MPRIS2 so playerctl, media keys, hyprlock, and bar widgets can control Nada Local."""

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop

ROOT_IFACE = "org.mpris.MediaPlayer2"
PLAYER_IFACE = "org.mpris.MediaPlayer2.Player"
PROPS_IFACE = "org.freedesktop.DBus.Properties"
PATH = "/org/mpris/MediaPlayer2"
NO_TRACK = dbus.ObjectPath("/org/mpris/MediaPlayer2/TrackList/NoTrack")

LOOP_TO_MPRIS = {"off": "None", "context": "Playlist", "track": "Track"}
LOOP_FROM_MPRIS = {v: k for k, v in LOOP_TO_MPRIS.items()}


class Mpris(dbus.service.Object):
    def __init__(self, player, raise_window, quit_app):
        DBusGMainLoop(set_as_default=True)
        self.player = player
        self.raise_window = raise_window
        self.quit_app = quit_app
        bus = dbus.SessionBus()
        self._bus_name = dbus.service.BusName("org.mpris.MediaPlayer2.nada_local", bus)
        super().__init__(bus, PATH, self._bus_name)
        self._last = {}
        player.stateChanged.connect(self._on_state)

    def _metadata(self):
        s = self.player.state
        if not s.get("hasTrack"):
            return dbus.Dictionary({"mpris:trackid": NO_TRACK}, signature="sv")
        raw_id = (s.get("id") or "unknown").replace("-", "_")
        track_id = "/org/nada_local/track/" + raw_id
        md = {
            "mpris:trackid": dbus.ObjectPath(track_id),
            "mpris:length": dbus.Int64(s.get("durationMs", 0) * 1000),
            "xesam:title": s.get("name", ""),
            "xesam:artist": dbus.Array(
                [a.strip() for a in s.get("artists", "").split(",") if a.strip()], signature="s"
            ),
            "xesam:album": s.get("album", ""),
            "xesam:url": s.get("uri", ""),
        }
        if s.get("imageLarge"):
            md["mpris:artUrl"] = s["imageLarge"]
        return dbus.Dictionary(md, signature="sv")

    def _player_props(self):
        s = self.player.state
        has = bool(s.get("hasTrack"))
        vol = s.get("volume", -1)
        return {
            "PlaybackStatus": ("Playing" if s.get("isPlaying") else "Paused") if has else "Stopped",
            "LoopStatus": LOOP_TO_MPRIS.get(s.get("repeat", "off"), "None"),
            "Shuffle": dbus.Boolean(s.get("shuffle", False)),
            "Metadata": self._metadata(),
            "Volume": dbus.Double(vol / 100 if vol is not None and vol >= 0 else 1.0),
            "Position": dbus.Int64(self.player.position * 1000),
            "Rate": dbus.Double(float(self.player.tempo)),
            "MinimumRate": dbus.Double(0.5),
            "MaximumRate": dbus.Double(2.0),
            "CanGoNext": dbus.Boolean(has),
            "CanGoPrevious": dbus.Boolean(has),
            "CanPlay": dbus.Boolean(True),
            "CanPause": dbus.Boolean(has),
            "CanSeek": dbus.Boolean(has),
            "CanControl": dbus.Boolean(True),
        }

    def _root_props(self):
        return {
            "CanQuit": dbus.Boolean(True),
            "CanRaise": dbus.Boolean(True),
            "HasTrackList": dbus.Boolean(False),
            "Identity": "Nada Local",
            "DesktopEntry": "nada-local",
            "SupportedUriSchemes": dbus.Array(["file"], signature="s"),
            "SupportedMimeTypes": dbus.Array(
                ["audio/flac", "audio/mpeg", "audio/ogg", "audio/opus", "audio/x-wav", "audio/mp4"],
                signature="s",
            ),
        }

    def _on_state(self):
        props = self._player_props()
        props.pop("Position")
        changed = {k: v for k, v in props.items() if self._last.get(k) != v}
        self._last = props
        if changed:
            self.PropertiesChanged(PLAYER_IFACE, changed, [])

    def seeked(self):
        self.Seeked(dbus.Int64(self.player.position * 1000))

    @dbus.service.method(PROPS_IFACE, in_signature="ss", out_signature="v")
    def Get(self, iface, prop):
        return self.GetAll(iface)[prop]

    @dbus.service.method(PROPS_IFACE, in_signature="s", out_signature="a{sv}")
    def GetAll(self, iface):
        if iface == PLAYER_IFACE:
            return self._player_props()
        if iface == ROOT_IFACE:
            return self._root_props()
        raise dbus.exceptions.DBusException(
            f"No interface {iface}", name="org.freedesktop.DBus.Error.UnknownInterface"
        )

    @dbus.service.method(PROPS_IFACE, in_signature="ssv")
    def Set(self, iface, prop, value):
        if iface != PLAYER_IFACE:
            return
        if prop == "Volume":
            self.player.setVolume(int(max(0.0, min(1.0, float(value))) * 100))
        elif prop == "Shuffle":
            if bool(value) != bool(self.player.state.get("shuffle")):
                self.player.toggleShuffle()
        elif prop == "LoopStatus":
            target = LOOP_FROM_MPRIS.get(str(value), "off")
            for _ in range(3):
                if self.player.state.get("repeat", "off") == target:
                    break
                self.player.cycleRepeat()
        elif prop == "Rate":
            self.player.setTempo(float(value))

    @dbus.service.signal(PROPS_IFACE, signature="sa{sv}as")
    def PropertiesChanged(self, iface, changed, invalidated):
        pass

    @dbus.service.method(ROOT_IFACE)
    def Raise(self):
        self.raise_window()

    @dbus.service.method(ROOT_IFACE)
    def Quit(self):
        self.quit_app()

    @dbus.service.method(PLAYER_IFACE)
    def PlayPause(self):
        self.player.togglePlay()

    @dbus.service.method(PLAYER_IFACE)
    def Play(self):
        if not self.player.state.get("isPlaying"):
            self.player.togglePlay()

    @dbus.service.method(PLAYER_IFACE)
    def Pause(self):
        if self.player.state.get("isPlaying"):
            self.player.togglePlay()

    @dbus.service.method(PLAYER_IFACE)
    def Stop(self):
        self.Pause()

    @dbus.service.method(PLAYER_IFACE)
    def Next(self):
        self.player.next()

    @dbus.service.method(PLAYER_IFACE)
    def Previous(self):
        self.player.previous()

    @dbus.service.method(PLAYER_IFACE, in_signature="x")
    def Seek(self, offset_us):
        self.player.seek(max(0, self.player.position + int(offset_us) // 1000))
        self.seeked()

    @dbus.service.method(PLAYER_IFACE, in_signature="ox")
    def SetPosition(self, track_id, position_us):
        self.player.seek(int(position_us) // 1000)
        self.seeked()

    @dbus.service.method(PLAYER_IFACE, in_signature="s")
    def OpenUri(self, uri):
        if uri.startswith("file://") or uri.startswith("/"):
            self.player.playFiles([uri])

    @dbus.service.signal(PLAYER_IFACE, signature="x")
    def Seeked(self, position):
        pass
