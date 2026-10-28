pragma Singleton
import QtQuick

// Global navigation bus: any component can ask the shell to open a page.
QtObject {
    signal open(string kind, string itemId)
    signal immersive(bool on)
    signal editTag(var track)

    function go(kind, itemId) {
        if (kind)
            open(kind, itemId || "")
    }

    function openTagEditor(track) {
        if (track && track.uri)
            editTag(track)
    }
}
