import QtQuick
import QtQuick.Controls

AbstractButton {
    id: b
    property string iconName
    property int size: 20
    property bool active: false
    property bool filled: false
    property color tint: Theme.text
    property string tip

    implicitWidth: size + (filled ? 24 : 16)
    implicitHeight: implicitWidth
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    opacity: enabled ? 1 : 0.35

    background: Rectangle {
        radius: height / 2
        color: b.filled ? (b.down ? Qt.darker(Theme.accent, 1.2) : b.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
                        : b.down ? Theme.alpha(Theme.text, 0.14) : b.hovered ? Theme.alpha(Theme.text, 0.08) : "transparent"
        scale: b.filled && b.hovered ? 1.06 : 1
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    contentItem: Item {
        Icon {
            anchors.centerIn: parent
            glyph: b.iconName
            size: b.size
            color: b.filled ? Theme.accentText : b.active ? Theme.accent : b.tint
        }
        Rectangle {
            visible: b.active && !b.filled
            implicitWidth: 4; implicitHeight: 4; radius: 2
            color: Theme.accent
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -2
        }
    }

    ToolTip.visible: tip !== "" && hovered
    ToolTip.text: tip
    ToolTip.delay: 600
}
