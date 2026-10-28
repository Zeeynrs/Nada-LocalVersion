import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Item {
    id: lv

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: lyrics.lines
        spacing: 22
        currentIndex: lyrics.synced ? lyrics.current : -1
        highlightRangeMode: lyrics.synced ? ListView.ApplyRange : ListView.NoHighlightRange
        preferredHighlightBegin: height * 0.34
        preferredHighlightEnd: height * 0.34 + 84
        highlightMoveDuration: 550
        highlightMoveVelocity: -1
        boundsBehavior: Flickable.StopAtBounds
        header: Item { width: 1; height: list.height * 0.26 }
        footer: Item { width: 1; height: list.height * 0.48 }
        ScrollBar.vertical: NScrollBar {}

        delegate: Item {
            id: row
            readonly property bool isCurrent: lyrics.synced && index === lyrics.current
            readonly property bool past: lyrics.synced && index < lyrics.current
            width: list.width - 20
            height: lineLabel.implicitHeight + 24

            // Scalloped translucent pill highlight behind the active lyric line
            Canvas {
                id: pillBg
                x: -6
                y: 0
                width: Math.min(row.width + 12, Math.max(120, lineLabel.contentWidth + 44))
                height: row.height
                opacity: row.isCurrent ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Connections {
                    target: Theme
                    function onAccentChanged() { pillBg.requestPaint() }
                }

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    const w = width - 8
                    const h = height - 8
                    const ox = 4
                    const oy = 4
                    const r = h / 2
                    if (w <= h) return

                    // Trace capsule perimeter and add subtle scallop ripples along the edge
                    const straight = w - 2 * r
                    const perim = 2 * straight + 2 * Math.PI * r
                    const waves = Math.max(18, Math.round(perim / 16))
                    const steps = waves * 12
                    const amp = 2.0

                    function pointOnCapsule(s) {
                        let d = ((s % perim) + perim) % perim
                        if (d < straight) {
                            // Top edge (left to right)
                            return { x: ox + r + d, y: oy, nx: 0, ny: -1 }
                        }
                        d -= straight
                        if (d < Math.PI * r) {
                            // Right semicircle
                            const a = -Math.PI / 2 + d / r
                            return { x: ox + r + straight + Math.cos(a) * r, y: oy + r + Math.sin(a) * r, nx: Math.cos(a), ny: Math.sin(a) }
                        }
                        d -= Math.PI * r
                        if (d < straight) {
                            // Bottom edge (right to left)
                            return { x: ox + r + straight - d, y: oy + h, nx: 0, ny: 1 }
                        }
                        d -= straight
                        // Left semicircle
                        const a = Math.PI / 2 + d / r
                        return { x: ox + r + Math.cos(a) * r, y: oy + r + Math.sin(a) * r, nx: Math.cos(a), ny: Math.sin(a) }
                    }

                    ctx.beginPath()
                    for (let i = 0; i <= steps; i++) {
                        const s = (i / steps) * perim
                        const p = pointOnCapsule(s)
                        const wave = amp * Math.cos((i / steps) * waves * Math.PI * 2)
                        const px = p.x + p.nx * wave
                        const py = p.y + p.ny * wave
                        if (i === 0) ctx.moveTo(px, py)
                        else ctx.lineTo(px, py)
                    }
                    ctx.closePath()
                    ctx.fillStyle = "rgba(255, 255, 255, 0.14)"
                    ctx.fill()
                    ctx.lineWidth = 1.2
                    ctx.strokeStyle = "rgba(255, 255, 255, 0.16)"
                    ctx.stroke()
                }
            }

            Label {
                id: lineLabel
                x: row.isCurrent ? 14 : 4
                anchors.verticalCenter: parent.verticalCenter
                width: row.width - 28
                text: modelData.text || "♪"
                wrapMode: Text.WordWrap
                font.pixelSize: lyrics.synced ? 26 : 22
                font.weight: Font.Bold
                color: !lyrics.synced ? Theme.alpha(Theme.text, 0.85)
                     : row.isCurrent ? "#ffffff"
                     : row.past ? Qt.rgba(1, 1, 1, 0.42) : Qt.rgba(1, 1, 1, 0.36)
                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 280 } }

                layer.enabled: row.isCurrent
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#ffffff"
                    shadowBlur: 0.75
                    shadowOpacity: 0.75
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }
            }

            HoverHandler { cursorShape: lyrics.synced ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler { onTapped: if (lyrics.synced) player.seek(modelData.t) }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 12
        visible: lyrics.status !== "ready"
        BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: lyrics.status === "loading"; visible: running }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ({ "loading": "Memuat lirik…", "none": "Lirik tidak ditemukan untuk lagu ini",
                     "error": "Gagal memuat lirik", "idle": "Putar lagu untuk melihat lirik" })[lyrics.status] || ""
            color: Theme.dim
            font.pixelSize: 18
        }
    }
}
