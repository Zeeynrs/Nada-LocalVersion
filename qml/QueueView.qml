import QtQuick
import QtQuick.Controls

ListView {
    id: q
    clip: true
    model: player.queue
    spacing: 2
    ScrollBar.vertical: NScrollBar {}
    Component.onCompleted: player.refreshQueue()

    header: Label {
        text: "Berikutnya"
        font.pixelSize: 22
        font.weight: Font.Bold
        leftPadding: 12
        bottomPadding: 10
    }
    delegate: TrackRow {
        track: modelData
        number: index + 1
        showAlbum: false
        onPlay: player.skip(index + 1)
    }
    Label {
        anchors.centerIn: parent
        visible: q.count === 0
        text: "Antrean kosong"
        color: Theme.dim
        font.pixelSize: 16
    }
}
