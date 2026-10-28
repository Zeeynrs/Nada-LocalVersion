import QtQuick
import QtQuick.Controls

// Dim text that underlines on hover and acts like a link.
Label {
    id: l
    signal clicked()
    elide: Text.ElideRight
    color: hh.hovered ? Theme.text : Theme.dim
    font.pixelSize: 13
    font.underline: hh.hovered

    HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: l.clicked() }
}
