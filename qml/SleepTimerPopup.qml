import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: sp
    width: 280
    padding: 14
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    readonly property var options: [
        { mode: "off", label: "Matikan Timer", sub: "Putar tanpa batas waktu" },
        { mode: "end_of_track", label: "Akhir Lagu Ini", sub: "Berhenti setelah lagu saat ini selesai" },
        { mode: "15", label: "15 Menit", sub: "Fade-out halus di 10 detik terakhir" },
        { mode: "30", label: "30 Menit", sub: "Fade-out halus di 10 detik terakhir" },
        { mode: "45", label: "45 Menit", sub: "Fade-out halus di 10 detik terakhir" },
        { mode: "60", label: "60 Menit", sub: "Fade-out halus di 10 detik terakhir" }
    ]

    background: Rectangle {
        color: Theme.surface3
        radius: 20
        border.color: Theme.alpha(Theme.text, 0.08)
    }

    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 } }

    contentItem: ColumnLayout {
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            Layout.bottomMargin: 4
            Label {
                Layout.fillWidth: true
                text: "Sleep Timer"
                font.pixelSize: 16
                font.weight: Font.Bold
            }
            Label {
                visible: player.sleepMode !== "off"
                text: player.sleepLabel
                font.family: Theme.mono
                font.pixelSize: 12
                font.weight: Font.Bold
                color: Theme.accent
            }
        }

        Repeater {
            model: sp.options
            AbstractButton {
                id: optBtn
                Layout.fillWidth: true
                implicitHeight: 46
                hoverEnabled: true
                focusPolicy: Qt.NoFocus
                readonly property bool active: player.sleepMode === modelData.mode
                onClicked: {
                    player.setSleepTimer(modelData.mode)
                    sp.close()
                }
                background: Rectangle {
                    radius: 12
                    color: optBtn.active ? Theme.alpha(Theme.accent, 0.16)
                         : optBtn.hovered ? Theme.alpha(Theme.text, 0.07) : "transparent"
                }
                contentItem: ColumnLayout {
                    spacing: 1
                    Label {
                        Layout.leftMargin: 10
                        Layout.fillWidth: true
                        text: modelData.label
                        font.pixelSize: 14
                        font.weight: optBtn.active ? Font.Bold : Font.Medium
                        color: optBtn.active ? Theme.accent : Theme.text
                    }
                    Label {
                        Layout.leftMargin: 10
                        Layout.fillWidth: true
                        text: modelData.sub
                        font.pixelSize: 11
                        color: Theme.dim
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
