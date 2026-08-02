pragma Singleton

import Quickshell
import QtQuick

// Non-color design tokens. A deliberately trimmed copy of the island's
// Appearance.qml: this config is standalone so that a fault in the shell
// cannot take the lockscreen down with it, which means it cannot import
// anything from the island either. Only the tokens the lockscreen
// actually uses are carried over.
Singleton {
    readonly property QtObject font: QtObject {
        readonly property string family: "Adwaita Sans"
        readonly property string mono: "JetBrainsMono Nerd Font Propo"
        readonly property string iconFamily: "Material Symbols Rounded"
        readonly property int size: 15
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
        }

        // Cubic bezier segments for NumberAnimation.easing.bezierCurve:
        // [cx1, cy1, cx2, cy2, endX, endY]
        readonly property QtObject curves: QtObject {
            // Material 3 "standard" — everyday fades and moves
            readonly property list<real> standard: [0.3, 0.0, 0.0, 1.0, 1.0, 1.0]
            // Material 3 "emphasized decelerate" — steep start, asymptotic settle
            readonly property list<real> emphasized: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
            // Slight overshoot
            readonly property list<real> expressive: [0.38, 1.21, 0.22, 1.0, 1.0, 1.0]
        }
    }
}
