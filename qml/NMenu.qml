import QtQuick
import QtQuick.Controls

Menu {
    id: m
    padding: 6
    background: Rectangle {
        implicitWidth: 230
        color: Theme.surface3
        radius: 14
        border.color: Theme.alpha(Theme.text, 0.07)
    }
    delegate: MenuItem {
        id: mi
        implicitHeight: 38
        contentItem: Label {
            text: mi.text
            leftPadding: 10
            font.pixelSize: 14
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 9
            color: mi.highlighted ? Theme.alpha(Theme.text, 0.09) : "transparent"
        }
    }
}
