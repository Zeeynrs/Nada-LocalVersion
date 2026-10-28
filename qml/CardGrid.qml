import QtQuick
import QtQuick.Controls

// Responsive grid of cards; no nested scrolling so the page scrolls as one.
Column {
    id: g
    property string title
    property var items: []
    property int rows: 1
    property bool expanded: false
    readonly property int columns: Math.max(2, Math.floor((width + 8) / 196))
    readonly property real cardWidth: (width - (columns - 1) * 4) / columns
    readonly property int limit: expanded ? items.length : columns * rows

    visible: items.length > 0
    spacing: 8

    Item {
        width: parent.width
        height: 36
        Label {
            text: g.title
            font.pixelSize: 22
            font.weight: Font.Bold
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
        }
        LinkLabel {
            visible: g.items.length > g.columns * g.rows
            text: g.expanded ? "Lebih sedikit" : "Tampilkan semua"
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            onClicked: g.expanded = !g.expanded
        }
    }

    Flow {
        width: parent.width
        spacing: 4
        Repeater {
            model: g.items.slice(0, g.limit)
            Card {
                width: g.cardWidth
                item: modelData
            }
        }
    }
}
