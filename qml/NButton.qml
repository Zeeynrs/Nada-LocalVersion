import QtQuick
import QtQuick.Controls

AbstractButton {
    id: b
    property bool primary: false
    property string iconName

    implicitHeight: 40
    implicitWidth: row.implicitWidth + 32
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    opacity: enabled ? 1 : 0.4

    background: Rectangle {
        radius: height / 2
        color: b.primary ? (b.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
                         : (b.down ? Theme.alpha(Theme.text, 0.16) : b.hovered ? Theme.alpha(Theme.text, 0.11) : Theme.alpha(Theme.text, 0.07))
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    contentItem: Item {
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8
            Icon {
                visible: b.iconName !== ""
                glyph: b.iconName
                size: 18
                anchors.verticalCenter: parent.verticalCenter
                color: b.primary ? Theme.accentText : Theme.text
            }
            Label {
                text: b.text
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: b.primary ? Theme.accentText : Theme.text
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
