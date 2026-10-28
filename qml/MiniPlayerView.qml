import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

// Compact Floating Mini Player Mode (Ctrl+M) with blurred cover, 1-line synced lyric, and Always-on-Top pin.
Item {
    id: mini
    signal exitMini()
    signal togglePin()
    property bool pinned: false
    readonly property var s: player ? player.state : ({})
    readonly property string activeLyric: {
        if (!lyrics || !lyrics.lines || lyrics.lines.length === 0) return ""
        const idx = lyrics.current
        if (idx >= 0 && idx < lyrics.lines.length) return lyrics.lines[idx].text || ""
        return ""
    }

    Rectangle {
        anchors.fill: parent
        color: "#111318"
    }

    Image {
        id: miniBg
        anchors.fill: parent
        source: mini.s.image || ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(128, 128)
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: miniBg
        blurEnabled: true
        blur: 1.0
        blurMax: 48
        saturation: 0.4
        brightness: -0.28
        opacity: miniBg.status === Image.Ready ? 1 : 0
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.06, 0.07, 0.09, 0.55)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Cover {
                Layout.preferredWidth: 68
                Layout.preferredHeight: 68
                scalloped: true
                scallops: 20
                source: mini.s.image || ""
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: mini.exitMini() }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Label {
                        Layout.fillWidth: true
                        text: mini.s.hasTrack ? mini.s.name : "Nada Local"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: "#ffffff"
                        elide: Text.ElideRight
                    }

                    // Pin (Always on Top) button
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: mini.pinned ? Theme.alpha(Theme.accent, 0.28) : (pinMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent")
                        Label {
                            anchors.centerIn: parent
                            text: "📌"
                            font.pixelSize: 11
                            opacity: mini.pinned ? 1.0 : 0.65
                        }
                        MouseArea {
                            id: pinMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mini.togglePin()
                        }
                        ToolTip.visible: pinMouse.containsMouse
                        ToolTip.text: mini.pinned ? "Lepas Sematan (Always on Top Aktif)" : "Sematkan di Atas Jendela Lain"
                    }

                    // Expand back to full window button
                    IconButton {
                        iconName: "expand"
                        size: 16
                        tip: "Kembali ke Jendela Penuh (Ctrl+M)"
                        onClicked: mini.exitMini()
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: mini.s.hasTrack ? mini.s.artists : "Pilih lagu untuk mulai"
                    font.pixelSize: 12
                    color: Qt.rgba(1, 1, 1, 0.72)
                    elide: Text.ElideRight
                }

                // Live 1-line synchronized lyric
                Label {
                    visible: mini.activeLyric !== ""
                    Layout.fillWidth: true
                    text: "♪ " + mini.activeLyric
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Theme.accent
                    elide: Text.ElideRight
                }
            }

            Row {
                spacing: 4
                IconButton {
                    iconName: "previous"
                    size: 18
                    onClicked: player.previous()
                }
                IconButton {
                    iconName: mini.s.isPlaying ? "pause" : "play"
                    filled: true
                    size: 20
                    onClicked: player.togglePlay()
                }
                IconButton {
                    iconName: "next"
                    size: 18
                    onClicked: player.next()
                }
            }
        }

        SeekBar {
            Layout.fillWidth: true
        }
    }
}
