import QtQuick
import QtQuick.Controls

Row {
    id: vc
    property real sliderWidth: 110
    property int lastVolume: 50
    readonly property var s: player.state
    readonly property int volume: s.volume !== undefined && s.volume >= 0 ? s.volume : 0
    spacing: 4
    enabled: s.hasTrack === true && s.supportsVolume !== false

    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        iconName: vc.volume === 0 ? "volume-off" : "volume"
        tip: "Bisukan"
        onClicked: {
            if (vc.volume > 0) {
                vc.lastVolume = vc.volume
                player.setVolume(0)
            } else {
                player.setVolume(vc.lastVolume || 50)
            }
        }
    }
    NSlider {
        anchors.verticalCenter: parent.verticalCenter
        width: vc.sliderWidth
        from: 0; to: 100
        value: vc.volume
        onMoved: player.setVolume(Math.round(value))
        WheelHandler {
            onWheel: (event) => player.setVolume(Math.max(0, Math.min(100, vc.volume + (event.angleDelta.y > 0 ? 5 : -5))))
        }
    }
}
