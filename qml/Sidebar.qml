import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: side
    property string currentKey
    property bool creatingPlaylist: false

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        anchors.topMargin: 16
        spacing: 4

        Row {
            Layout.leftMargin: 10
            Layout.bottomMargin: 14
            spacing: 10
            Image {
                source: Qt.resolvedUrl("../data/nada-local.svg")
                width: 32; height: 32
                sourceSize: Qt.size(64, 64)
            }
            Label {
                text: "nada"
                font.pixelSize: 24
                font.weight: Font.Black
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: 20
                width: localBadge.implicitWidth + 14
                radius: 10
                color: Theme.alpha(Theme.accent, 0.16)
                border.width: 1
                border.color: Theme.alpha(Theme.accent, 0.35)
                Label {
                    id: localBadge
                    anchors.centerIn: parent
                    text: "LOCAL"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 1.0
                    color: Theme.accent
                }
            }
        }

        NavItem { Layout.fillWidth: true; text: "Beranda"; iconName: "home"; active: side.currentKey === "home"; onClicked: Nav.go("home") }
        NavItem { Layout.fillWidth: true; text: "Cari"; iconName: "search"; active: side.currentKey === "search"; onClicked: Nav.go("search") }
        NavItem { Layout.fillWidth: true; text: "Semua Lagu"; iconName: "library"; active: side.currentKey === "playlist:all"; onClicked: Nav.go("playlist", "all") }
        NavItem { Layout.fillWidth: true; text: "Lagu Disukai"; iconName: "heart"; active: side.currentKey === "liked:"; onClicked: Nav.go("liked") }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 6
            Layout.topMargin: 16
            Layout.bottomMargin: 2
            Label {
                Layout.fillWidth: true
                text: "Playlist"
                color: Theme.faint
                font.pixelSize: 12
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.2
            }
            IconButton {
                iconName: "queue-add"
                size: 16
                tip: "Buat playlist baru"
                onClicked: {
                    side.creatingPlaylist = !side.creatingPlaylist
                    if (side.creatingPlaylist) newPlField.forceActiveFocus()
                }
            }
        }

        RowLayout {
            visible: side.creatingPlaylist
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            spacing: 6
            NTextField {
                id: newPlField
                Layout.fillWidth: true
                placeholderText: "Nama playlist…"
                onAccepted: {
                    if (text.trim()) {
                        library.createPlaylist(text.trim())
                        text = ""
                        side.creatingPlaylist = false
                    }
                }
                Keys.onEscapePressed: {
                    text = ""
                    side.creatingPlaylist = false
                }
            }
        }

        ListView {
            id: pl
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: library.playlists
            spacing: 2
            ScrollBar.vertical: NScrollBar {}
            delegate: AbstractButton {
                id: d
                width: pl.width
                height: 56
                hoverEnabled: true
                focusPolicy: Qt.NoFocus
                readonly property bool active: side.currentKey === "playlist:" + modelData.id
                readonly property bool playingHere: player.state.contextUri === modelData.uri
                onClicked: Nav.go("playlist", modelData.id)
                background: Rectangle {
                    radius: 12
                    color: d.active ? Theme.alpha(Theme.accent, 0.14) : d.hovered ? Theme.alpha(Theme.text, 0.06) : "transparent"
                }
                contentItem: RowLayout {
                    spacing: 12
                    Cover {
                        Layout.leftMargin: 6
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 42
                        radius: 8
                        source: modelData.imageSmall || ""
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Label {
                            Layout.fillWidth: true
                            text: modelData.name
                            elide: Text.ElideRight
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: d.playingHere ? Theme.accent : Theme.text
                        }
                        Label {
                            Layout.fillWidth: true
                            text: modelData.subtitle
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            color: Theme.dim
                        }
                    }
                    Icon {
                        visible: d.playingHere && player.state.isPlaying
                        glyph: "volume"
                        size: 16
                        color: Theme.accent
                        Layout.rightMargin: 8
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.alpha(Theme.text, 0.06); Layout.topMargin: 4 }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8
            Cover {
                Layout.leftMargin: 8
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                round: true
                source: ""
                fallbackIcon: "speaker"
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label {
                    Layout.fillWidth: true
                    text: (library.stats.tracks || 0) + " Lagu Lokal"
                    elide: Text.ElideRight
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                Label {
                    Layout.fillWidth: true
                    text: library.scanning ? "Memindai folder…" : ((library.stats.albums || 0) + " album • " + (library.stats.artists || 0) + " artis")
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    color: Theme.dim
                }
            }
            IconButton {
                iconName: "refresh"
                enabled: !library.scanning
                tip: "Pindai ulang folder musik (Ctrl+R)"
                onClicked: library.refreshAll()
            }
            IconButton {
                iconName: "settings"
                tip: "Pengaturan (Ctrl+,)"
                active: side.currentKey === "settings"
                onClicked: Nav.go("settings")
            }
        }
    }
}
