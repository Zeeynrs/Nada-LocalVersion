import QtQuick
import QtQuick.Controls

AbstractButton {
    id: b
    property string iconName
    property bool active: false

    implicitHeight: 44
    hoverEnabled: true
    focusPolicy: Qt.NoFocus

    background: Rectangle {
        radius: height / 2
        color: b.active ? Theme.alpha(Theme.accent, 0.16) : b.hovered ? Theme.alpha(Theme.text, 0.06) : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    contentItem: Row {
        leftPadding: 14
        spacing: 14
        Icon {
            glyph: b.iconName
            size: 22
            color: b.active ? Theme.accent : Theme.dim
            anchors.verticalCenter: parent.verticalCenter
        }
        Label {
            text: b.text
            font.pixelSize: 15
            font.weight: b.active ? Font.Bold : Font.Medium
            color: b.active ? Theme.text : Theme.dim
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
