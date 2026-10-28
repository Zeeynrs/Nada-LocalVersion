import QtQuick
import QtQuick.Controls

TextField {
    id: f
    property string iconName

    implicitHeight: 44
    leftPadding: iconName ? 44 : 18
    rightPadding: 18
    font.pixelSize: 15
    color: Theme.text
    placeholderTextColor: Theme.faint
    selectionColor: Theme.alpha(Theme.accent, 0.45)
    selectedTextColor: Theme.text

    background: Rectangle {
        radius: height / 2
        color: f.activeFocus ? Theme.alpha(Theme.text, 0.12) : Theme.alpha(Theme.text, 0.07)
        border.width: f.activeFocus ? 2 : 0
        border.color: Theme.alpha(Theme.accent, 0.7)
        Icon {
            visible: f.iconName !== ""
            glyph: f.iconName
            size: 20
            color: Theme.dim
            anchors.verticalCenter: parent.verticalCenter
            x: 14
        }
    }
}
