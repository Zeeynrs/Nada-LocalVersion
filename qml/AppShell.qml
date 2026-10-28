import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: shell
    objectName: "shell"
    property bool immersive: false
    signal enterMini()

    function navigate(kind, itemId) {
        const key = kind + ":" + itemId
        const cur = stack.currentItem ? stack.currentItem.pageKey : ""
        immersive = false
        if (kind === "home") {
            stack.pop(null)
            return
        }
        if (cur === key || cur === kind || !kind || (kind !== "liked" && kind !== "search" && kind !== "settings" && kind !== "folders" && !itemId))
            return
        if (kind === "playlist" || kind === "album" || kind === "liked")
            stack.push(collectionComp, { kind: kind, itemId: itemId })
        else if (kind === "artist")
            stack.push(artistComp, { itemId: itemId })
        else if (kind === "folders")
            stack.push(foldersComp)
        else if (kind === "search")
            stack.push(searchComp)
        else if (kind === "settings")
            stack.push(settingsComp)
    }

    Connections {
        target: Nav
        function onOpen(kind, itemId) { shell.navigate(kind, itemId) }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Sidebar {
                Layout.fillHeight: true
                Layout.preferredWidth: shell.width > 1100 ? 270 : 230
                currentKey: stack.currentItem ? stack.currentItem.pageKey : ""
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 10
                Layout.rightMargin: 10
                radius: 24
                color: Theme.surface
                clip: true

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 320
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.alpha(Theme.accent, 0.16) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }

                StackView {
                    id: stack
                    anchors.fill: parent
                    initialItem: HomePage {}

                    pushEnter: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220 }
                            NumberAnimation { property: "y"; from: 24; to: 0; duration: 280; easing.type: Easing.OutCubic }
                        }
                    }
                    pushExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 160 } }
                    popEnter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220 } }
                    popExit: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 160 }
                            NumberAnimation { property: "y"; from: 0; to: 24; duration: 200 }
                        }
                    }
                }

                IconButton {
                    x: 14; y: 10
                    visible: stack.depth > 1
                    iconName: "back"
                    tip: "Kembali (Alt+←)"
                    onClicked: stack.pop()
                }
            }
        }

        PlayerBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 96
            onOpenImmersive: shell.immersive = true
            onOpenMini: shell.enterMini()
        }
    }

    TapHandler {
        acceptedButtons: Qt.BackButton
        onTapped: if (stack.depth > 1) stack.pop()
    }

    ImmersivePlayer {
        id: immersivePlayer
        width: shell.width
        height: shell.height
        open: shell.immersive
        onClose: shell.immersive = false
    }

    Binding {
        target: visualizer
        property: "active"
        value: shell.immersive && session.visualizerEnabled && shell.Window.visibility !== Window.Minimized
    }

    Component { id: collectionComp; CollectionPage {} }
    Component { id: artistComp; ArtistPage {} }
    Component { id: foldersComp; FoldersPage {} }
    Component { id: searchComp; SearchPage {} }
    Component { id: settingsComp; SettingsPage {} }

    Shortcut { sequence: "Space"; onActivated: player.togglePlay() }
    Shortcut { sequence: "Ctrl+Right"; onActivated: player.next() }
    Shortcut { sequence: "Ctrl+Left"; onActivated: player.previous() }
    Shortcut { sequence: "Ctrl+Up"; onActivated: player.setVolume(Math.min(100, (player.state.volume || 0) + 5)) }
    Shortcut { sequence: "Ctrl+Down"; onActivated: player.setVolume(Math.max(0, (player.state.volume || 0) - 5)) }
    Shortcut { sequence: "Ctrl+F"; onActivated: Nav.go("search") }
    Shortcut { sequence: "Ctrl+R"; onActivated: library.refreshAll() }
    Shortcut { sequence: "Ctrl+L"; onActivated: shell.immersive = !shell.immersive }
    Shortcut { sequence: "Ctrl+,"; onActivated: Nav.go("settings") }
    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "Alt+Left"; onActivated: if (stack.depth > 1) stack.pop() }
    Shortcut {
        sequence: "Escape"
        onActivated: shell.immersive ? shell.immersive = false : (stack.depth > 1 ? stack.pop() : null)
    }
}
