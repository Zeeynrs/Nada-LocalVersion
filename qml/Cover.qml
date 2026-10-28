import QtQuick
import QtQuick.Effects
import QtQuick.Window

// Album/artist art with rounded corners (or scalloped badge) and a placeholder while loading.
Item {
    id: root
    property url source
    property real radius: 8
    property bool round: false
    property bool scalloped: false
    property int scallops: 24
    property real scallopDepth: 0.038
    property bool simple: false  // plain square image, cheaper for long lists
    property string fallbackIcon: "note"
    readonly property bool ready: img.status === Image.Ready
    readonly property real cornerRadius: (round || scalloped) ? width / 2 : radius
    readonly property int loadSize: Math.ceil(Math.max(width, height) * Screen.devicePixelRatio)

    Rectangle {
        id: placeholderRect
        anchors.fill: parent
        radius: root.cornerRadius
        color: Theme.surface3
        visible: !root.ready && !root.scalloped
        Icon {
            anchors.centerIn: parent
            glyph: root.fallbackIcon
            size: Math.max(14, Math.min(root.width * 0.38, 64))
            color: Theme.faint
        }
    }

    Canvas {
        anchors.fill: parent
        visible: !root.ready && root.scalloped
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const cx = width / 2
            const cy = height / 2
            const rBase = Math.min(cx, cy) * (1 - root.scallopDepth)
            const amp = Math.min(cx, cy) * root.scallopDepth
            const N = root.scallops
            ctx.fillStyle = Theme.surface3
            ctx.beginPath()
            const steps = 360
            for (let i = 0; i <= steps; i++) {
                const a = (i / steps) * Math.PI * 2
                const r = rBase + amp * Math.cos(N * a)
                const x = cx + Math.cos(a) * r
                const y = cy + Math.sin(a) * r
                if (i === 0) ctx.moveTo(x, y)
                else ctx.lineTo(x, y)
            }
            ctx.closePath()
            ctx.fill()
        }
        Icon {
            anchors.centerIn: parent
            glyph: root.fallbackIcon
            size: Math.max(14, Math.min(root.width * 0.38, 64))
            color: Theme.faint
        }
    }

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: root.loadSize
        sourceSize.height: root.loadSize
        visible: root.simple && root.ready
        smooth: true
    }

    Loader {
        anchors.fill: parent
        active: !root.simple && root.ready
        sourceComponent: MultiEffect {
            source: img
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
            NumberAnimation on opacity { from: 0; to: 1; duration: 220 }
        }
    }

    Item {
        id: mask
        width: root.width
        height: root.height
        layer.enabled: true
        layer.smooth: true
        // Keep visible: true when scalloped so Canvas always paints its FBO, but hide via opacity: 0
        visible: root.scalloped
        opacity: 0
        Rectangle {
            anchors.fill: parent
            radius: root.cornerRadius
            visible: !root.scalloped
        }
        Canvas {
            id: scallopCanvas
            anchors.fill: parent
            visible: root.scalloped
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const cx = width / 2
                const cy = height / 2
                const rBase = Math.min(cx, cy) * (1 - root.scallopDepth)
                const amp = Math.min(cx, cy) * root.scallopDepth
                const N = root.scallops
                ctx.fillStyle = "#ffffff"
                ctx.beginPath()
                const steps = 360
                for (let i = 0; i <= steps; i++) {
                    const a = (i / steps) * Math.PI * 2
                    const r = rBase + amp * Math.cos(N * a)
                    const x = cx + Math.cos(a) * r
                    const y = cy + Math.sin(a) * r
                    if (i === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.closePath()
                ctx.fill()
            }
        }
    }
}
