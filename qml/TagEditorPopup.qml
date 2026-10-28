import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: pop
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: 480
    padding: 24
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property var targetTrack: ({})

    function openForTrack(track) {
        if (!track || !track.uri) return
        targetTrack = track
        titleField.text = track.name || ""
        artistField.text = track.artists || ""
        albumField.text = track.album || ""
        yearField.text = track.year || ""
        trackNumField.text = track.trackNum > 0 ? String(track.trackNum) : ""
        open()
        titleField.forceActiveFocus()
    }

    function saveTags() {
        if (!targetTrack || !targetTrack.uri) return
        const tNum = parseInt(trackNumField.text.trim()) || 0
        library.updateTrackTags(
            targetTrack.uri,
            titleField.text.trim(),
            artistField.text.trim(),
            albumField.text.trim(),
            yearField.text.trim(),
            tNum
        )
        close()
    }

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.58)
    }

    background: Rectangle {
        radius: 22
        color: Theme.surface3
        border.width: 1
        border.color: Theme.alpha(Theme.text, 0.12)
    }

    contentItem: ColumnLayout {
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Cover {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
                source: pop.targetTrack.imageSmall || ""
                simple: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label {
                    text: "Edit Tag Metadata"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }
                Label {
                    Layout.fillWidth: true
                    text: pop.targetTrack.path || pop.targetTrack.uri || ""
                    color: Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                }
            }

            IconButton {
                iconName: "close"
                size: 16
                onClicked: pop.close()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Label { text: "Judul Lagu"; color: Theme.dim; font.pixelSize: 12; font.weight: Font.DemiBold }
                NTextField {
                    id: titleField
                    Layout.fillWidth: true
                    placeholderText: "Judul lagu…"
                    onAccepted: pop.saveTags()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Label { text: "Artis"; color: Theme.dim; font.pixelSize: 12; font.weight: Font.DemiBold }
                NTextField {
                    id: artistField
                    Layout.fillWidth: true
                    placeholderText: "Nama artis…"
                    onAccepted: pop.saveTags()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Label { text: "Album"; color: Theme.dim; font.pixelSize: 12; font.weight: Font.DemiBold }
                NTextField {
                    id: albumField
                    Layout.fillWidth: true
                    placeholderText: "Nama album…"
                    onAccepted: pop.saveTags()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Label { text: "Tahun Rilis"; color: Theme.dim; font.pixelSize: 12; font.weight: Font.DemiBold }
                    NTextField {
                        id: yearField
                        Layout.fillWidth: true
                        placeholderText: "2024"
                        onAccepted: pop.saveTags()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Label { text: "Nomor Track"; color: Theme.dim; font.pixelSize: 12; font.weight: Font.DemiBold }
                    NTextField {
                        id: trackNumField
                        Layout.fillWidth: true
                        placeholderText: "1"
                        onAccepted: pop.saveTags()
                    }
                }
            }
        }

        Label {
            Layout.fillWidth: true
            text: (pop.targetTrack.uri || "").startsWith("cue://")
                  ? "Track CUE Sheet: perubahan disimpan ke database pustaka lokal."
                  : "Perubahan ditulis langsung ke tag fisik file audio & database pustaka."
            color: Theme.faint
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 10
            Item { Layout.fillWidth: true }
            NButton {
                text: "Batal"
                onClicked: pop.close()
            }
            NButton {
                text: "Simpan Tag"
                primary: true
                onClicked: pop.saveTags()
            }
        }
    }
}
