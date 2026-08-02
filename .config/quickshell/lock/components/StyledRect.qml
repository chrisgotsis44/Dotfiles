import QtQuick
import qs.config

// Base surface: themed color with an animated color transition, so any
// state-driven recolor (hover, active toggle, ...) fades instead of snaps.
Rectangle {
    color: Colors.surface
    radius: Appearance.rounding.normal

    Behavior on color {
        ColorAnimation {
            duration: Appearance.anim.durations.fast
        }
    }
}
