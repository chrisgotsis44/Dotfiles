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
            font.pixelSize: Appearance.font.px(16)
            font.weight: 700
        }

        IconButton {
            id: refreshButton
            visible: root.refreshable
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: "refresh"
            size: 34
            iconSize: 18
            onClicked: root.refresh()

            // Gentle spin while a scan is in flight. Referencing
            // refreshButton directly rather than this animation's own
            // implicit `target` -- the implicit target can resolve to
            // null by the time onStopped runs (observed as a "Value is
            // null" TypeError once Bluetooth's page started driving
            // `busy` for real), so onStopped had nothing to reset the
            // rotation on and the icon was left stuck mid-spin.
            RotationAnimation on rotation {
                running: root.busy
                from: 0
                to: 360
                duration: 1200
                loops: Animation.Infinite
                onStopped: refreshButton.rotation = 0
            }
        }
    }

    ListView {
        id: list
        width: parent.width
        height: 380
        clip: true
        spacing: 6

        // The model here is a plain JS array (Network.networks /
        // Bluetooth.devices), reassigned wholesale on every refresh --
        // ListView can't diff that into per-item moves the way a real
        // ListModel could, so a re-sort (e.g. the just-connected network
        // jumping to the top) still shows up as fresh delegates rather
        // than existing ones sliding into place. `add`/`displaced` still
        // give that refresh a soft fade + settle instead of a hard snap.
        add: Transition {
            NumberAnimation {
                properties: "opacity"
                from: 0
                to: 1
                duration: Appearance.anim.durations.normal
            }
            NumberAnimation {
                properties: "y"
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
        displaced: Transition {
            NumberAnimation {
                properties: "y"
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
        remove: Transition {
            NumberAnimation {
                properties: "opacity"
                to: 0
                duration: Appearance.anim.durations.fast
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: list.count === 0
            text: root.busy ? "Scanning…" : "Nothing found"
            font.pixelSize: Appearance.font.px(14)
            color: Colors.faint
        }
    }
}
