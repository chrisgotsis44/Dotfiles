import QtQuick
import qs.config
import qs.services
import qs.components

// Compact weather readout for the hover-expanded island: condition
// emoji + temperature, no pill/background container -- unadorned like
// the battery module it sits beside (see Bar.qml's hoverSection).
Row {
    spacing: 6

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        visible: Weather.ready
        text: Weather.emoji
        font.pixelSize: Appearance.font.px(14)
    }
    MaterialIcon {
        anchors.verticalCenter: parent.verticalCenter
        visible: !Weather.ready
        text: "cloud"
        font.pixelSize: Appearance.font.px(17)
        color: Colors.text
    }
    MonoText {
        anchors.verticalCenter: parent.verticalCenter
        text: Weather.temp
        font.pixelSize: Appearance.font.px(12)
        font.weight: 600
        color: Colors.subtext
    }
}
