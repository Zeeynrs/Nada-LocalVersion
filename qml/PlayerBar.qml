import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: bar
    signal openImmersive()
    readonly property var s: player.state
    readonly property real sideWidth: Math.max(240, width * 0.28)

    // left: now playing
    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: bar.sideWidth
        spacing: 14

        Cover {
            Layout.preferredWidth: 60
            Layout.preferredHeight: 60
            radius: 12
            source: bar.s.image || ""
            HoverHandler { id: coverHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: bar.openImmersive() }
            Rectangle {
                anchors.fill: parent
                radius: 12
                color: Theme.alpha(Theme.bg, 0.5)
                visible: coverHover.hovered
                Icon { anchors.centerIn: parent; glyph: "expand"; size: 22 }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label {
                Layout.fillWidth: true
                text: bar.s.hasTrack ? bar.s.name : "Tidak ada yang diputar"
                elide: Text.ElideRight
                font.pixelSize: 15
                font.weight: Font.DemiBold
                HoverHandler { cursorShape: bar.s.albumId ? Qt.PointingHandCursor : Qt.ArrowCursor }
                TapHandler { onTapped: if (bar.s.albumId) Nav.go("album", bar.s.albumId) }
            }
            LinkLabel {
                Layout.fillWidth: true
                text: bar.s.hasTrack ? bar.s.artists : "Pilih lagu lokal untuk mulai"
                onClicked: if (bar.s.artistId) Nav.go("artist", bar.s.artistId)
            }
            Label {
                visible: !!bar.s.hasTrack && !!bar.s.quality
                Layout.fillWidth: true
                text: bar.s.quality || ""
                font.pixelSize: 10
                font.family: Theme.mono
                color: Theme.accent
                elide: Text.ElideRight
            }
        }
        IconButton {
            visible: !!bar.s.hasTrack
            iconName: bar.s.liked ? "heart" : "heart-outline"
            tint: bar.s.liked ? Theme.accent : Theme.dim
            tip: bar.s.liked ? "Hapus dari Lagu Disukai" : "Simpan ke Lagu Disukai"
            onClicked: player.toggleLike()
        }
    }

    // center: transport + seek
    Column {
        anchors.centerIn: parent
        width: Math.min(620, bar.width - 2 * bar.sideWidth - 48)
        spacing: 2
        TransportControls { anchors.horizontalCenter: parent.horizontalCenter; size: 20 }
        SeekBar { width: parent.width }
    }

    // right: extras
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            iconName: "lyrics"
            tip: "Lirik, Visualizer & Equalizer (Ctrl+L)"
            onClicked: bar.openImmersive()
        }
        IconButton {
            id: devButton
            anchors.verticalCenter: parent.verticalCenter
            iconName: "devices"
            tip: "Output Audio (" + (bar.s.deviceName || "Otomatis") + ")"
            active: !!bar.s.deviceId && bar.s.deviceId !== "auto"
            onClicked: devices.opened ? devices.close() : devices.open()
            DevicesPopup {
                id: devices
                x: devButton.width - width
                y: -height - 16
            }
        }
        VolumeControl {
            anchors.verticalCenter: parent.verticalCenter
            sliderWidth: Math.min(120, Math.max(70, bar.width * 0.08))
        }
    }

    Label {
        visible: !!bar.s.deviceId && bar.s.deviceId !== "auto"
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        text: "▶ " + (bar.s.deviceName || "")
        color: Theme.accent
        font.pixelSize: 11
        font.weight: Font.DemiBold
    }
}
