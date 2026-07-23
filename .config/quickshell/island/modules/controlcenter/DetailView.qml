import QtQuick
import qs.config
import qs.components

// Generic Control Center detail page: back header + scrollable list.
// The caller supplies the model and row delegate.
Column {
    id: root

    property string title
    property bool busy: false
    property alias model: list.model
    property alias delegate: list.delegate
    property bool refreshable: true

    signal back()
    signal refresh()

    spacing: 10

    Item {
        width: parent.width
        height: 40

        IconButton {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            icon: "arrow_back"
            size: 34
            iconSize: 18
            onClicked: root.back()
        }

        StyledText {
            anchors.centerIn: parent
            text: root.title
            font.pixelSize: 16
            font.weight: 700
        }

        IconButton {
            visible: root.refreshable
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: "refresh"
            size: 34
            iconSize: 18
            onClicked: root.refresh()

            // Gentle spin while a scan is in flight.
            RotationAnimation on rotation {
                running: root.busy
                from: 0
                to: 360
                duration: 1200
                loops: Animation.Infinite
                onStopped: target.rotation = 0
            }
        }
    }

    ListView {
        id: list
        width: parent.width
        height: 380
        clip: true
        spacing: 6

        StyledText {
            anchors.centerIn: parent
            visible: list.count === 0
            text: root.busy ? "Scanning…" : "Nothing found"
            font.pixelSize: 14
            color: Colors.faint
        }
    }
}
