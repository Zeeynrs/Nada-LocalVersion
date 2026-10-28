pragma Singleton
import QtQuick

QtObject {
    readonly property color bg: "#0d0e12"
    readonly property color surface: "#15171c"
    readonly property color surface2: "#1d2026"
    readonly property color surface3: "#272b33"
    readonly property color text: "#eef0f5"
    readonly property color dim: "#a3a9b6"
    readonly property color faint: "#646a78"
    readonly property color accentText: "#0b0d12"
    readonly property color danger: "#ff8a80"
    property color accent: "#9ecaff"

    readonly property string font: "Google Sans Flex"
    readonly property string mono: "JetBrainsMono Nerd Font"

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    function fmt(ms) {
        const total = Math.max(0, Math.floor((ms || 0) / 1000))
        const s = total % 60
        return Math.floor(total / 60) + ":" + (s < 10 ? "0" : "") + s
    }

    function librespotStatus(st) {
        return {
            "off": "mati", "starting": "memulai…", "authenticating": "menunggu login di browser…",
            "ready": "siap", "crashed": "berhenti, mencoba lagi…", "error": "login gagal",
            "missing": "librespot belum terpasang"
        }[st] || st
    }

    function greeting() {
        const h = new Date().getHours()
        if (h < 11) return "Selamat pagi"
        if (h < 15) return "Selamat siang"
        if (h < 19) return "Selamat sore"
        return "Selamat malam"
    }
}
