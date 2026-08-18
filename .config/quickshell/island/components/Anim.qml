import QtQuick
import qs.config

// A motion token: one `type` picks BOTH the curve and the duration it is
// meant to run at.
//
//     Behavior on x { Anim { type: Anim.DefaultSpatial } }
//
// The pairing is the entire point. An expressive curve overshoots, and an
// overshoot needs tail to settle in -- run one at 150ms and it reads as a
// glitch rather than as spring. Picking a curve and a duration separately
// is how that mismatch happens, so prefer this over hand-wiring
// Appearance.anim.curves.* and Appearance.anim.durations.* together.
//
// Spatial vs effects, since it decides which half of the list to look in:
//   spatial — things that MOVE or RESIZE. Underdamped, they overshoot a
//             little and settle. This is what reads as alive.
//   effects — things that FADE or RECOLOR. Critically damped. Opacity
//             past 1 is clamped and an overshooting colour looks broken.
NumberAnimation {
    id: root

    enum Type {
        // Utilitarian, no overshoot.
        Standard,
        StandardSmall,
        StandardLarge,
        // Leaving / arriving. Accel lands at full speed, so it is only
        // ever right for something on its way out.
        StandardAccel,
        StandardDecel,
        // Big, considered moves.
        Emphasized,
        EmphasizedAccel,
        EmphasizedDecel,
        // Expressive spatial — overshoots.
        FastSpatial,
        DefaultSpatial,
        SlowSpatial,
        // Expressive effects — does not.
        FastEffects,
        DefaultEffects,
        SlowEffects
    }

    property int type: Anim.DefaultSpatial

    readonly property var _d: Appearance.anim.durations
    readonly property var _c: Appearance.anim.curves

    duration: {
        switch (root.type) {
        case Anim.Standard:
        case Anim.StandardAccel:
        case Anim.StandardDecel:
            return root._d.normal;
        case Anim.StandardSmall:
            return root._d.small;
        case Anim.StandardLarge:
            return root._d.large;
        case Anim.Emphasized:
        case Anim.EmphasizedAccel:
        case Anim.EmphasizedDecel:
            return root._d.extraLarge;
        case Anim.FastSpatial:
            return root._d.fastSpatial;
        case Anim.DefaultSpatial:
            return root._d.defaultSpatial;
        case Anim.SlowSpatial:
            return root._d.slowSpatial;
        case Anim.FastEffects:
            return root._d.fastEffects;
        case Anim.DefaultEffects:
            return root._d.defaultEffects;
        case Anim.SlowEffects:
            return root._d.slowEffects;
        }
        return root._d.normal;
    }

    easing.type: Easing.BezierSpline
    easing.bezierCurve: {
        switch (root.type) {
        case Anim.Standard:
        case Anim.StandardSmall:
        case Anim.StandardLarge:
            return root._c.standard;
        case Anim.StandardAccel:
            return root._c.standardAccel;
        case Anim.StandardDecel:
            return root._c.standardDecel;
        case Anim.Emphasized:
            return root._c.emphasizedFull;
        case Anim.EmphasizedAccel:
            return root._c.emphasizedAccel;
        case Anim.EmphasizedDecel:
            return root._c.emphasizedDecel;
        case Anim.FastSpatial:
            return root._c.fastSpatial;
        case Anim.DefaultSpatial:
            return root._c.defaultSpatial;
        case Anim.SlowSpatial:
            return root._c.slowSpatial;
        case Anim.FastEffects:
            return root._c.fastEffects;
        case Anim.DefaultEffects:
            return root._c.defaultEffects;
        case Anim.SlowEffects:
            return root._c.slowEffects;
        }
        return root._c.standard;
    }
}
