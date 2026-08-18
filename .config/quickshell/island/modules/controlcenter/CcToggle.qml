import QtQuick
import qs.config
import qs.components

// One Control Center toggle: icon badge + label + live status line.
// Active state lights the badge in the seafoam accent.
//
// Left-click toggles; right-click (on tiles with hasDetail) opens the
// setting's detail list view.
StyledRect {
    id: root

    property string icon
    property string label
    property string sub
    property bool active: false
    property bool hasDetail: false
    // Small overlay icon on the corner of the icon badge, e.g. an
    // ethernet glyph on the Wi-Fi tile when a wired connection is also
    // up. Empty string hides it.
    property string badgeIcon: ""

    signal toggled()
    signal rightClicked()

    implicitHeight: 68
    radius: 20
    color: mouse.pressed ? Colors.surfacePressed
         : mouse.containsMouse ? Colors.surfaceHover
         : Colors.surface

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 42
            radius: 21
            color: root.active ? Colors.accent : Colors.surfaceHigh

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.durations.fast
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: root.icon
                font.pixelSize: Appearance.font.px(21)
                color: root.active ? Colors.accentFg : Colors.subtext
            }

            StyledRect {
                visible: root.badgeIcon !== ""
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -2
                anchors.bottomMargin: -2
                width: 18
                height: 18
                radius: 9
                color: Colors.surface
                border.width: 1.5
                border.color: Colors.bg

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.badgeIcon
                    font.pixelSize: Appearance.font.px(11)
                    color: Colors.accent
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            width: parent.width - 54

            StyledText {
                width: parent.width
                text: root.label
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.px(14)
                font.weight: 600
            }
            StyledText {
                width: parent.width
                text: root.sub
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.px(12)
                color: root.active ? Colors.accent : Colors.subtext
            }
        }
    }

    // Hint that a right-click detail view exists.
    MaterialIcon {
        visible: root.hasDetail
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: "chevron_right"
        font.pixelSize: Appearance.font.px(16)
        color: mouse.containsMouse ? Colors.subtext : Colors.faint
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: e => {
            if (e.button === Qt.RightButton)
                root.rightClicked();
            else
                root.toggled();
        }
    }
}
