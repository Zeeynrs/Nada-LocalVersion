import QtQuick
import QtQuick.Controls

Item {
    id: page
    property string itemId
    readonly property string pageKey: "artist:" + itemId
    property var info: ({})
    property bool loading: true

    Component.onCompleted: library.load("artist", itemId)
    Connections {
        target: library
        function onLoaded(key, data) {
            if (key !== page.pageKey) return
            page.info = data
            page.loading = false
            if (data.error) session.toast(data.error)
        }
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: page.info.tracks || []
        bottomMargin: 24
        ScrollBar.vertical: NScrollBar {}

        header: Column {
            width: list.width
            PageHeader {
                width: parent.width
                info: page.info
                loading: page.loading
                round: true
                fallbackIcon: "speaker"
                onPlayAll: player.playContext(page.info.uri, "")
                onShuffleAll: player.shufflePlay(page.info.uri)
            }
            Label {
                visible: (page.info.tracks || []).length > 0
                text: "Populer"
                font.pixelSize: 22
                font.weight: Font.Bold
                leftPadding: 32
                bottomPadding: 8
            }
        }

        delegate: TrackRow {
            track: modelData
            number: index + 1
            showAlbum: true
            onPlay: player.playUris((page.info.tracks || []).map(x => x.uri), index)
        }

        footer: Item {
            width: list.width
            height: grid.height + 40
            CardGrid {
                id: grid
                x: 20
                y: 24
                width: parent.width - 40
                title: "Diskografi"
                items: page.info.albums || []
                rows: 2
            }
        }
    }
}
