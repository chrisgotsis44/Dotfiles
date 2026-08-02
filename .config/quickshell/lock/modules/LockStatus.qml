import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// The bottom edge: what's playing on the left, machine status on the
// right. Both are pushed to the corners and kept small on purpose -- they
// are reference information, and anything louder would compete with the
// clock for the one focal point the screen is allowed.
Item {
    id: root

    property bool shown: false

    implicitHeight: Math.max(nowPlaying.implicitHeight, chips.implicitHeight)

    opacity: root.shown ? 1 : 0

    transform: Translate {
        y: root.shown ? 0 : 14

        Behavior on y {
            NumberAnimation {
                duration: Appearance.anim.durations.expand
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.anim.durations.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.curves.standard
        }
    }

    RowLayout {
        id: nowPlaying

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        // Nothing playing means nothing here -- no placeholder row.
        visible: NowPlaying.isPlaying
        opacity: NowPlaying.isPlaying ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.durations.normal
            }
        }

        ClippingRectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 42
            implicitHeight: 42
            radius: 10
            color: Colors.surfaceHigh

            Image {
                anchors.fill: parent
                source: NowPlaying.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 84
                sourceSize.height: 84
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            StyledText {
                Layout.maximumWidth: 260
                text: NowPlaying.title
                font.pixelSize: 14
                font.weight: 600
                elide: Text.ElideRight
            }

            StyledText {
                Layout.maximumWidth: 260
                text: NowPlaying.artist
                font.pixelSize: 12
                color: Colors.subtext
                elide: Text.ElideRight
                visible: NowPlaying.artist !== ""
            }
        }
    }

    RowLayout {
        id: chips

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: "keyboard_capslock"
            font.pixelSize: 19
            color: Colors.danger
            visible: Lock.capsLock
        }

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: NetStatus.icon
            font.pixelSize: 19
            color: Colors.subtext
            visible: NetStatus.ready
        }

        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 5
            visible: Battery.available

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                text: Battery.icon
                font.pixelSize: 19
                color: Battery.percent <= 15 && !Battery.charging ? Colors.danger : Colors.subtext
            }

            MonoText {
                Layout.alignment: Qt.AlignVCenter
                text: `${Battery.percent}%`
                font.pixelSize: 13
                color: Colors.subtext
            }
        }
    }
}
