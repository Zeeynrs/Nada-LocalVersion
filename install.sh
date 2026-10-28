#!/usr/bin/env bash
# Installer multi-distro untuk Nada Local
set -euo pipefail

DEST="${HOME}/.local/share/nada-local"
BIN="${HOME}/.local/bin/nada-local"
DESKTOP="${HOME}/.local/share/applications/nada-local.desktop"
ICON="${HOME}/.local/share/icons/hicolor/scalable/apps/nada-local.svg"

if [[ "${1:-}" == "--uninstall" ]]; then
    echo ":: Menghapus instalasi Nada Local..."
    rm -rf "${DEST}" "${BIN}" "${DESKTOP}" "${ICON}"
    echo "✓ Nada Local berhasil dihapus."
    exit 0
fi

install_deps() {
    if command -v pacman >/dev/null 2>&1; then
        echo ":: Distro berbasis Arch Linux terdeteksi..."
        sudo pacman -S --needed --noconfirm python pyside6 mpv ffmpeg python-dbus cava python-mutagen || true
    elif command -v apt-get >/dev/null 2>&1; then
        echo ":: Distro berbasis Debian/Ubuntu terdeteksi..."
        sudo apt-get update
        sudo apt-get install -y python3 python3-venv python3-dbus libmpv-dev mpv ffmpeg cava python3-mutagen \
            pyside6-essentials qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts qml6-module-qtquick-effects || true
    elif command -v dnf >/dev/null 2>&1; then
        echo ":: Distro berbasis Fedora terdeteksi..."
        sudo dnf install -y python3 python3-pyside6 python3-dbus mpv-libs mpv ffmpeg cava python3-mutagen || true
    fi
}

if [[ "${1:-}" != "--no-deps" ]]; then
    if ! python3 -c "import PySide6" >/dev/null 2>&1 || ! python3 -c "import ctypes.util; assert ctypes.util.find_library('mpv')" >/dev/null 2>&1; then
        install_deps
    fi
fi

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "${DEST}" "$(dirname "${BIN}")" "$(dirname "${DESKTOP}")" "$(dirname "${ICON}")"

if [[ "${SRC_DIR}" != "${DEST}" ]]; then
    rm -rf "${DEST}/nada_local" "${DEST}/qml" "${DEST}/data"
    cp -r "${SRC_DIR}/nada_local" "${SRC_DIR}/qml" "${SRC_DIR}/data" "${SRC_DIR}/run.py" "${DEST}/"
fi
chmod +x "${DEST}/run.py"

cat > "${BIN}" <<EOF
#!/usr/bin/env bash
exec python3 -I "${DEST}/run.py" "\$@"
EOF
chmod +x "${BIN}"

sed "s|@BIN@|${BIN}|g" "${DEST}/data/nada-local.desktop" > "${DESKTOP}"
cp "${DEST}/data/nada-local.svg" "${ICON}"

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$(dirname "${DESKTOP}")" 2>/dev/null || true

echo "✓ Nada Local terpasang di ${BIN}"
echo "  Jalankan dengan perintah: nada-local"
