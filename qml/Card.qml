import QtQuick
import QtQuick.Controls

Item {
    id: card
    property var item: ({})
    readonly property bool round: item.kind === "artist"

    implicitHeight: col.implicitHeight + 24

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    // a MouseArea (not TapHandler) so clicks on the play button don't also navigate
    MouseArea { anchors.fill: parent; onClicked: Nav.go(card.item.kind, card.item.id) }

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: hover.hovered ? Theme.alpha(Theme.text, 0.07) : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Column {
        id: col
        x: 12; y: 12
        width: card.width - 24
        spacing: 4

        Item {
            width: parent.width
            height: width
            Cover {
                anchors.fill: parent
                source: card.item.image || ""
                round: card.round
                radius: 14
                fallbackIcon: card.round ? "speaker" : "note"
                scale: hover.hovered ? 1.02 : 1
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
            IconButton {
                iconName: "play"
                filled: true
                size: 22
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 8
                opacity: hover.hovered ? 1 : 0
                anchors.bottomMargin: hover.hovered ? 8 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                Behavior on anchors.bottomMargin { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                onClicked: player.playContext(card.item.uri, "")
            }
        }
        Item { width: 1; height: 6 }
        Label {
            width: parent.width
            text: card.item.name || ""
            elide: Text.ElideRight
            font.pixelSize: 15
            font.weight: Font.DemiBold
            horizontalAlignment: card.round ? Text.AlignHCenter : Text.AlignLeft
        }
        Label {
            width: parent.width
            text: card.item.kind === "album" && card.item.year ? card.item.year + " • " + card.item.subtitle : (card.item.subtitle || "")
            elide: Text.ElideRight
            color: Theme.dim
            font.pixelSize: 13
            horizontalAlignment: card.round ? Text.AlignHCenter : Text.AlignLeft
        }
    }
}
