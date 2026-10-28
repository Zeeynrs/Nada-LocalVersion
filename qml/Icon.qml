import QtQuick
import QtQuick.Controls.impl

IconImage {
    property string glyph
    property int size: 20

    source: glyph ? Qt.resolvedUrl("icons/" + glyph + ".svg") : ""
    width: size
    height: size
    sourceSize: Qt.size(size * 2, size * 2)
    color: Theme.text
}
