import QtQuick
import qs.config
import qs.services
import qs.components

// Compact weather capsule for the hover-expanded island: condition
// emoji + temperature in the mono font.
StyledRect {
    implicitWidth: wxRow.implicitWidth + 26
    implicitHeight: 34
    radius: 17
    color: Colors.surfaceHigh

    Row {
        id: wxRow
        anchors.centerIn: parent
        spacing: 7

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: Weather.ready
            text: Weather.emoji
            font.pixelSize: 14
        }
        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: !Weather.ready
            text: "cloud"
            font.pixelSize: 16
            color: Colors.subtext
        }
        MonoText {
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.temp
            font.pixelSize: 13
            color: Colors.subtext
        }
    }
}
