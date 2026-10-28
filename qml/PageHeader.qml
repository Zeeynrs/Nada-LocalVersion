import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Big cover + title block used by playlist, album, liked and artist pages.
Item {
    id: h
    property var info: ({})
    property bool loading: false
    property bool round: false
    property string fallbackIcon: "note"
    signal playAll()
    signal shuffleAll()

    implicitHeight: row.implicitHeight + 72

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 32
        anchors.topMargin: 56
        spacing: 28

        Cover {
            Layout.preferredWidth: Math.min(220, h.width * 0.24)
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignBottom
            radius: 20
            round: h.round
            source: h.info.imageLarge || h.info.image || ""
            fallbackIcon: h.fallbackIcon
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignBottom
            spacing: 6
            Label {
                text: h.info.typeLabel || (h.round ? "Artis" : "")
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.dim
            }
            Label {
                Layout.fillWidth: true
                text: h.loading && !h.info.name ? "Memuat…" : (h.info.name || "")
                font.pixelSize: Math.max(30, Math.min(58, h.width / 16))
                font.weight: Font.Black
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                lineHeight: 0.95
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: h.info.description || h.info.genres || ""
                textFormat: Text.PlainText
                color: Theme.dim
                font.pixelSize: 14
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
            }
            Label {
                text: h.info.kind === "playlist"
                      ? h.info.subtitle + (h.info.tracks ? " • " + h.info.tracks.length + " lagu" : "")
                      : h.info.kind === "artist" ? "" : (h.info.subtitle || "")
                visible: text !== ""
                font.pixelSize: 14
                color: Theme.text
            }
            Row {
                Layout.topMargin: 14
                spacing: 12
                IconButton {
                    iconName: "play"
                    filled: true
                    size: 28
                    tip: "Putar"
                    enabled: !h.loading && (!!h.info.playUri || (h.info.tracks && h.info.tracks.length > 0))
                    onClicked: h.playAll()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "shuffle"
                    size: 26
                    tint: Theme.dim
                    tip: "Putar acak"
                    enabled: !h.loading
                    onClicked: h.shuffleAll()
                }
                BusyIndicator {
                    anchors.verticalCenter: parent.verticalCenter
                    running: h.loading
                    visible: running
                    implicitWidth: 32; implicitHeight: 32
                }
            }
        }
    }
}
