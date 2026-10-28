import QtQuick
import QtQuick.Controls

ScrollBar {
    id: s
    width: 10
    policy: ScrollBar.AsNeeded
    contentItem: Rectangle {
        implicitWidth: 6
        radius: 3
        color: Theme.alpha(Theme.text, s.pressed ? 0.4 : s.hovered ? 0.3 : 0.16)
        opacity: s.active || s.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
    }
}
