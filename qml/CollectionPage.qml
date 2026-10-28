import QtQuick
import QtQuick.Controls

// Playlist, album and liked songs.
Item {
    id: page
    property string kind
    property string itemId
    readonly property string pageKey: kind + ":" + itemId
    property var info: ({})
    property bool loading: true

    function reload() {
        loading = true
        library.load(kind, itemId)
    }
    Component.onCompleted: reload()

    Connections {
        target: library
        function onLoaded(key, data) {
            if (key !== page.pageKey) return
            page.info = data
            page.loading = false
            if (data.error) session.toast(data.error)
        }
    }

    function playAt(i) {
        const t = info.tracks || []
        if (info.playUri)
            player.playContext(info.playUri, t[i] ? t[i].uri : "")
        else
            player.playUris(t.map(x => x.uri), i)
    }
    function playAll() { playAt(0) }
    function shuffleAll() {
        if (info.playUri) {
            player.shufflePlay(info.playUri)
            return
        }
        const uris = (info.tracks || []).map(x => x.uri)
        for (let i = uris.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [uris[i], uris[j]] = [uris[j], uris[i]]
        }
        player.playUris(uris, 0)
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: page.info.tracks || []
        reuseItems: true
        bottomMargin: 24
        ScrollBar.vertical: NScrollBar {}

        header: PageHeader {
            width: list.width
            info: page.info
            loading: page.loading
            fallbackIcon: page.kind === "liked" ? "heart" : "note"
            onPlayAll: page.playAll()
            onShuffleAll: page.shuffleAll()
        }

        delegate: TrackRow {
            track: modelData
            number: index + 1
            showCover: page.kind !== "album"
            showAlbum: page.kind !== "album"
            onPlay: page.playAt(index)
        }

        footer: Label {
            width: list.width
            visible: !!page.info.note
            text: page.info.note || ""
            padding: 32
            wrapMode: Text.WordWrap
            color: Theme.dim
            font.pixelSize: 14
        }
    }
}
