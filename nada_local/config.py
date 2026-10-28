"""Paths and persisted settings for Nada Local."""

import json
import os
from pathlib import Path

APP_ID = "nada-local"
CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / APP_ID
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / APP_ID
COVERS_DIR = CACHE_DIR / "covers"
LYRICS_CACHE_DIR = CACHE_DIR / "lyrics"
DB_FILE = CACHE_DIR / "library.db"
SETTINGS_FILE = CONFIG_DIR / "settings.json"

DEFAULT_MUSIC_DIR = str(Path.home() / "Music")

DEFAULTS = {
    "music_dirs": [DEFAULT_MUSIC_DIR],
    "audio_device": "auto",
    "gapless": "weak",           # "no" | "weak" | "yes"
    "replaygain": "no",          # "no" | "track" | "album"
    "visualizer": True,
    "visualizer_style": "bars",  # "bars" | "wave"
    "online_lyrics": True,       # fallback ke LRCLIB bila .lrc lokal tidak ada
    "eq_enabled": False,
    "eq_preset": "Flat",
    "eq_bands": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    "tempo": 1.0,
    "keep_pitch": True,
    "volume": 85,
    "shuffle": False,
    "repeat": "off",
}


def write_private(path: Path, data: dict) -> None:
    """Write JSON atomically, readable by the current user."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    os.replace(tmp, path)


def read_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


class Settings:
    def __init__(self):
        self._data = {**DEFAULTS, **read_json(SETTINGS_FILE)}
        if not isinstance(self._data.get("music_dirs"), list) or not self._data["music_dirs"]:
            self._data["music_dirs"] = [DEFAULT_MUSIC_DIR]

    def get(self, key, default=None):
        return self._data.get(key, default)

    def __getitem__(self, key):
        return self._data[key]

    def __setitem__(self, key, value):
        if self._data.get(key) != value:
            self._data[key] = value
            write_private(SETTINGS_FILE, self._data)
