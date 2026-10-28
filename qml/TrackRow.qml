import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: row
    property var track: ({})
    property int number: 0
    property bool showCover: true
    property bool showAlbum: true
    readonly property bool current: track.uri !== undefined && player.state.uri === track.uri
    readonly property bool playing: current && player.state.isPlaying
    signal play()

    width: ListView.view ? ListView.view.width : (parent ? parent.width : 400)
    height: 58
    opacity: track.playable === false ? 0.45 : 1

    HoverHandler { id: hover }
    TapHandler { onDoubleTapped: row.play() }
    TapHandler { acceptedButtons: Qt.RightButton; onTapped: menu.popup() }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        radius: 12
        color: hover.hovered ? Theme.alpha(Theme.text, 0.06) : row.current ? Theme.alpha(Theme.accent, 0.07) : "transparent"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 20
        spacing: 14

        Item {
            Layout.preferredWidth: 26
            Layout.fillHeight: true
            Label {
                anchors.centerIn: parent
                visible: !hover.hovered && !row.playing
                text: row.number > 0 ? row.number : ""
                color: row.current ? Theme.accent : Theme.dim
                font.pixelSize: 14
            }
            Icon {
                anchors.centerIn: parent
                visible: row.playing && !hover.hovered
                glyph: "equalizer"
                size: 18
                color: Theme.accent
            }
            IconButton {
                anchors.centerIn: parent
                visible: hover.hovered
                iconName: row.playing ? "pause" : "play"
                size: 20
                onClicked: row.playing ? player.togglePlay() : row.play()
            }
        }

        Cover {
            visible: row.showCover
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            source: row.track.imageSmall || ""
            simple: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 120
            spacing: 2
            Label {
                Layout.fillWidth: true
                text: row.track.name || ""
                elide: Text.ElideRight
                font.pixelSize: 15
                font.weight: Font.Medium
                color: row.current ? Theme.accent : Theme.text
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Rectangle {
                    visible: !!row.track.format
                    implicitWidth: fmtLabel.implicitWidth + 10
                    implicitHeight: 16
                    radius: 4
                    color: Theme.alpha(Theme.accent, 0.16)
                    Label {
                        id: fmtLabel
                        anchors.centerIn: parent
                        text: row.track.format || ""
                        font.pixelSize: 9
                        font.bold: true
                        color: Theme.accent
                    }
                }
                LinkLabel {
                    Layout.fillWidth: true
                    text: row.track.artists || ""
                    onClicked: Nav.go("artist", row.track.artistId)
                }
            }
        }

        LinkLabel {
            visible: row.showAlbum && row.width > 760
            Layout.preferredWidth: row.width * 0.26
            text: row.track.album || ""
            onClicked: Nav.go("album", row.track.albumId)
        }

        IconButton {
            iconName: "queue-add"
            size: 18
            tip: "Tambah ke antrean"
            opacity: hover.hovered ? 1 : 0
            onClicked: player.addToQueue(row.track.uri)
        }

        Label {
            Layout.preferredWidth: 44
            horizontalAlignment: Text.AlignRight
            text: Theme.fmt(row.track.durationMs)
            color: Theme.dim
            font.pixelSize: 13
            font.features: { "tnum": 1 }
        }
    }

    NMenu {
        id: menu
        MenuItem { text: "Putar"; onTriggered: row.play() }
        MenuItem { text: "Tambah ke antrean"; onTriggered: player.addToQueue(row.track.uri) }
        MenuItem {
            text: row.track.liked ? "Hapus dari Lagu Disukai" : "Simpan ke Lagu Disukai"
            onTriggered: player.setLiked(row.track.uri, !row.track.liked)
        }
        MenuItem { text: "Buka album"; enabled: !!row.track.albumId; onTriggered: Nav.go("album", row.track.albumId) }
        MenuItem { text: "Buka artis"; enabled: !!row.track.artistId; onTriggered: Nav.go("artist", row.track.artistId) }
        MenuItem { text: "Edit Tag Metadata…"; enabled: !!row.track.uri; onTriggered: Nav.openTagEditor(row.track) }
        MenuItem { text: "Buka folder file"; enabled: !!row.track.path; onTriggered: session.openContainingFolder(row.track.path) }
        MenuItem { text: "Salin path file"; enabled: !!row.track.path; onTriggered: session.copy(row.track.path) }
    }
}
