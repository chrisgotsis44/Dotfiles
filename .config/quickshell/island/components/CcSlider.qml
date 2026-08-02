import QtQuick
import Quickshell.Widgets
import qs.config

// iOS-style capsule slider: dark track, off-white fill, glyph pinned
// left. Unidirectional data flow — the slider never owns the value:
//   value:  bind to the source of truth (Audio.volume, ...)
//   moved:  fire the mutation (Audio.setVolume, ...)
// While dragging we show the local drag value so a laggy backend
// (e.g. debounced brightnessctl) can't make the thumb rubber-band.
Item {
    id: root

    property real value: 0
    property string icon: ""

    signal moved(real newValue)

    implicitWidth: 240
    implicitHeight: 46

    readonly property real shown: mouse.pressed ? mouse.dragValue : value

    StyledRect {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Colors.sliderTrack

        ClippingRectangle {
            anchors.fill: parent
            radius: track.radius
            color: "transparent"

            Rectangle {
                width: root.shown * parent.width
                height: parent.height
                // Same accent as the active Control Center toggles
                // (CcToggle's badge, ToggleSwitch's track) -- one accent
                // color for every "this is on / this is the current
                // value" surface in the Control Center.
                color: Colors.accent

                Behavior on width {
                    enabled: !mouse.pressed
                    NumberAnimation {
                        duration: Appearance.anim.durations.fast
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }
            }
        }

        MaterialIcon {
            visible: root.icon !== ""
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            font.pixelSize: Math.min(21, root.height * 0.55)
            color: Colors.sliderIcon
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        property real dragValue: 0

        function update(x: real) {
            dragValue = Math.max(0, Math.min(1, x / width));
            root.moved(dragValue);
        }

        onPressed: e => update(e.x)
        onPositionChanged: e => {
            if (pressed)
                update(e.x);
        }
        onWheel: w => {
            const step = w.angleDelta.y > 0 ? 0.05 : -0.05;
            root.moved(Math.max(0, Math.min(1, root.value + step)));
        }
    }
}
