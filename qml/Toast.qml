import QtQuick
import QtQuick.Controls

Rectangle {
    id: t
    property bool shown: false

    function show(msg) {
        label.text = msg
        shown = true
        hideTimer.restart()
    }

    anchors.horizontalCenter: parent.horizontalCenter
    y: shown ? parent.height - height - 112 : parent.height + 10
    z: 1000
    width: Math.min(label.implicitWidth + 40, parent.width - 48)
    height: 44
    radius: 22
    color: Theme.surface3
    border.color: Theme.alpha(Theme.text, 0.08)
    Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    Label {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, t.width - 40)
        elide: Text.ElideRight
        font.pixelSize: 14
    }
    Timer { id: hideTimer; interval: 3200; onTriggered: t.shown = false }
    MouseArea { anchors.fill: parent; onClicked: t.shown = false }
}
