import QtQuick
import QtQuick.Controls

Row {
    id: tc
    property int size: 22
    readonly property var s: player.state
    spacing: 8

    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        iconName: "shuffle"; size: tc.size - 2
        active: !!tc.s.shuffle
        tip: "Acak"
        onClicked: player.toggleShuffle()
    }
    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        iconName: "previous"; size: tc.size + 2
        tip: "Sebelumnya (Ctrl+←)"
        onClicked: player.previous()
    }
    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        iconName: tc.s.isPlaying ? "pause" : "play"
        size: tc.size + 4
        filled: true
        tip: "Putar/Jeda (Spasi)"
        onClicked: player.togglePlay()
    }
    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        iconName: "next"; size: tc.size + 2
        tip: "Berikutnya (Ctrl+→)"
        onClicked: player.next()
    }
    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        iconName: tc.s.repeat === "track" ? "repeat-one" : "repeat"
        size: tc.size - 2
        active: tc.s.repeat !== undefined && tc.s.repeat !== "off"
        tip: "Ulangi"
        onClicked: player.cycleRepeat()
    }
}
