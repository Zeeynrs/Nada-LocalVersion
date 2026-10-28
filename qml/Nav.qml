pragma Singleton
import QtQuick

// Global navigation bus: any component can ask the shell to open a page.
QtObject {
    signal open(string kind, string itemId)
    signal immersive(bool on)

    function go(kind, itemId) {
        if (kind)
            open(kind, itemId || "")
    }
}
