import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.components

// Hyprland workspace dots for the hover-expanded island. Inactive
// workspaces are subtle, low-opacity dots; the focused one stretches
// into a crisp, fully-opaque accent capsule with its number fading in.
// Width, height AND position all animate (the last via a plain
// `Behavior on x` picked up from Row's own positioner, which assigns
// x directly rather than through a binding) so the whole row resettles
// smoothly whenever a workspace is added, removed, or focus changes.
//
// Shows only THIS monitor's workspaces, at most five of them.
Row {
    id: root

    required property ShellScreen screen
    readonly property var monitor: Hyprland.monitorFor(screen)

    spacing: 10

    Repeater {
        // This monitor's workspaces, sorted, capped at 5; special
        // workspaces (id < 0) hidden.
        //
        // Wrapped in ScriptModel, NOT used as a bare JS array: a plain
        // array expression is a brand-new list object on every
        // re-evaluation, so Repeater tears down and rebuilds every
        // delegate whenever a workspace is added or removed. That
        // destroys exactly the animations below -- a delegate that was
        // just constructed has nothing to animate *from*, so the dots
        // popped into place instead of sliding. ScriptModel diffs the
        // list and emits real insert/remove operations, so surviving
        // dots keep their identity and their `Behavior on x` runs.
        model: ScriptModel {
            values: [...Hyprland.workspaces.values]
                .filter(w => w.id > 0 && w.monitor?.name === root.monitor?.name)
                .sort((a, b) => a.id - b.id)
                .slice(0, 5)
        }

        Rectangle {
            id: dot

            required property var modelData

            readonly property bool focused: modelData.focused

            anchors.verticalCenter: parent.verticalCenter
            width: focused ? 30 : 8
            height: focused ? 20 : 8
            radius: height / 2
            color: focused ? Colors.accent : Colors.text
            opacity: focused ? 1 : (dotHover.hovered ? 0.55 : 0.28)

            Behavior on width {
                NumberAnimation {
                    duration: Appearance.anim.durations.expand
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.expressive
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: Appearance.anim.durations.expand
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.expressive
                }
            }
            // Row assigns x directly as siblings resize/reorder -- this
            // turns that jump into a smooth slide.
            Behavior on x {
                NumberAnimation {
                    duration: Appearance.anim.durations.expand
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.expressive
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.durations.fast
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.durations.fast
                }
            }

            // Adwaita Sans, not the mono font -- JetBrains' digits read
            // cramped/blocky at this size; the regular UI font's numerals
            // sit much more cleanly inside the capsule.
            StyledText {
                anchors.centerIn: parent
                text: dot.modelData.id
                font.pixelSize: 11
                font.weight: 700
                color: Colors.accentFg
                opacity: dot.focused ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.durations.normal
                    }
                }
            }

            HoverHandler {
                id: dotHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: Hyprland.dispatch("workspace " + dot.modelData.id)
            }
        }
    }
}
