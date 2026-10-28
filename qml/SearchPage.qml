import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    readonly property string pageKey: "search"
    property var results: ({})
    property bool searching: false
    property string lastQuery: ""

    Component.onCompleted: field.forceActiveFocus()

    Connections {
        target: library
        function onSearchFinished(query, data) {
            if (query !== page.lastQuery) return
            page.searching = false
            page.results = data
            if (data.error) session.toast(data.error)
        }
    }

    Timer {
        id: debounce
        interval: 350
        onTriggered: {
            const q = field.text.trim()
            if (!q) { page.results = {}; return }
            page.lastQuery = q
            page.searching = true
            library.search(q)
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight + 48
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: NScrollBar {}

        Column {
            id: col
            x: 20
            y: 52
            width: flick.width - 40
            spacing: 24

            RowLayout {
                width: parent.width
                spacing: 12
                NTextField {
                    id: field
                    Layout.fillWidth: true
                    Layout.maximumWidth: 560
                    Layout.leftMargin: 12
                    iconName: "search"
                    placeholderText: "Mau dengar apa?"
                    onTextChanged: debounce.restart()
                    Keys.onEscapePressed: text = ""
                }
                BusyIndicator { running: page.searching; visible: running; implicitWidth: 32; implicitHeight: 32 }
            }

            Label {
                visible: !page.results.tracks && !page.searching
                text: "Cari lagu, artis, album, atau playlist."
                color: Theme.dim
                font.pixelSize: 15
                leftPadding: 12
            }

            Column {
                width: parent.width
                visible: (page.results.tracks || []).length > 0
                spacing: 2
                Label { text: "Lagu"; font.pixelSize: 22; font.weight: Font.Bold; leftPadding: 12; bottomPadding: 6 }
                Repeater {
                    model: page.results.tracks || []
                    TrackRow {
                        width: col.width
                        track: modelData
                        number: index + 1
                        onPlay: player.playUris(page.results.tracks.map(x => x.uri), index)
                    }
                }
            }
            CardGrid { width: parent.width; title: "Artis"; items: page.results.artists || [] }
            CardGrid { width: parent.width; title: "Album"; items: page.results.albums || [] }
            CardGrid { width: parent.width; title: "Playlist"; items: page.results.playlists || [] }
        }
    }
}
