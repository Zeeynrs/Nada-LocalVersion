import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

// Full-window "now playing": scalloped cover, dual-mode visualizer (bars & wave),
// wavy seekbar, scalloped play button, glowing synced lyrics, queue, and equalizer.
Item {
    id: im
    objectName: "immersive"
    property bool open: false
    property string panel: "lyrics"  // "lyrics" | "queue" | "equalizer"
    readonly property var s: player ? player.state : ({})
    readonly property bool wide: width > 900
    property bool panelOpen: true
    readonly property bool showPanel: panelOpen
    readonly property bool shown: y < height
    signal close()

    function selectPanel(name) {
        if (panelOpen && panel === name) {
            panelOpen = false
        } else {
            panel = name
            panelOpen = true
        }
    }

    function toggleVisualizerStyle() {
        if (!session) return
        session.visualizerStyle = (session.visualizerStyle === "wave") ? "bars" : "wave"
    }

    y: open ? 0 : height
    visible: shown
    Behavior on y { NumberAnimation { duration: 460; easing.type: Easing.OutQuint } }

    // swallow input so nothing underneath reacts
    MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.AllButtons; onWheel: (w) => w.accepted = true }

    Rectangle { anchors.fill: parent; color: "#14161b" }

    Image {
        id: bgArt
        anchors.fill: parent
        source: im.s.image || ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(256, 256)
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: bgArt
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        saturation: 0.45
        brightness: -0.22
        opacity: bgArt.status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 600 } }
        SequentialAnimation on scale {
            running: im.shown
            loops: Animation.Infinite
            NumberAnimation { from: 1.15; to: 1.32; duration: 24000; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.32; to: 1.15; duration: 24000; easing.type: Easing.InOutSine }
        }
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.06, 0.07, 0.09, 0.28) }
            GradientStop { position: 0.6; color: Qt.rgba(0.06, 0.07, 0.09, 0.42) }
            GradientStop { position: 1.0; color: Qt.rgba(0.06, 0.07, 0.09, 0.68) }
        }
    }

    // Subtle decorative flower & scallop silhouettes in the background corners
    Canvas {
        id: decorCanvas
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = "rgba(255, 255, 255, 0.042)"

            function drawFlower(cx, cy, baseR, ampR, petals, rot) {
                ctx.beginPath()
                const steps = 240
                for (let i = 0; i <= steps; i++) {
                    const a = (i / steps) * Math.PI * 2
                    const r = baseR + ampR * Math.cos(petals * (a - rot))
                    const x = cx + Math.cos(a) * r
                    const y = cy + Math.sin(a) * r
                    if (i === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.closePath()
                ctx.fill()
            }

            // 1. Top-left 7-petal flower silhouette
            drawFlower(width * 0.04, height * 0.19, 130, 48, 7, 0.4)
            // 2. Top-center soft circle silhouette
            drawFlower(width * 0.51, height * 0.02, 82, 0, 1, 0)
            // 3. Top-right 10-lobe scalloped silhouette
            drawFlower(width * 0.90, height * 0.12, 92, 16, 10, 0.2)
            // 4. Bottom-left 9-lobe cloud flower silhouette
            drawFlower(width * 0.08, height * 0.90, 118, 22, 9, 0.1)
            // 5. Bottom-right 18-petal daisy starburst silhouette
            ctx.fillStyle = "rgba(255, 255, 255, 0.048)"
            drawFlower(width * 0.85, height * 0.82, 125, 46, 18, 0.15)
        }
    }

    // ========================================================================
    // TOP BAR: Round Close Button (Left) & Segmented Pill Toolbar (Right)
    // ========================================================================
    Item {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 68

        // Top-left circular close button ("×")
        Rectangle {
            x: 24
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: 18
            color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.12)
            Behavior on color { ColorAnimation { duration: 140 } }

            Icon {
                anchors.centerIn: parent
                glyph: "close"
                size: 15
                color: "#ffffff"
            }
            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: im.close()
            }
        }

        // Top-right translucent pill toolbar
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            height: 40
            width: pillRow.implicitWidth + 12
            radius: 20
            color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.14)

            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: 4

                // 1. Cover-only view toggle
                Rectangle {
                    width: 38; height: 30; radius: 15
                    readonly property bool active: !im.showPanel
                    color: active ? "#ffffff" : (covMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                    Canvas {
                        anchors.centerIn: parent
                        width: 16; height: 16
                        property color pen: parent.active ? "#181a20" : "#ffffff"
                        onPenChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = pen
                            ctx.lineWidth = 1.6
                            ctx.lineJoin = "round"
                            ctx.strokeRect(2, 2, 12, 12)
                            ctx.beginPath()
                            ctx.moveTo(2.5, 11.5)
                            ctx.lineTo(6.5, 7.5)
                            ctx.lineTo(9.5, 10.5)
                            ctx.lineTo(11.5, 8.5)
                            ctx.lineTo(13.5, 11.5)
                            ctx.stroke()
                        }
                    }
                    MouseArea {
                        id: covMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: im.panelOpen = !im.panelOpen
                    }
                }

                // 2. Lyrics tab
                Rectangle {
                    width: 38; height: 30; radius: 15
                    readonly property bool active: im.showPanel && im.panel === "lyrics"
                    color: active ? "#ffffff" : (lyrMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                    Icon {
                        anchors.centerIn: parent
                        glyph: "lyrics"
                        size: 16
                        color: parent.active ? "#181a20" : "#ffffff"
                    }
                    MouseArea {
                        id: lyrMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: im.selectPanel("lyrics")
                    }
                }

                // 3. Queue tab
                Rectangle {
                    width: 38; height: 30; radius: 15
                    readonly property bool active: im.showPanel && im.panel === "queue"
                    color: active ? "#ffffff" : (qMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                    Icon {
                        anchors.centerIn: parent
                        glyph: "queue"
                        size: 16
                        color: parent.active ? "#181a20" : "#ffffff"
                    }
                    MouseArea {
                        id: qMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: im.selectPanel("queue")
                    }
                }

                // 4. Visualizer Style Toggle (Moon icon: switches "bars" <-> "wave")
                Rectangle {
                    width: 38; height: 30; radius: 15
                    readonly property bool isWave: session && session.visualizerStyle === "wave"
                    color: styleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    Canvas {
                        anchors.centerIn: parent
                        width: 16; height: 16
                        property bool waveMode: parent.isWave
                        onWaveModeChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = "#ffffff"
                            ctx.lineWidth = 1.6
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            // Crescent moon icon matching the screenshots
                            ctx.beginPath()
                            ctx.arc(8.5, 8, 5.5, 0.45, Math.PI * 1.55)
                            ctx.quadraticCurveTo(6.0, 8.0, 12.8, 11.4)
                            ctx.closePath()
                            if (waveMode) {
                                ctx.fillStyle = "rgba(255, 255, 255, 0.35)"
                                ctx.fill()
                            }
                            ctx.stroke()
                        }
                    }
                    MouseArea {
                        id: styleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: im.toggleVisualizerStyle()
                    }
                    ToolTip.visible: styleMouse.containsMouse
                    ToolTip.text: (session && session.visualizerStyle === "wave")
                                  ? "Gaya Visualizer: Gelombang (Klik untuk Batang)"
                                  : "Gaya Visualizer: Batang (Klik untuk Gelombang)"
                    ToolTip.delay: 400
                }

                // 5. Equalizer tab
                Rectangle {
                    width: 38; height: 30; radius: 15
                    readonly property bool active: im.showPanel && im.panel === "equalizer"
                    color: active ? "#ffffff" : (eqMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                    Icon {
                        anchors.centerIn: parent
                        glyph: "equalizer"
                        size: 16
                        color: parent.active ? "#181a20" : "#ffffff"
                    }
                    MouseArea {
                        id: eqMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: im.selectPanel("equalizer")
                    }
                }
            }
        }
    }

    // ========================================================================
    // MAIN CONTENT: Left (Scalloped Cover & Controls) + Right (Panel)
    // ========================================================================
    RowLayout {
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 56
        anchors.rightMargin: 56
        anchors.topMargin: 4
        anchors.bottomMargin: 36
        spacing: 56

        // ---- LEFT COLUMN: Scalloped Cover + Centered Info & Controls ----
        ColumnLayout {
            visible: im.wide || !im.showPanel
            Layout.preferredWidth: im.wide && im.showPanel ? Math.min(460, im.width * 0.44) : -1
            Layout.fillWidth: !im.wide || !im.showPanel
            Layout.fillHeight: true
            spacing: 12

            Item { Layout.fillHeight: true }

            // Scalloped Cover + Dual-Mode Visualizer Stage
            Item {
                id: coverStage
                readonly property real side: Math.max(220, Math.min(
                    im.wide && im.showPanel ? Math.min(390, im.width * 0.36) : Math.min(420, im.width - 120),
                    im.height - 350,
                    390
                ))
                readonly property bool visOn: session ? session.visualizerEnabled : true
                readonly property real coverSide: Math.round(side * 0.62)
                Layout.preferredWidth: side
                Layout.preferredHeight: side
                Layout.alignment: Qt.AlignHCenter

                CircularSpectrum {
                    anchors.fill: parent
                    visible: coverStage.visOn
                    active: visualizer ? visualizer.active : false
                    playing: !!im.s.isPlaying && im.shown
                    style: session ? session.visualizerStyle : "bars"
                    accentColor: Theme.accent
                    coverRadius: (bigCover.width * bigCover.scale) / 2
                    scallops: 24
                    scallopDepth: 0.038
                }

                Cover {
                    id: bigCover
                    anchors.centerIn: parent
                    width: coverStage.coverSide
                    height: coverStage.coverSide
                    scalloped: true
                    scallops: 24
                    scallopDepth: 0.038
                    source: im.s.imageLarge || im.s.image || ""
                    scale: im.s.isPlaying ? 1.0 : 0.95
                    Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                }
            }

            // Centered Track Title, Artist + "•••", Album Name
            ColumnLayout {
                Layout.preferredWidth: Math.min(400, coverStage.side + 40)
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                spacing: 4

                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: im.s.name || "Tidak ada yang diputar"
                    font.pixelSize: 26
                    font.weight: Font.Black
                    color: "#ffffff"
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    LinkLabel {
                        text: im.s.artists || ""
                        font.pixelSize: 16
                        color: Qt.rgba(1, 1, 1, 0.72)
                        onClicked: if (im.s.artistId) { im.close(); Nav.go("artist", im.s.artistId) }
                    }
                    Label {
                        visible: !!im.s.hasTrack
                        text: "•••"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: moreHover.hovered ? "#ffffff" : (im.s.liked ? Theme.accent : Qt.rgba(1, 1, 1, 0.55))
                        HoverHandler { id: moreHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: player.toggleLike() }
                    }
                }

                Label {
                    visible: !!(im.s.album)
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: im.s.album || ""
                    font.pixelSize: 12
                    color: Qt.rgba(1, 1, 1, 0.45)
                    elide: Text.ElideRight
                    HoverHandler { cursorShape: im.s.albumId ? Qt.PointingHandCursor : Qt.ArrowCursor }
                    TapHandler { onTapped: if (im.s.albumId) { im.close(); Nav.go("album", im.s.albumId) } }
                }
            }

            // Wavy Squiggly Progress / Seek Bar with "-remaining" time
            RowLayout {
                id: wavySeekRow
                Layout.preferredWidth: Math.min(360, coverStage.side + 20)
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
                spacing: 10

                readonly property real durationMs: Math.max(1, im.s.durationMs || 0)
                readonly property real currentMs: seekMouse.pressed ? seekMouse.dragMs : (player ? player.position : 0)
                readonly property real progress: Math.max(0, Math.min(1, currentMs / durationMs))

                Label {
                    text: Theme.fmt(wavySeekRow.currentMs)
                    color: Qt.rgba(1, 1, 1, 0.72)
                    font.pixelSize: 11
                    font.features: { "tnum": 1 }
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                }

                Item {
                    id: wavyTrack
                    Layout.fillWidth: true
                    height: 22
                    property real _phase: 0

                    FrameAnimation {
                        running: im.shown && !!im.s.isPlaying
                        onTriggered: {
                            wavyTrack._phase += frameTime * 6.5
                            wavyCanvas.requestPaint()
                        }
                    }

                    Connections {
                        target: player
                        function onPositionChanged() { wavyCanvas.requestPaint() }
                    }

                    Canvas {
                        id: wavyCanvas
                        anchors.fill: parent
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            const cy = height / 2
                            const progX = Math.max(4, Math.min(width - 4, wavySeekRow.progress * width))
                            const playing = !!im.s.isPlaying

                            // 1. Unplayed straight track on the right
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.24)"
                            ctx.lineWidth = 3.6
                            ctx.lineCap = "round"
                            ctx.beginPath()
                            ctx.moveTo(progX, cy)
                            ctx.lineTo(width - 2, cy)
                            ctx.stroke()

                            // 2. Played sinusoidal wavy track on the left
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.85)"
                            ctx.lineWidth = 3.6
                            ctx.lineCap = "round"
                            ctx.beginPath()
                            const amp = playing ? 2.2 : 0.8
                            const freq = 0.24
                            for (let x = 2; x <= progX; x += 1.5) {
                                const y = cy + amp * Math.sin(x * freq - wavyTrack._phase)
                                if (x === 2) ctx.moveTo(x, y)
                                else ctx.lineTo(x, y)
                            }
                            ctx.stroke()

                            // 3. Rounded pill cap at progress tip
                            const tipY = cy + amp * Math.sin(progX * freq - wavyTrack._phase)
                            ctx.fillStyle = "#ffffff"
                            ctx.beginPath()
                            ctx.arc(progX, tipY, 3.2, 0, Math.PI * 2)
                            ctx.fill()
                        }
                    }

                    MouseArea {
                        id: seekMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !!im.s.hasTrack
                        property real dragMs: 0
                        function updateDrag(mx) {
                            const n = Math.max(0, Math.min(1, mx / Math.max(1, width)))
                            dragMs = n * wavySeekRow.durationMs
                            wavyCanvas.requestPaint()
                        }
                        onPressed: (mouse) => updateDrag(mouse.x)
                        onPositionChanged: (mouse) => { if (pressed) updateDrag(mouse.x) }
                        onReleased: player.seek(dragMs)
                    }
                }

                Label {
                    text: "-" + Theme.fmt(Math.max(0, (im.s.durationMs || 0) - wavySeekRow.currentMs))
                    color: Qt.rgba(1, 1, 1, 0.72)
                    font.pixelSize: 11
                    font.features: { "tnum": 1 }
                    Layout.preferredWidth: 38
                }
            }

            // Transport Controls with Scalloped Play/Pause Button
            Row {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                spacing: 22

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "shuffle"
                    size: 20
                    active: !!im.s.shuffle
                    tip: "Acak"
                    onClicked: player.toggleShuffle()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "previous"
                    size: 22
                    tip: "Sebelumnya (Ctrl+←)"
                    onClicked: player.previous()
                }

                // Scalloped White Play/Pause Badge Button with Glow
                Item {
                    width: 60
                    height: 60
                    anchors.verticalCenter: parent.verticalCenter
                    scale: playMouse.pressed ? 0.94 : (playMouse.containsMouse ? 1.06 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Canvas {
                        anchors.fill: parent
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            const cx = width / 2
                            const cy = height / 2
                            const rBase = 24.5
                            const amp = 1.8
                            const lobes = 12
                            ctx.fillStyle = "#ffffff"
                            ctx.beginPath()
                            for (let i = 0; i <= 180; i++) {
                                const a = (i / 180) * Math.PI * 2
                                const r = rBase + amp * Math.cos(lobes * a)
                                const x = cx + Math.cos(a) * r
                                const y = cy + Math.sin(a) * r
                                if (i === 0) ctx.moveTo(x, y)
                                else ctx.lineTo(x, y)
                            }
                            ctx.closePath()
                            ctx.fill()
                        }
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#ffffff"
                            shadowBlur: 0.65
                            shadowOpacity: 0.45
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                        }
                    }

                    Icon {
                        anchors.centerIn: parent
                        glyph: im.s.isPlaying ? "pause" : "play"
                        size: 24
                        color: "#14161b"
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: player.togglePlay()
                    }
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "next"
                    size: 22
                    tip: "Berikutnya (Ctrl+→)"
                    onClicked: player.next()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: im.s.repeat === "track" ? "repeat-one" : "repeat"
                    size: 20
                    active: im.s.repeat !== undefined && im.s.repeat !== "off"
                    tip: "Ulangi"
                    onClicked: player.cycleRepeat()
                }
            }

            // Full-width Volume Bar with Vertical Pill Thumb (matching both screenshots)
            RowLayout {
                id: volRow
                Layout.preferredWidth: Math.min(320, coverStage.side)
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                spacing: 12
                property int lastVol: 60
                readonly property int vol: (im.s.volume !== undefined && im.s.volume >= 0) ? im.s.volume : 80

                Icon {
                    glyph: volRow.vol === 0 ? "volume-off" : "volume"
                    size: 16
                    color: Qt.rgba(1, 1, 1, 0.72)
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            if (volRow.vol > 0) {
                                volRow.lastVol = volRow.vol
                                player.setVolume(0)
                            } else {
                                player.setVolume(volRow.lastVol || 60)
                            }
                        }
                    }
                }

                Item {
                    id: volBar
                    Layout.fillWidth: true
                    height: 20
                    readonly property real norm: Math.max(0, Math.min(1, volRow.vol / 100))

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 6
                        radius: 3
                        color: Qt.rgba(1, 1, 1, 0.22)

                        Rectangle {
                            width: volBar.norm * parent.width
                            height: parent.height
                            radius: 3
                            color: "#ffffff"
                        }
                    }

                    // Vertical pill thumb at the end of the volume bar
                    Rectangle {
                        width: 3.6
                        height: 18
                        radius: 1.8
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(parent.width - width, volBar.norm * parent.width + 3))
                        color: "#ffffff"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        function setFromX(mx) {
                            const pct = Math.round(Math.max(0, Math.min(1, mx / Math.max(1, width))) * 100)
                            player.setVolume(pct)
                        }
                        onPressed: (mouse) => setFromX(mouse.x)
                        onPositionChanged: (mouse) => { if (pressed) setFromX(mouse.x) }
                        onWheel: (wheel) => player.setVolume(Math.max(0, Math.min(100, volRow.vol + (wheel.angleDelta.y > 0 ? 5 : -5))))
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        // ---- RIGHT COLUMN: Lyrics / Equalizer / Queue ----
        ColumnLayout {
            visible: im.showPanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: im.shown && im.showPanel
                sourceComponent: im.panel === "lyrics" ? lyricsComp
                               : im.panel === "equalizer" ? eqComp
                               : queueComp
            }

            // Compact controls when narrow window hides the left cover column
            RowLayout {
                visible: !im.wide
                Layout.fillWidth: true
                spacing: 16
                Cover {
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
                    scalloped: true
                    source: im.s.image || ""
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label { Layout.fillWidth: true; text: im.s.name || ""; elide: Text.ElideRight; font.pixelSize: 16; font.weight: Font.Bold }
                    SeekBar { Layout.fillWidth: true }
                }
                TransportControls { size: 20 }
            }
        }
    }

    Component { id: lyricsComp; LyricsView {} }
    Component { id: queueComp; QueueView {} }
    Component { id: eqComp; EqualizerView {} }
}
