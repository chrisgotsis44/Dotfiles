pragma Singleton

import Quickshell
import QtQuick

// Non-color design tokens: fonts, metrics, animation durations and curves.
// Everything is scaled up ~1.2x for legibility / touch friendliness.
Singleton {
    readonly property QtObject font: QtObject {
        // General UI text
        readonly property string family: "Adwaita Sans"
        // Numbers, status readouts, monospace elements
        readonly property string mono: "JetBrainsMono Nerd Font Propo"
        readonly property string iconFamily: "Material Symbols Rounded"
        readonly property int size: 15
    }

    readonly property QtObject bar: QtObject {
        readonly property int topMargin: 8
        readonly property int hPadding: 22
        readonly property int vPadding: 11
        // Reserved strip at the top of the screen, sized to the IDLE
        // pill with an even gap above and below it:
        //   topMargin + idle island height (18px clock + 2×vPadding)
        //   + topMargin again  =  8 + 40 + 8
        // Expanded states (hover/OSD/notif/menus) intentionally overlay
        // application windows, like the real Dynamic Island.
        readonly property int exclusiveZone: 48
    }

    readonly property QtObject rounding: QtObject {
        readonly property int small: 12
        readonly property int normal: 18
        readonly property int large: 28
    }

    readonly property QtObject anim: QtObject {
        readonly property QtObject durations: QtObject {
            readonly property int fast: 150
            readonly property int normal: 300
            readonly property int expand: 500
            // The island's own resize while morphed into a menu (see
            // Bar.qml's inMenu Behaviors). Anything that grows/shrinks
            // INSIDE a menu and expects the island to keep up without
            // clipping it mid-animation -- e.g. an expandable submenu of
            // sliders -- should animate its own height on this same
            // duration, not a shorter one, or it reveals faster than the
            // island can resize around it and gets cut off at the bottom.
            readonly property int menu: 550
        }

        // Cubic bezier segments for NumberAnimation.easing.bezierCurve:
        // [cx1, cy1, cx2, cy2, endX, endY]
        readonly property QtObject curves: QtObject {
            // Material 3 "standard" — everyday fades and moves
            readonly property list<real> standard: [0.3, 0.0, 0.0, 1.0, 1.0, 1.0]
            // Material 3 "emphasized decelerate" — same family as
            // Easing.InOutExpo: steep start, asymptotic settle
            readonly property list<real> emphasized: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
            // Slight overshoot — the island's expand/contract "bounce"
            readonly property list<real> expressive: [0.38, 1.21, 0.22, 1.0, 1.0, 1.0]
        }
    }
}
