import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: p
    width: 360
    padding: 14
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    onOpened: player.refreshDevices()

    function deviceIcon(type) {
        if (type === "smartphone") return "smartphone"
        if (type === "computer") return "computer"
        return "speaker"
    }

    background: Rectangle {
        color: Theme.surface3
        radius: 20
        border.color: Theme.alpha(Theme.text, 0.07)
    }

    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 } }

    contentItem: ColumnLayout {
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                text: "Perangkat Output Audio"
                font.pixelSize: 17
                font.weight: Font.Bold
            }
            IconButton { iconName: "refresh"; size: 18; tip: "Muat ulang"; onClicked: player.refreshDevices() }
        }

        Repeater {
            model: player.devices
            AbstractButton {
                id: d
                Layout.fillWidth: true
                implicitHeight: 54
                hoverEnabled: true
                focusPolicy: Qt.NoFocus
                onClicked: { player.transfer(modelData.id); p.close() }
                background: Rectangle {
                    radius: 12
                    color: modelData.active ? Theme.alpha(Theme.accent, 0.14) : d.hovered ? Theme.alpha(Theme.text, 0.07) : "transparent"
                }
                contentItem: RowLayout {
                    spacing: 12
                    Icon {
                        Layout.leftMargin: 10
                        glyph: p.deviceIcon(modelData.type)
                        size: 24
                        color: modelData.active ? Theme.accent : Theme.dim
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label {
                            Layout.fillWidth: true
                            text: modelData.name
                            elide: Text.ElideRight
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            color: modelData.active ? Theme.accent : Theme.text
                        }
                        Label {
                            text: modelData.active ? "Aktif digunakan" : (modelData.id === "auto" ? "Default PipeWire/ALSA" : modelData.id)
                            font.pixelSize: 11
                            color: Theme.dim
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.alpha(Theme.text, 0.08); Layout.topMargin: 4 }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8
            Rectangle {
                implicitWidth: 8; implicitHeight: 8; radius: 4
                color: player.mpvAvailable ? "#7ee08f" : Theme.danger
            }
            Label {
                Layout.fillWidth: true
                text: player.mpvAvailable ? ("Engine Audio: " + player.mpvVersion) : "libmpv tidak ditemukan"
                font.pixelSize: 12
                color: Theme.dim
                elide: Text.ElideRight
            }
        }
    }
}
