import QtQuick
import qs.components
import qs.config

// A display-size number that rolls when it changes: the outgoing value
// rises out of the frame while the incoming one comes up from below.
//
// Two labels rather than one, because `onValueChanged` cannot see the
// value it replaced -- `shown` holds what is currently rendered, and the
// swap is what drives the animation.
Item {
    id: root

    property string value: ""
    property int pixelSize: 168
    property color textColor: "white"
    // Forced equal across rows by the caller: digits are proportional, so
    // "16" and "40" are never naturally the same width.
    property real rowWidth: 0

    // What is actually on screen right now.
    property string shown: ""

    // Kept short deliberately. The negative leading in LockClock makes the
    // two rows' boxes OVERLAP by ~60px, so clipping to this item's own
    // bounds cannot stop a departing numeral from straying over the row
    // above it -- the fade has to do that work instead, which is why the
    // opacity animations below finish well before the movement does.
    readonly property real travel: root.implicitHeight * 0.32

    implicitWidth: root.rowWidth > 0 ? root.rowWidth : live.implicitWidth
    implicitHeight: live.implicitHeight

    // The outgoing number has to be masked as it leaves, or it just floats
    // away over the wallpaper.
    clip: true

    onValueChanged: {
        if (root.shown === "" || root.shown === root.value) {
            // First paint, or no real change -- nothing to roll.
            root.shown = root.value;
            return;
        }
        ghost.text = root.shown;
        root.shown = root.value;
        roll.restart();
    }

    Component.onCompleted: root.shown = root.value

    StyledText {
        id: live
        width: root.width
        horizontalAlignment: Text.AlignHCenter
        text: root.shown
        font.family: Appearance.font.family
        font.pixelSize: root.pixelSize
        font.weight: Font.Black
        color: root.textColor
    }

    StyledText {
        id: ghost
        width: root.width
        horizontalAlignment: Text.AlignHCenter
        font.family: Appearance.font.family
        font.pixelSize: root.pixelSize
        font.weight: Font.Black
        color: root.textColor
        opacity: 0
    }

    ParallelAnimation {
        id: roll

        NumberAnimation {
            target: ghost
            property: "y"
            from: 0
            to: -root.travel
            duration: 520
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.curves.emphasized
        }
        NumberAnimation {
            target: ghost
            property: "opacity"
            from: 1
            to: 0
            duration: 230
        }
        NumberAnimation {
            target: live
            property: "y"
            from: root.travel
            to: 0
            duration: 520
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.curves.emphasized
        }
        NumberAnimation {
            target: live
            property: "opacity"
            from: 0
            to: 1
            duration: 300
        }
    }
}
