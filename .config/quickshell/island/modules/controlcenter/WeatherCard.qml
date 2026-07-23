import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Weather card for the Control Center: condition emoji + temperature
// up front, humidity and wind as secondary readouts on the right.
StyledRect {
    implicitHeight: 92
    radius: 20
    color: Colors.surface
    border.width: 1
    border.color: Colors.border

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 14

        StyledText {
            visible: Weather.ready
            text: Weather.emoji
            font.pixelSize: 36
        }
        MaterialIcon {
            visible: !Weather.ready
            text: "cloud"
            font.pixelSize: 34
            color: Colors.subtext
        }

        Column {
            Layout.fillWidth: true
            spacing: 2

            MonoText {
                text: Weather.temp
                font.pixelSize: 26
                font.weight: 700
            }
            StyledText {
                width: parent.width
                text: Weather.ready ? Weather.condition : "Fetching weather…"
                elide: Text.ElideRight
                font.pixelSize: 13
                color: Colors.subtext
            }
        }

        Column {
            visible: Weather.ready
            spacing: 6

            Row {
                anchors.right: parent.right
                spacing: 6

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "humidity_percentage"
                    font.pixelSize: 15
                    color: Colors.accent
                }
                MonoText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.humidity
                    font.pixelSize: 12
                    color: Colors.subtext
                }
            }

            Row {
                anchors.right: parent.right
                spacing: 6

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "air"
                    font.pixelSize: 15
                    color: Colors.accent
                }
                MonoText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.wind
                    font.pixelSize: 12
                    color: Colors.subtext
                }
            }
        }
    }
}
