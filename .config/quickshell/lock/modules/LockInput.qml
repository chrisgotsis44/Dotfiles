import QtQuick
import qs.components
import qs.config
import qs.services

// The password capsule.
//
// It never takes keyboard focus -- LockSurface grabs every key and routes
// it to Lock.handleKey(), so a multi-monitor setup types into one shared
// buffer instead of whichever surface happens to be focused. This is a
// pure view over Lock.buffer.
Item {
    id: root

    property bool shown: false

    readonly property int capsuleWidth: 340
    readonly property int capsuleHeight: 54

    implicitWidth: capsuleWidth
    implicitHeight: capsuleHeight + 34

    opacity: root.shown ? 1 : 0
    // Rises into place on entrance and sinks on the idle fade-out.
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

    StyledRect {
        id: capsule

        // Drives the fail rim flash: animated 1 -> 0 rather than animating
        // border.color directly, which would clobber the binding on it.
        property real flash: 0

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        // Collapses to a circle on success, so the unlock has a gesture of
        // its own rather than the whole screen simply fading.
        width: Lock.unlocking ? root.capsuleHeight : root.capsuleWidth
        height: root.capsuleHeight
        radius: height / 2
        color: Colors.surfaceHigh
        border.width: 1
        // Picks up the accent while there is something to submit, so the
        // field reads as live rather than as a static shape with dots on it.
        border.color: Lock.buffer !== "" ? Qt.alpha(Colors.accent, 0.55) : Colors.border

        transform: Translate {
            id: shake
        }

        Behavior on width {
            NumberAnimation {
                duration: Appearance.anim.durations.expand
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.expressive
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Appearance.anim.durations.normal
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Colors.danger
            opacity: capsule.flash
        }

        StyledText {
            anchors.centerIn: parent
            text: "Enter password"
            font.pixelSize: 14
            color: Colors.faint
            opacity: Lock.buffer === "" && !Lock.authenticating && !Lock.unlocking ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.durations.fast
                }
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 9
            opacity: Lock.unlocking ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.durations.fast
                }
            }

            Repeater {
                // Capped rather than scrolling: the capsule is a fixed
                // width, so past this the dot row simply stops growing.
                model: Math.min(Lock.buffer.length, Lock.maxDots)

                Rectangle {
                    width: 9
                    height: 9
                    radius: 4.5
                    color: Colors.text
                    scale: 0

                    // Each new dot springs in on its own -- the Repeater
                    // builds exactly one delegate per keystroke.
                    Component.onCompleted: scale = 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.anim.durations.fast
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.anim.curves.expressive
                        }
                    }
                }
            }
        }

        MaterialIcon {
            id: trail
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 19
            text: Lock.authenticating ? "progress_activity" : Lock.lockedOut ? "lock_clock" : "lock"
            color: Lock.lockedOut ? Colors.danger : Colors.faint
            opacity: Lock.unlocking ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.durations.fast
                }
            }
        }

        // Separate from the trailing glyph rather than a text swap: on
        // success the capsule is collapsing to a circle underneath, and
        // the check has to land in its centre, not where the lock was.
        MaterialIcon {
            anchors.centerIn: parent
            text: "check"
            font.pixelSize: 24
            color: Colors.accent
            opacity: Lock.unlocking ? 1 : 0
            scale: Lock.unlocking ? 1 : 0.4

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.durations.normal
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.durations.expand
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.expressive
                }
            }
        }
    }

    // Standalone rather than `NumberAnimation on rotation`, so the icon
    // can be snapped back to upright once the spin stops.
    NumberAnimation {
        target: trail
        property: "rotation"
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
        running: Lock.authenticating
        onRunningChanged: if (!running)
            trail.rotation = 0
    }

    StyledText {
        anchors.top: capsule.bottom
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        text: Lock.message
        font.pixelSize: 13
        color: Lock.messageIsError ? Colors.danger : Colors.subtext
        opacity: Lock.message === "" ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.durations.normal
            }
        }
    }

    SequentialAnimation {
        id: shakeAnim

        NumberAnimation {
            target: shake
            property: "x"
            to: 11
            duration: 55
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: shake
            property: "x"
            to: -9
            duration: 70
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: shake
            property: "x"
            to: 6
            duration: 70
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: shake
            property: "x"
            to: -3
            duration: 70
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: shake
            property: "x"
            to: 0
            duration: 80
            easing.type: Easing.OutQuad
        }
    }

    SequentialAnimation {
        id: flashAnim

        NumberAnimation {
            target: capsule
            property: "flash"
            to: 1
            duration: 70
        }
        NumberAnimation {
            target: capsule
            property: "flash"
            to: 0
            duration: 520
            easing.type: Easing.OutQuad
        }
    }

    Connections {
        target: Lock

        function onFailed(): void {
            shakeAnim.restart();
            flashAnim.restart();
        }
    }
}
