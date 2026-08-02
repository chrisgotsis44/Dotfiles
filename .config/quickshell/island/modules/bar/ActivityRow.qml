import QtQuick
import qs.config
import qs.components
import qs.services

// One live activity, expanded: icon, what it is, how far along, controls.
//
// Which controls appear is decided by the activity's own `controls` field
// rather than by this file knowing about timers -- a script-pushed
// activity gets a dismiss and nothing else, because the shell has no way
// to pause someone else's download.
Item {
    id: root

    required property var activity

    readonly property bool isMode: (root.activity?.kind ?? "task") === "mode"
    readonly property bool indeterminate: (root.activity?.progress ?? -1) < 0
    readonly property string controls: root.activity?.controls ?? ""
    readonly property bool isTimer: root.controls === "timer"
    readonly property bool isPomo: root.controls === "pomodoro"
    readonly property bool isStopwatch: root.controls === "stopwatch"
    readonly property bool isKeepAwake: root.controls === "keepawake"
    readonly property bool isDnd: root.controls === "dnd"
    readonly property bool ownsTransport: root.isTimer || root.isPomo || root.isStopwatch
    readonly property bool running: root.isTimer ? Timers.timerRunning : root.isPomo ? Timers.pomoRunning : root.isStopwatch ? Timers.swRunning : false

    implicitHeight: 44

    Rectangle {
        id: badge
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 34
        radius: 17
        color: Colors.surfaceHigh

        MaterialIcon {
            anchors.centerIn: parent
            text: root.activity?.icon ?? "bolt"
            font.pixelSize: 18
            color: Colors.accent
        }
    }

    Column {
        anchors.left: badge.right
        anchors.leftMargin: 12
        anchors.right: valueText.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        StyledText {
            width: parent.width
            text: {
                const t = root.activity?.title ?? "";
                const s = root.activity?.subtitle ?? "";
                // A mode's subtitle gets its own line below instead of
                // being folded in -- there is no track competing for the
                // space, and "Sleep and lock suppressed" is the point.
                if (root.isMode || s === "")
                    return t;
                return `${t} · ${s}`;
            }
            elide: Text.ElideRight
            font.pixelSize: 13
            font.weight: 600
        }

        StyledText {
            width: parent.width
            visible: root.isMode && (root.activity?.subtitle ?? "") !== ""
            text: root.activity?.subtitle ?? ""
            elide: Text.ElideRight
            font.pixelSize: 11
            color: Colors.subtext
        }

        // Track + fill. Indeterminate activities get a sliding sliver
        // instead of a fill, since a bar stuck at zero reads as stalled.
        // Modes get nothing: they are not progressing toward anything.
        Rectangle {
            id: track
            visible: !root.isMode
            width: parent.width
            height: 4
            radius: 2
            color: Colors.surfaceHigh
            clip: true

            Rectangle {
                id: fill
                height: parent.height
                radius: parent.radius
                color: Colors.accent
                width: root.indeterminate ? track.width * 0.3 : track.width * Math.max(0, Math.min(1, root.activity?.progress ?? 0))

                Behavior on width {
                    enabled: !root.indeterminate

                    NumberAnimation {
                        duration: Appearance.anim.durations.normal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }
            }

            SequentialAnimation {
                running: root.indeterminate && !root.isMode
                loops: Animation.Infinite

                NumberAnimation {
                    target: fill
                    property: "x"
                    from: -track.width * 0.3
                    to: track.width
                    duration: 1200
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }

    MonoText {
        id: valueText
        anchors.right: controlRow.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.activity?.value ?? ""
        visible: text !== ""
        font.pixelSize: 15
        font.weight: 700
    }

    Row {
        id: controlRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        component MiniButton: Rectangle {
            id: mini

            property string glyph
            signal pressed

            width: 30
            height: 30
            radius: 15
            color: miniMouse.containsMouse ? Colors.surfaceHover : Colors.surfaceHigh

            MaterialIcon {
                anchors.centerIn: parent
                text: mini.glyph
                font.pixelSize: 17
                font.variableAxes: ({
                    FILL: 1
                })
                color: Colors.subtext
            }

            MouseArea {
                id: miniMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mini.pressed()
            }
        }

        MiniButton {
            visible: root.ownsTransport
            glyph: root.running ? "pause" : "play_arrow"
            onPressed: {
                if (root.isTimer)
                    Timers.timerToggle();
                else if (root.isPomo)
                    Timers.pomoToggle();
                else
                    Timers.swToggle();
            }
        }

        MiniButton {
            visible: root.isPomo
            glyph: "skip_next"
            onPressed: Timers.pomoSkip()
        }

        MiniButton {
            glyph: "close"
            onPressed: {
                if (root.isTimer)
                    Timers.timerReset();
                else if (root.isPomo)
                    Timers.pomoReset();
                else if (root.isStopwatch)
                    Timers.swReset();
                else if (root.isKeepAwake)
                    GlobalState.toggleKeepAwake();
                else if (root.isDnd)
                    GlobalState.dnd = false;
                else
                    Activities.remove(root.activity.id);
            }
        }
    }
}
