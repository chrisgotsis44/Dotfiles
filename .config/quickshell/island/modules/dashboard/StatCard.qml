import QtQuick
import qs.config
import qs.components

// Base tile for the Performance grid: surface panel with an icon +
// title header row, content below. Children land in `content`.
StyledRect {
    id: root

    property string icon
    property string title
    default property alias contentData: content.data

    radius: 20
    color: Colors.surface
    border.width: 1
    border.color: Colors.border

    implicitHeight: header.height + content.childrenRect.height + 16 + 10 + 16

    Row {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 16
        anchors.leftMargin: 16
        spacing: 8
        height: 22

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            font.pixelSize: Appearance.font.px(18)
            color: Colors.accent
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            font.pixelSize: Appearance.font.px(13)
            font.weight: 700
            color: Colors.subtext
        }
    }

    Item {
        id: content
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 10
        anchors.leftMargin: 16
        anchors.rightMargin: 16
    }
}
