import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    readonly property string pageKey: "folders"
    readonly property var fv: library.folderView

    Component.onCompleted: library.browseFolder(fv.currentPath || "")

    Connections {
        target: library
        function onTagsUpdated() { library.browseFolder(page.fv.currentPath || "") }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight + 56
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: NScrollBar {}

        ColumnLayout {
            id: col
            x: 24
            y: 52
            width: flick.width - 48
            spacing: 18

            // Header & Breadcrumb bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                IconButton {
                    visible: !!page.fv.canGoUp
                    iconName: "back"
                    size: 20
                    tip: "Naik ke folder induk"
                    onClicked: library.browseFolder(page.fv.parentPath || "")
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label {
                        Layout.fillWidth: true
                        text: page.fv.currentName || "Folder Musik"
                        font.pixelSize: 32
                        font.weight: Font.Black
                        elide: Text.ElideRight
                    }
                    Label {
                        visible: !!page.fv.currentPath
                        Layout.fillWidth: true
                        text: page.fv.currentPath || ""
                        font.family: Theme.mono
                        font.pixelSize: 12
                        color: Theme.dim
                        elide: Text.ElideMiddle
                    }
                }

                NButton {
                    visible: (page.fv.totalRecursive || 0) > 0
                    text: "Putar Semua (" + (page.fv.totalRecursive || 0) + ")"
                    iconName: "play"
                    primary: true
                    onClicked: player.playContext(page.fv.playUri, "")
                }
                NButton {
                    visible: (page.fv.totalRecursive || 0) > 1
                    text: "Acak"
                    iconName: "shuffle"
                    onClicked: player.shufflePlay(page.fv.playUri)
                }
            }

            // Subfolders Section
            ColumnLayout {
                Layout.fillWidth: true
                visible: (page.fv.folders || []).length > 0
                spacing: 6

                Label {
                    text: "Subfolder (" + (page.fv.folders || []).length + ")"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    Layout.leftMargin: 8
                }

                Repeater {
                    model: page.fv.folders || []
                    Rectangle {
                        id: fCard
                        Layout.fillWidth: true
                        implicitHeight: 62
                        radius: 14
                        color: fHover.hovered ? Theme.alpha(Theme.text, 0.08) : Theme.alpha(Theme.text, 0.04)
                        Behavior on color { ColorAnimation { duration: 120 } }

                        HoverHandler { id: fHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: library.browseFolder(modelData.path) }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 14
                            spacing: 14

                            Cover {
                                Layout.preferredWidth: 44
                                Layout.preferredHeight: 44
                                radius: 10
                                source: modelData.image || ""
                                fallbackIcon: "library"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Label {
                                    Layout.fillWidth: true
                                    text: modelData.name || ""
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: modelData.subtitle || ""
                                    font.pixelSize: 12
                                    color: Theme.dim
                                    elide: Text.ElideRight
                                }
                            }

                            IconButton {
                                visible: (modelData.trackCount || 0) > 0
                                iconName: "play"
                                filled: true
                                size: 18
                                tip: "Putar folder ini"
                                onClicked: player.playContext(modelData.uri, "")
                            }
                        }
                    }
                }
            }

            // Tracks inside current folder
            ColumnLayout {
                Layout.fillWidth: true
                visible: (page.fv.tracks || []).length > 0
                spacing: 2

                Label {
                    text: "Berkas Audio di Folder Ini (" + (page.fv.tracks || []).length + ")"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    Layout.leftMargin: 8
                    Layout.bottomMargin: 4
                }

                Repeater {
                    model: page.fv.tracks || []
                    TrackRow {
                        Layout.fillWidth: true
                        track: modelData
                        number: index + 1
                        onPlay: player.playUris((page.fv.tracks || []).map(x => x.uri), index)
                    }
                }
            }

            Label {
                visible: (page.fv.folders || []).length === 0 && (page.fv.tracks || []).length === 0
                text: "Folder ini tidak memiliki berkas audio yang terindeks."
                color: Theme.dim
                font.pixelSize: 15
                Layout.leftMargin: 8
                Layout.topMargin: 16
            }
        }
    }
}
