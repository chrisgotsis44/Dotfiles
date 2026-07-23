import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.components

// Hyprland workspace dots for the hover-expanded island. The focused
// workspace stretches into an accent capsule (with its number fading
// in); the others are compact clickable dots.
//
// Shows only THIS monitor's workspaces, at most five of them.
Row {
    id: root

    required property ShellScreen screen
    readonly property var monitor: Hyprland.monitorFor(screen)

    spacing: 8

    Repeater {
        // This monitor's workspaces, sorted, capped at 5; special
        // workspaces (id < 0) hidden.
        model: [...Hyprland.workspaces.values]
            .filter(w => w.id > 0 && w.monitor?.name === root.monitor?.name)
            .sort((a, b) => a.id - b.id)
            .slice(0, 5)

        Rectangle {
            id: dot

            required property var modelData

            readonly property bool focused: modelData.focused

            anchors.verticalCenter: parent.verticalCenter
            width: focused ? 28 : 12
            height: 12
            radius: 6
            color: focused ? Colors.accent
                 : dotHover.hovered ? Colors.surfaceHover
                 : Colors.surfaceHigh

            Behavior on width {
                NumberAnimation {
                    duration: Appearance.anim.durations.expand
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.expressive
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.durations.fast
                }
            }

            // Adwaita Sans, not the mono font -- JetBrains' digits read
            // cramped/blocky at this size; the regular UI font's numerals
            // sit much more cleanly inside a 12px-tall pill.
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
