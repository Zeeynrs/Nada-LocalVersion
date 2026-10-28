import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Live 6-band Equalizer & Tempo/Pitch DSP panel wired to libmpv.
Item {
    id: eqRoot
    readonly property bool eqEnabled: player ? player.eqEnabled : false
    readonly property string presetName: player ? player.eqPreset : "Flat"
    readonly property var bands: player ? player.eqBands : [0, 0, 0, 0, 0, 0]
    readonly property real tempo: player ? player.tempo : 1.0
    readonly property bool keepPitch: player ? player.keepPitch : true

    readonly property var bandLabels: ["60", "150", "400", "1k", "2k", "15k"]
    readonly property var presets: ({
        "Flat":       [0.0,   0.0,   0.0,   0.0,   0.0,   0.0],
        "Bass Boost": [0.65,  0.45,  0.10, -0.05,  0.00,  0.05],
        "Rock":       [0.45,  0.22, -0.15,  0.12,  0.32,  0.42],
        "Vocal":      [-0.15, 0.05,  0.38,  0.48,  0.25, -0.05],
        "Warm Hi-Fi": [0.36,  0.14, -0.02, -0.10, -0.08, -0.08]
    })
    readonly property var presetNames: ["Flat", "Bass Boost", "Rock", "Vocal", "Warm Hi-Fi"]

    property var _specSmooth: []
    property real _time: 0

    function setBand(index, val) {
        if (!player) return
        if (!player.eqEnabled) player.setEqEnabled(true)
        player.setEqBand(index, val)
        eqGraph.requestPaint()
    }

    function nextPreset() {
        if (!player) return
        const curIdx = presetNames.indexOf(presetName)
        const idx = (curIdx + 1) % presetNames.length
        const name = presetNames[idx]
        if (!player.eqEnabled && name !== "Flat") player.setEqEnabled(true)
        player.setEqPreset(name, presets[name])
        eqGraph.requestPaint()
    }

    Connections {
        target: player
        function onDspChanged() { eqGraph.requestPaint() }
    }

    FrameAnimation {
        running: eqRoot.visible
        onTriggered: {
            const dt = Math.min(0.05, frameTime)
            eqRoot._time += dt
            const N = 32
            if (eqRoot._specSmooth.length !== N) {
                const init = new Array(N)
                for (let i = 0; i < N; i++) init[i] = 0
                eqRoot._specSmooth = init
            }

            const raw = visualizer ? (visualizer.bars || []) : []
            let maxSig = 0
            for (let i = 0; i < raw.length; i++) {
                if ((raw[i] || 0) > maxSig) maxSig = raw[i]
            }
            const hasCava = visualizer && visualizer.active && maxSig > 0.008
            const playing = player && player.state ? !!player.state.isPlaying : false
            const t = eqRoot._time
            const cur = eqRoot._specSmooth

            for (let i = 0; i < N; i++) {
                const xNorm = i / (N - 1)
                const bell = Math.exp(-Math.pow((xNorm - 0.50) / 0.24, 2.0))
                const subPeak = Math.exp(-Math.pow((xNorm - 0.23) / 0.06, 2.0)) * 0.75
                let v = 0
                if (hasCava) {
                    const binIdx = Math.min(raw.length - 1, Math.floor(xNorm * (raw.length - 1)))
                    v = (raw[binIdx] || 0) * (0.35 + 0.85 * bell + subPeak)
                } else if (playing) {
                    const wave = 0.45 + 0.55 * Math.sin(i * 1.4 - t * 6.5) * Math.cos(i * 0.7 + t * 4.2)
                    const beat = 0.65 + 0.35 * Math.sin(t * 5.6)
                    v = (bell * (0.45 + 0.55 * wave) + subPeak * beat * 0.6) * 0.85
                }
                v = Math.max(0, Math.min(1, v * (eqRoot.eqEnabled ? 1.0 : 0.45)))
                cur[i] += (v - cur[i]) * Math.min(1.0, dt * 16.0)
            }
            eqGraph.requestPaint()
        }
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16

        // CARD 1: 6-BAND EQUALIZER (libmpv lavfi)
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 370
            radius: 22
            color: Qt.rgba(1, 1, 1, 0.09)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.11)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Label {
                        text: "Equalizer (libmpv DSP)"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: "#ffffff"
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        implicitWidth: presetRow.implicitWidth + 22
                        implicitHeight: 28
                        radius: 14
                        color: presetMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.12)
                        Row {
                            id: presetRow
                            anchors.centerIn: parent
                            spacing: 6
                            Label {
                                text: eqRoot.presetName
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: "#ffffff"
                            }
                            Label {
                                text: "↕"
                                font.pixelSize: 11
                                color: Qt.rgba(1, 1, 1, 0.75)
                            }
                        }
                        MouseArea {
                            id: presetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: eqRoot.nextPreset()
                        }
                    }

                    Rectangle {
                        width: 50
                        height: 28
                        radius: 14
                        color: eqRoot.eqEnabled ? "#c9cdd4" : Qt.rgba(1, 1, 1, 0.16)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.22)
                        Behavior on color { ColorAnimation { duration: 160 } }

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            y: 3
                            x: eqRoot.eqEnabled ? parent.width - width - 3 : 3
                            color: "#22252b"
                            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (player) player.setEqEnabled(!eqRoot.eqEnabled)
                        }
                    }
                }

                Canvas {
                    id: eqGraph
                    Layout.fillWidth: true
                    Layout.preferredHeight: 112
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        const w = width
                        const h = height
                        if (w <= 0 || h <= 0) return

                        const padX = (w / 12)
                        const spanW = w - padX * 2
                        const curveMidY = h * 0.34
                        const curveAmp = h * 0.24
                        const specBaseY = h - 10
                        const specMaxH = h * 0.62

                        const N = 32
                        const spec = eqRoot._specSmooth
                        ctx.save()
                        ctx.lineCap = "round"
                        for (let i = 0; i < N; i++) {
                            const sx = 6 + (i / (N - 1)) * (w - 12)
                            const v = spec.length === N ? spec[i] : 0
                            const barH = Math.max(0.5, v * specMaxH)

                            if (v > 0.04) {
                                ctx.strokeStyle = "rgba(236, 32, 108, " + Math.min(0.32, v * 0.38) + ")"
                                ctx.lineWidth = 11
                                ctx.beginPath()
                                ctx.moveTo(sx, specBaseY)
                                ctx.lineTo(sx, specBaseY - barH)
                                ctx.stroke()
                            }

                            ctx.strokeStyle = "#dd246e"
                            ctx.lineWidth = 5.2
                            ctx.beginPath()
                            ctx.moveTo(sx, specBaseY)
                            ctx.lineTo(sx, specBaseY - barH)
                            ctx.stroke()
                        }
                        ctx.restore()

                        ctx.save()
                        ctx.strokeStyle = "rgba(255, 255, 255, 0.20)"
                        ctx.lineWidth = 1.2
                        ctx.setLineDash([3, 4])
                        ctx.beginPath()
                        ctx.moveTo(4, curveMidY)
                        ctx.lineTo(w - 4, curveMidY)
                        ctx.stroke()
                        ctx.restore()

                        const pts = []
                        for (let b = 0; b < 6; b++) {
                            const bx = padX + (b / 5) * spanW
                            const by = curveMidY - (eqRoot.bands[b] || 0) * curveAmp
                            pts.push({ x: bx, y: by })
                        }

                        ctx.save()
                        ctx.strokeStyle = "rgba(255, 255, 255, 0.22)"
                        ctx.lineWidth = 6.0
                        ctx.lineCap = "round"
                        ctx.beginPath()
                        ctx.moveTo(4, pts[0].y)
                        ctx.lineTo(pts[0].x, pts[0].y)
                        for (let i = 0; i < pts.length - 1; i++) {
                            const xc = (pts[i].x + pts[i + 1].x) / 2
                            const yc = (pts[i].y + pts[i + 1].y) / 2
                            ctx.quadraticCurveTo(pts[i].x, pts[i].y, xc, yc)
                        }
                        ctx.lineTo(pts[5].x, pts[5].y)
                        ctx.lineTo(w - 4, pts[5].y)
                        ctx.stroke()

                        ctx.strokeStyle = "rgba(235, 238, 245, 0.78)"
                        ctx.lineWidth = 2.6
                        ctx.stroke()

                        ctx.fillStyle = "rgba(245, 247, 252, 0.85)"
                        for (let i = 0; i < pts.length; i++) {
                            ctx.beginPath()
                            ctx.arc(pts[i].x, pts[i].y, 3.2, 0, Math.PI * 2)
                            ctx.fill()
                        }
                        ctx.restore()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Repeater {
                        model: 6
                        Item {
                            id: bandCol
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            readonly property real gain: eqRoot.bands[index] || 0

                            Rectangle {
                                id: vTrack
                                anchors.top: parent.top
                                anchors.bottom: freqLabel.top
                                anchors.bottomMargin: 12
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 4
                                radius: 2
                                color: Qt.rgba(1, 1, 1, 0.16)

                                Rectangle {
                                    id: thumb
                                    width: 28
                                    height: 14
                                    radius: 7
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: (1 - (bandCol.gain + 1) / 2) * (vTrack.height - height)
                                    color: "#f4f6fa"

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 10
                                        height: 1.6
                                        radius: 0.8
                                        color: "#9aa0ac"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.leftMargin: -18
                                    anchors.rightMargin: -18
                                    cursorShape: Qt.PointingHandCursor
                                    function updateFromY(my) {
                                        const norm = 1.0 - Math.max(0, Math.min(1, (my - thumb.height / 2) / Math.max(1, vTrack.height - thumb.height)))
                                        eqRoot.setBand(index, norm * 2 - 1)
                                    }
                                    onPressed: (mouse) => updateFromY(mouse.y)
                                    onPositionChanged: (mouse) => { if (pressed) updateFromY(mouse.y) }
                                    onDoubleClicked: eqRoot.setBand(index, 0)
                                }
                            }

                            Label {
                                id: freqLabel
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: eqRoot.bandLabels[index]
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Qt.rgba(1, 1, 1, 0.65)
                            }
                        }
                    }
                }
            }
        }

        // CARD 2: TEMPO & PITCH
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 168
            radius: 22
            color: Qt.rgba(1, 1, 1, 0.09)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.11)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 12

                Label {
                    text: "Tempo & Pitch"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: "#ffffff"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Rectangle {
                        width: 26
                        height: 26
                        radius: 13
                        color: speedResetMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                        Canvas {
                            anchors.fill: parent
                            anchors.margins: 4
                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                ctx.strokeStyle = "rgba(255, 255, 255, 0.72)"
                                ctx.lineWidth = 1.6
                                ctx.lineCap = "round"
                                ctx.beginPath()
                                ctx.arc(width / 2, height / 2 + 1, width / 2 - 1.5, Math.PI * 0.8, Math.PI * 2.2)
                                ctx.stroke()
                                ctx.beginPath()
                                ctx.moveTo(width / 2, height / 2 + 1)
                                ctx.lineTo(width * 0.72, height * 0.28)
                                ctx.stroke()
                            }
                        }
                        MouseArea {
                            id: speedResetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (player) player.setTempo(1.0)
                        }
                    }

                    Item {
                        id: tempoSlider
                        Layout.fillWidth: true
                        height: 24
                        readonly property real norm: (eqRoot.tempo - 0.5) / 1.5

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 8
                            radius: 4
                            color: Qt.rgba(0.18, 0.20, 0.24, 0.85)

                            Rectangle {
                                width: Math.max(8, tempoSlider.norm * parent.width)
                                height: parent.height
                                radius: 4
                                color: "#c9cdd4"
                            }

                            Rectangle {
                                width: 3; height: 3; radius: 1.5
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                color: Qt.rgba(1, 1, 1, 0.5)
                            }
                        }

                        Rectangle {
                            width: 4
                            height: 22
                            radius: 2
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width, tempoSlider.norm * parent.width - width / 2))
                            color: "#d8dce3"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            function setFromX(mx) {
                                const n = Math.max(0, Math.min(1, mx / Math.max(1, width)))
                                const rawT = 0.5 + n * 1.5
                                if (player) player.setTempo(Math.round(rawT * 20) / 20)
                            }
                            onPressed: (mouse) => setFromX(mouse.x)
                            onPositionChanged: (mouse) => { if (pressed) setFromX(mouse.x) }
                            onDoubleClicked: if (player) player.setTempo(1.0)
                        }
                    }

                    Rectangle {
                        implicitWidth: 44
                        implicitHeight: 26
                        radius: 13
                        color: Qt.rgba(1, 1, 1, 0.12)
                        Label {
                            anchors.centerIn: parent
                            text: Number(eqRoot.tempo.toFixed(2)) + "×"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: "#ffffff"
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "Pertahankan Nada Asli (Keep Original Pitch)"
                        font.pixelSize: 15
                        font.weight: Font.Medium
                        color: Qt.rgba(1, 1, 1, 0.90)
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        width: 48
                        height: 26
                        radius: 13
                        color: eqRoot.keepPitch ? "#c9cdd4" : Qt.rgba(0.18, 0.20, 0.24, 0.85)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.22)
                        Behavior on color { ColorAnimation { duration: 160 } }

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            y: 3
                            x: eqRoot.keepPitch ? parent.width - width - 3 : 3
                            color: eqRoot.keepPitch ? "#22252b" : "#9aa0ac"
                            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (player) player.setKeepPitch(!eqRoot.keepPitch)
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: eqRoot.keepPitch
                          ? "Kecepatan berubah tanpa mengubah tinggi nada vokal/instrumen"
                          : "Kecepatan juga mengubah nada (gaya nightcore / slowed vinyl)"
                    font.pixelSize: 12
                    color: Qt.rgba(1, 1, 1, 0.48)
                    elide: Text.ElideRight
                }
            }
        }
    }
}
