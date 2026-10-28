import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: win
    width: 1280
    height: 800
    minimumWidth: 900
    minimumHeight: 600
    visible: true
    title: player.state.hasTrack ? player.state.name + " • " + player.state.artists + " — Nada Local" : "Nada Local"
    color: Theme.bg

    palette {
        window: Theme.bg
        windowText: Theme.text
        text: Theme.text
        base: Theme.surface2
        alternateBase: Theme.surface3
        button: Theme.surface2
        buttonText: Theme.text
        highlight: Theme.accent
        highlightedText: Theme.accentText
        placeholderText: Theme.faint
        toolTipBase: Theme.surface3
        toolTipText: Theme.text
        light: Theme.surface3
        midlight: Theme.surface3
        mid: Theme.surface2
        dark: Theme.surface
        shadow: "#000000"
    }

    property color liveAccent: player.accent
    Behavior on liveAccent { ColorAnimation { duration: 900; easing.type: Easing.InOutQuad } }
    Binding { target: Theme; property: "accent"; value: win.liveAccent }

    onActiveChanged: player.setFastPolling(active)

    AppShell {
        anchors.fill: parent
    }

    // Drag & drop local audio files directly into the window
    DropArea {
        anchors.fill: parent
        onDropped: (drop) => {
            if (drop.hasUrls && drop.urls.length > 0) {
                player.playFiles(drop.urls)
            }
        }
    }

    Connections {
        target: session
        function onToast(msg) { toast.show(msg) }
    }
    Toast { id: toast }
}
