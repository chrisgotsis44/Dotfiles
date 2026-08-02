import QtQuick
import qs.components
import qs.config
import qs.services

// The whole lockscreen composition, deliberately independent of the
// session-lock protocol: shell.qml wraps this in a WlSessionLock, but it
// renders identically inside a plain PanelWindow, which is what makes the
// look testable without ever locking the machine.
//
// One of these exists per monitor. All shared state lives in Lock.
Item {
    id: root

    property bool entered: false

    // Entrance stage. Each element joins on its own beat rather than the
    // whole screen arriving at once -- and because the sequence is
    // re-runnable, waking from idle replays the same reveal instead of
    // snapping everything back together.
    property int stage: 0

    // Pointer parallax, in pixels, handed to the background.
    property real parallaxX: 0
    property real parallaxY: 0

    focus: true

    // The whole surface dissolves on unlock, blur and all.
    //
    // It used to run the entrance backwards instead -- blur and dim easing
    // to zero so the wallpaper sharpened before the surface went. That
    // looked good in principle but exposed the trick: the source image is
    // decoded at 512px wide precisely BECAUSE it is always blurred, so
    // un-blurring it put a visibly soft, low-resolution wallpaper on screen
    // for the last half second of every unlock. Keeping the blur to the end
    // means the only thing that changes is opacity, and the real desktop
    // wallpaper is what comes through.
    opacity: Lock.unlocking ? 0 : 1

    Behavior on opacity {
        NumberAnimation {
            duration: 380
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.curves.standard
        }
    }

    Keys.onPressed: event => {
        Lock.handleKey(event.key, event.text, event.modifiers);
        event.accepted = true;
    }

    LockBackground {
        anchors.fill: parent
        active: root.entered
        dimmed: Lock.idle
        parallaxX: root.parallaxX
        parallaxY: root.parallaxY
    }

    Item {
        id: foreground

        anchors.fill: parent
        // Pulls very slightly towards the viewer as it goes, so the unlock
        // reads as the screen lifting away rather than just switching off.
        scale: Lock.unlocking ? 1.04 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.durations.expand
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }

        // Alone in the top-left, full weekday and month spelled out --
        // there is nothing else up there competing for the space, so the
        // abbreviated form would just look clipped.
        StyledText {
            id: dateLabel

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 72
            anchors.topMargin: 58
            text: Qt.formatDateTime(Time.now, "dddd, d MMMM")
            font.pixelSize: 19
            color: Colors.subtext
            opacity: root.stage >= 2 && !Lock.idle ? 1 : 0

            transform: Translate {
                x: dateLabel.opacity > 0 ? 0 : -14

                Behavior on x {
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
                }
            }
        }

        LockClock {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.42) - height / 2
            digitSize: Math.round(parent.height * 0.155)
            shown: root.stage >= 1
            // Stays through idle -- dimmed, but never gone. It is the one
            // thing worth reading from across the room.
            dimmed: Lock.idle
        }

        LockInput {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.74)
            shown: root.stage >= 3 && !Lock.idle
        }

        LockStatus {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 72
            anchors.rightMargin: 72
            anchors.bottomMargin: 46
            shown: root.stage >= 4 && !Lock.idle
        }
    }

    // Pointer motion counts as activity, and also drives the background
    // parallax. NoButton so it only ever observes -- there is nothing on
    // the lockscreen to click.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true

        onPositionChanged: mouse => {
            Lock.noteActivity();
            if (root.width <= 0 || root.height <= 0)
                return;
            // Inverted: the background leans away from the cursor, which
            // is what reads as depth rather than as the image being dragged.
            root.parallaxX = (mouse.x / root.width - 0.5) * -16;
            root.parallaxY = (mouse.y / root.height - 0.5) * -11;
        }
    }

    SequentialAnimation {
        id: entrance

        ScriptAction {
            script: root.stage = 1
        }
        PauseAnimation {
            duration: 150
        }
        ScriptAction {
            script: root.stage = 2
        }
        PauseAnimation {
            duration: 90
        }
        ScriptAction {
            script: root.stage = 3
        }
        PauseAnimation {
            duration: 90
        }
        ScriptAction {
            script: root.stage = 4
        }
    }

    Connections {
        target: Lock

        function onIdleChanged(): void {
            if (!Lock.idle && root.entered)
                entrance.restart();
        }
    }

    Component.onCompleted: {
        root.forceActiveFocus();
        // One tick late, or `entered` would be true at first render and
        // the entrance would have nothing to animate from.
        Qt.callLater(() => {
            root.entered = true;
            entrance.start();
        });
    }
}
