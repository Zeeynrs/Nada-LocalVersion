# Maintainer: Zeeynrs
pkgname=nada-local-git
pkgver=0.1.0.r1
pkgrel=1
pkgdesc="Pemutar musik lokal Hi-Fi ringan untuk desktop Linux (Python + Qt Quick + libmpv)"
arch=('any')
url="https://github.com/Zeeynrs/Nada-LocalVersion"
license=('GPL-3.0-or-later')
depends=(
    'python'
    'pyside6'
    'mpv'
    'ffmpeg'
    'python-dbus'
)
optdepends=(
    'cava: spektrum visualizer audio real-time pada tampilan penuh'
    'python-mutagen: ekstraksi tag audio ekstra cepat'
)
makedepends=('git')
provides=('nada-local')
conflicts=('nada-local')
source=()
sha256sums=()

package() {
    local _src="${startdir}"
    install -d "${pkgdir}/usr/lib/nada-local"
    install -d "${pkgdir}/usr/bin"

    cp -r "${_src}/nada_local" "${pkgdir}/usr/lib/nada-local/"
    cp -r "${_src}/qml" "${pkgdir}/usr/lib/nada-local/"
    cp -r "${_src}/data" "${pkgdir}/usr/lib/nada-local/"
    install -Dm755 "${_src}/run.py" "${pkgdir}/usr/lib/nada-local/run.py"

    cat > "${pkgdir}/usr/bin/nada-local" << 'EOF'
#!/usr/bin/env bash
exec python3 -I /usr/lib/nada-local/run.py "$@"
EOF
    chmod 755 "${pkgdir}/usr/bin/nada-local"

    sed "s|@BIN@|/usr/bin/nada-local|g" "${_src}/data/nada-local.desktop" \
        > "${srcdir}/nada-local.desktop"
    install -Dm644 "${srcdir}/nada-local.desktop" \
        "${pkgdir}/usr/share/applications/nada-local.desktop"
    install -Dm644 "${_src}/data/nada-local.svg" \
        "${pkgdir}/usr/share/icons/hicolor/scalable/apps/nada-local.svg"
    install -Dm644 "${_src}/LICENSE" \
        "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"
}
