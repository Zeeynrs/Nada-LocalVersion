import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    readonly property string pageKey: "settings"

    component Section: Rectangle {
        default property alias content: inner.data
        property string title
        Layout.fillWidth: true
        Layout.maximumWidth: 760
        implicitHeight: inner.implicitHeight + 48
        radius: 20
        color: Theme.alpha(Theme.text, 0.04)
        ColumnLayout {
            id: inner
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14
            Label { text: parent.parent.title; font.pixelSize: 18; font.weight: Font.Bold }
        }
    }
    component SettingRow: RowLayout {
        property string label
        property string hint
        Layout.fillWidth: true
        spacing: 16
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label { text: parent.parent.label; font.pixelSize: 15 }
            Label {
                visible: text !== ""
                Layout.fillWidth: true
                text: parent.parent.hint
                color: Theme.dim
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight + 80
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: NScrollBar {}

        ColumnLayout {
            id: col
            x: 32
            y: 52
            width: flick.width - 64
            spacing: 18

            Label { text: "Pengaturan"; font.pixelSize: 36; font.weight: Font.Black }

            Section {
                title: "Folder Pustaka Musik"

                Label {
                    Layout.fillWidth: true
                    text: "Nada Local memindai file FLAC, MP3, OPUS, OGG, M4A, WAV, dan playlist M3U dari folder di bawah ini."
                    color: Theme.dim
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: session.musicDirs
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 46
                        radius: 12
                        color: Theme.bg
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 10
                            spacing: 10
                            Icon { glyph: "library"; size: 18; color: Theme.accent }
                            Label {
                                Layout.fillWidth: true
                                text: modelData
                                font.family: Theme.mono
                                font.pixelSize: 13
                                elide: Text.ElideMiddle
                            }
                            NButton {
                                text: "Buka"
                                onClicked: session.openContainingFolder(modelData)
                            }
                            IconButton {
                                visible: session.musicDirs.length > 1
                                iconName: "close"
                                size: 16
                                tip: "Hapus folder ini"
                                onClicked: session.removeMusicDir(modelData)
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    NTextField {
                        id: dirField
                        Layout.fillWidth: true
                        placeholderText: "Tambah path folder musik (contoh: ~/Downloads/Music)…"
                        onAccepted: {
                            if (text.trim()) {
                                session.addMusicDir(text.trim())
                                text = ""
                            }
                        }
                    }
                    NButton {
                        text: "Tambah Folder"
                        primary: true
                        onClicked: {
                            if (dirField.text.trim()) {
                                session.addMusicDir(dirField.text.trim())
                                dirField.text = ""
                            }
                        }
                    }
                    NButton {
                        text: library.scanning ? "Memindai…" : "Pindai Ulang"
                        iconName: "refresh"
                        enabled: !library.scanning
                        onClicked: library.refreshAll()
                    }
                }
            }

            Section {
                title: "Mesin Audio (libmpv)"
                SettingRow {
                    label: "Status Engine"
                    hint: player.mpvAvailable ? "Menggunakan C API libmpv secara langsung untuk pemutaran bit-perfect." : "Pasang paket mpv di distro Linux Anda."
                    Rectangle {
                        implicitWidth: 10; implicitHeight: 10; radius: 5
                        color: player.mpvAvailable ? "#7ee08f" : Theme.danger
                    }
                    Label {
                        text: player.mpvAvailable ? player.mpvVersion : "libmpv belum terpasang"
                        color: Theme.dim
                        font.pixelSize: 14
                    }
                }
                SettingRow {
                    label: "Gapless Playback"
                    hint: "Hilangkan jeda hening saat berpindah antar lagu dalam satu album."
                    ComboBox {
                        id: gaplessBox
                        Layout.preferredWidth: 180
                        textRole: "text"
                        valueRole: "value"
                        model: [
                            { text: "Otomatis (Weak)", value: "weak" },
                            { text: "Paksa Aktif (Yes)", value: "yes" },
                            { text: "Nonaktif", value: "no" }
                        ]
                        Component.onCompleted: currentIndex = Math.max(0, indexOfValue(session.gapless))
                        onActivated: session.gapless = currentValue
                        background: Rectangle {
                            implicitHeight: 40
                            radius: 20
                            color: Theme.alpha(Theme.text, gaplessBox.hovered ? 0.11 : 0.07)
                        }
                        contentItem: Label {
                            leftPadding: 18
                            text: gaplessBox.displayText
                            font.pixelSize: 14
                            verticalAlignment: Text.AlignVCenter
                        }
                        popup.background: Rectangle { color: Theme.surface3; radius: 12 }
                    }
                }
                SettingRow {
                    label: "Normalisasi Volume (ReplayGain)"
                    hint: "Sesuaikan keras suara menggunakan metadata ReplayGain pada file FLAC/MP3."
                    ComboBox {
                        id: rgBox
                        Layout.preferredWidth: 180
                        textRole: "text"
                        valueRole: "value"
                        model: [
                            { text: "Nonaktif", value: "no" },
                            { text: "Per Lagu (Track)", value: "track" },
                            { text: "Per Album", value: "album" }
                        ]
                        Component.onCompleted: currentIndex = Math.max(0, indexOfValue(session.replaygain))
                        onActivated: session.replaygain = currentValue
                        background: Rectangle {
                            implicitHeight: 40
                            radius: 20
                            color: Theme.alpha(Theme.text, rgBox.hovered ? 0.11 : 0.07)
                        }
                        contentItem: Label {
                            leftPadding: 18
                            text: rgBox.displayText
                            font.pixelSize: 14
                            verticalAlignment: Text.AlignVCenter
                        }
                        popup.background: Rectangle { color: Theme.surface3; radius: 12 }
                    }
                }
            }

            Section {
                title: "Lirik & Visualizer"
                SettingRow {
                    label: "Visualizer Spektrum (Cava)"
                    hint: visualizer.available
                          ? "Spektrum lingkaran di sekeliling cover pada tampilan penuh (PipeWire monitor)."
                          : "Pasang paket cava untuk mengaktifkan spektrum frekuensi real-time."
                    Switch {
                        checked: session.visualizerEnabled
                        onToggled: session.visualizerEnabled = checked
                    }
                }
                SettingRow {
                    label: "Fallback Lirik Online (LRCLIB)"
                    hint: "Jika file .lrc lokal atau tag lirik tidak ditemukan, cari otomatis dari database LRCLIB dan simpan di cache lokal."
                    Switch {
                        checked: session.onlineLyrics
                        onToggled: session.onlineLyrics = checked
                    }
                }
            }

            Section {
                title: "Pintasan Keyboard"
                GridLayout {
                    columns: 2
                    columnSpacing: 24
                    rowSpacing: 6
                    Repeater {
                        model: [
                            "Spasi", "Putar / jeda",
                            "Ctrl + → / ←", "Lagu berikutnya / sebelumnya",
                            "Ctrl + ↑ / ↓", "Volume naik / turun",
                            "Ctrl + F", "Cari di pustaka lokal",
                            "Ctrl + R", "Pindai ulang folder musik",
                            "Ctrl + L", "Tampilan penuh + lirik + EQ",
                            "Alt + ← / Esc", "Kembali / tutup tampilan penuh",
                            "Ctrl + ,", "Pengaturan"
                        ]
                        Label {
                            text: modelData
                            font.family: index % 2 === 0 ? Theme.mono : Theme.font
                            font.pixelSize: 13
                            color: index % 2 === 0 ? Theme.accent : Theme.dim
                        }
                    }
                }
            }
        }
    }
}
