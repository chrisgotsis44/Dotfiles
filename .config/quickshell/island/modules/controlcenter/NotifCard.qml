import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.config
import qs.components

// One row in the Control Center's notification list.
StyledRect {
    id: root

    required property Notification notif

    implicitHeight: content.implicitHeight + 24
    radius: 16
    color: hover.hovered ? Colors.surfaceHover : Colors.surface

    Row {
        id: content
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 38
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        IconImage {
            anchors.top: parent.top
            implicitSize: 30
            source: {
                if (root.notif.image)
                    return root.notif.image;
                return Quickshell.iconPath(root.notif.appIcon || "dialog-information", "dialog-information");
            }
        }

        Column {
            width: parent.width - 36
            spacing: 2

            StyledText {
                width: parent.width
                text: root.notif.appName || "Notification"
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.px(11)
                font.weight: 600
                font.capitalization: Font.AllUppercase
                color: Colors.faint
            }
            StyledText {
                width: parent.width
                text: root.notif.summary
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.px(14)
                font.weight: 600
            }
            StyledText {
                width: parent.width
                visible: text !== ""
                text: root.notif.body
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
                textFormat: Text.StyledText
                font.pixelSize: Appearance.font.px(13)
                color: Colors.subtext
            }
        }
    }

    MaterialIcon {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 12
        text: "close"
        font.pixelSize: Appearance.font.px(16)
        color: closeHover.hovered ? Colors.danger : Colors.faint
        opacity: hover.hovered ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.durations.fast
            }
        }

        HoverHandler {
            id: closeHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: root.notif.dismiss()
        }
    }

    HoverHandler {
        id: hover
    }
}
