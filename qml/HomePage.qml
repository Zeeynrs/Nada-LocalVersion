import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    readonly property string pageKey: "home"
    readonly property var home: library.home

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight + 48
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: NScrollBar {}

        Column {
            id: col
            x: 20
            y: 52
            width: flick.width - 40
            spacing: 28

            RowLayout {
                width: parent.width
                Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    text: Theme.greeting() + (library.me.name ? ", " + library.me.name.split(" ")[0] : "")
                    font.pixelSize: 36
                    font.weight: Font.Black
                    elide: Text.ElideRight
                }
                NButton {
                    text: library.scanning ? "Memindai…" : "Pindai Musik"
                    iconName: "refresh"
                    enabled: !library.scanning
                    onClicked: library.refreshAll()
                }
            }

            // Empty state banner when no music is in ~/Music yet
            Rectangle {
                width: parent.width
                visible: (library.stats.tracks || 0) === 0 && !library.scanning
                implicitHeight: emptyCol.implicitHeight + 48
                radius: 20
                color: Theme.alpha(Theme.accent, 0.08)
                border.width: 1
                border.color: Theme.alpha(Theme.accent, 0.25)

                ColumnLayout {
                    id: emptyCol
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 10
                    Label {
                        text: "Pustaka Musik Lokal Masih Kosong"
                        font.pixelSize: 20
                        font.weight: Font.Bold
                    }
                    Label {
                        Layout.fillWidth: true
                        text: "Letakkan file audio (FLAC, MP3, OPUS, WAV, M4A) di ~/Music, seret file langsung ke jendela ini, atau tambahkan folder musik lain di halaman Pengaturan."
                        color: Theme.dim
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                    }
                    RowLayout {
                        spacing: 10
                        Layout.topMargin: 4
                        NButton {
                            text: "Atur Folder Musik"
                            primary: true
                            onClicked: Nav.go("settings")
                        }
                        NButton {
                            text: "Pindai Ulang"
                            iconName: "refresh"
                            onClicked: library.refreshAll()
                        }
                    }
                }
            }

            // Quick tiles
            GridLayout {
                width: parent.width
                columns: width > 900 ? 4 : 2
                columnSpacing: 10
                rowSpacing: 10
                visible: library.playlists.length > 0
                Repeater {
                    model: [{ kind: "liked", id: "", name: "Lagu yang Disukai", imageSmall: "" }].concat(library.playlists.slice(0, 7))
                    AbstractButton {
                        id: tile
                        Layout.fillWidth: true
                        implicitHeight: 64
                        hoverEnabled: true
                        focusPolicy: Qt.NoFocus
                        onClicked: Nav.go(modelData.kind, modelData.id)
                        background: Rectangle {
                            radius: 14
                            color: tile.hovered ? Theme.alpha(Theme.text, 0.12) : Theme.alpha(Theme.text, 0.06)
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }
                        contentItem: RowLayout {
                            spacing: 12
                            Cover {
                                Layout.preferredWidth: 64
                                Layout.preferredHeight: 64
                                radius: 14
                                source: modelData.imageSmall || ""
                                fallbackIcon: modelData.kind === "liked" ? "heart" : "note"
                            }
                            Label {
                                Layout.fillWidth: true
                                text: modelData.name
                                elide: Text.ElideRight
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }

            CardGrid { width: parent.width; title: "Album di Koleksimu"; items: page.home.recent || []; rows: 1 }

            Column {
                width: parent.width
                visible: (page.home.topTracks || []).length > 0
                spacing: 4
                Label {
                    text: "Lagu di Pustaka Lokal"
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    leftPadding: 12
                    bottomPadding: 6
                }
                Repeater {
                    model: (page.home.topTracks || []).slice(0, 8)
                    TrackRow {
                        width: col.width
                        track: modelData
                        number: index + 1
                        onPlay: player.playUris(page.home.topTracks.map(x => x.uri), index)
                    }
                }
            }

            CardGrid { width: parent.width; title: "Artis Lokal"; items: page.home.topArtists || []; rows: 1 }
            CardGrid { width: parent.width; title: "Playlist Lokal"; items: library.playlists; rows: 2 }
        }
    }
}
