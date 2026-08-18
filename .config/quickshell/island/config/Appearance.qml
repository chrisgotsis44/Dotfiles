pragma Singleton

import Quickshell
import QtQuick

// Non-color design tokens: fonts, metrics, animation durations and curves.
// Everything is scaled up ~1.2x for legibility / touch friendliness.
Singleton {
    readonly property QtObject font: QtObject {
        // General UI text. Live from config.json; an unresolvable name
        // falls back to Qt's default rather than failing.
        readonly property string family: Config.settings.fontFamily || "Adwaita Sans"
        // Numbers, status readouts, monospace elements
        readonly property string mono: "JetBrainsMono Nerd Font Propo"
        readonly property string iconFamily: "Material Symbols Rounded"
        // Live from config.json (Settings panel / hand edit) -- clamped
        // so a bad hand-edit can't render the shell unreadable.
        readonly property int size: Math.max(11, Math.min(20, Config.settings.fontSize))

        // Every explicit text size in the shell goes through px(), which
        // scales it relative to a base of 15.
        //
        // This exists because `size` alone could never work: it is the
        // DEFAULT for StyledText, and all 218 call sites set
        // font.pixelSize themselves, which replaces the binding
        // outright. Raising the setting changed literally one thing --
        // text that had not asked for a size, of which there is none.
        // px() is the indirection that gives the setting reach.
        //
        // Rounded because a fractional pixelSize renders blurry.
        readonly property real scale: size / 15
        function px(base: real): int {
            return Math.round(base * scale);
        }
    }

    readonly property QtObject bar: QtObject {
        readonly property int topMargin: Math.max(0, Math.min(32, Config.settings.barTopMargin))
        readonly property int hPadding: Math.max(8, Math.min(48, Config.settings.barHPadding))
        readonly property int vPadding: Math.max(4, Math.min(28, Config.settings.barVPadding))
        // Reserved strip at the top of the screen, sized to the IDLE
        // pill with an even gap above and below it:
        //   topMargin + idle island height (18px clock + 2×vPadding)
        //   + topMargin again
        // Derived, not a literal, so it tracks the topMargin setting.
        // Expanded states (hover/OSD/notif/menus) intentionally overlay
        // application windows, like the real Dynamic Island.
        readonly property int exclusiveZone: topMargin * 2 + 18 + vPadding * 2
    }

    readonly property QtObject rounding: QtObject {
        // One scale factor from config.json across all three steps, so
        // their relationship (and every widget's hierarchy of corners)
        // survives the adjustment.
        readonly property real scale: Math.max(0.25, Math.min(1.75, Config.settings.roundingScale))
        readonly property int small: Math.round(12 * scale)
        readonly property int normal: Math.round(18 * scale)
        readonly property int large: Math.round(28 * scale)
    }

    // Motion.
    //
    // This is the Material 3 *Expressive* token set: twelve curves, each
    // with a duration it is meant to be used at. The pairing is the whole
    // point -- an expressive curve overshoots, and an overshoot needs
    // room to settle, so running one at 150ms just reads as a glitch.
    // components/Anim.qml bundles the two so they cannot be mismatched;
    // prefer it over hand-picking a curve and a duration separately.
    //
    // Spatial vs effects is the distinction worth internalising:
    //   spatial — things that MOVE or RESIZE. Slightly underdamped, so
    //             they overshoot a touch and settle. This is what reads
    //             as "alive" rather than "computed".
    //   effects — things that FADE or RECOLOR. Critically damped, no
    //             overshoot, because opacity past 1 is just clamped and
    //             a colour that overshoots looks like a bug.
    readonly property QtObject anim: QtObject {
        readonly property QtObject durations: QtObject {
            // Every duration is multiplied by this, from config.json.
            // 0 turns animation off outright (every Behavior snaps); 2
            // is half speed. Curves are untouched -- pace changes,
            // character doesn't.
            readonly property real scale: Math.max(0, Math.min(3, Config.settings.animScale))

            // --- legacy names, still used by ~90 call sites in both
            // --- shells. Base values unchanged.
            readonly property int fast: Math.round(150 * scale)
            readonly property int normal: Math.round(300 * scale)
            readonly property int expand: Math.round(500 * scale)
            // The island's own resize while morphed into a menu (see
            // Bar.qml's inMenu Behaviors). Anything that grows/shrinks
            // INSIDE a menu and expects the island to keep up without
            // clipping it mid-animation -- e.g. an expandable submenu of
            // sliders -- should animate its own height on this same
            // duration, not a shorter one, or it reveals faster than the
            // island can resize around it and gets cut off at the bottom.
            readonly property int menu: Math.round(550 * scale)

            // --- M3 standard/emphasized scale
            readonly property int small: Math.round(200 * scale)
            readonly property int large: Math.round(400 * scale)
            readonly property int extraLarge: Math.round(600 * scale)

            // --- M3 expressive. Spatial durations are long because the
            // --- curves overshoot and need the tail to settle in.
            readonly property int fastSpatial: Math.round(350 * scale)
            readonly property int defaultSpatial: Math.round(500 * scale)
            readonly property int slowSpatial: Math.round(650 * scale)
            readonly property int fastEffects: Math.round(150 * scale)
            readonly property int defaultEffects: Math.round(200 * scale)
            readonly property int slowEffects: Math.round(300 * scale)
        }

        // Cubic bezier segments for NumberAnimation.easing.bezierCurve.
        // One segment is [cx1, cy1, cx2, cy2, endX, endY]; a list of 12
        // is two chained segments, and the last point must be (1,1).
        readonly property QtObject curves: QtObject {
            // --- standard: no overshoot, for utilitarian motion
            readonly property list<real> standard: [0.3, 0.0, 0.0, 1.0, 1.0, 1.0]
            // Leaving the screen: start slow, accelerate away. Never use
            // this for something arriving -- it lands at full speed.
            readonly property list<real> standardAccel: [0.3, 0.0, 1.0, 1.0, 1.0, 1.0]
            // Arriving: full speed immediately, then ease down.
            readonly property list<real> standardDecel: [0.0, 0.0, 0.0, 1.0, 1.0, 1.0]

            // `emphasized` predates the rest of this block and is really
            // M3's emphasizedDecel. It stays exactly as it was -- 31 call
            // sites across the island and lock shells are tuned against
            // it, and a decelerate curve is the right default for most of
            // them anyway (reveals, slides, expansions).
            readonly property list<real> emphasized: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
            readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
            readonly property list<real> emphasizedAccel: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
            // M3's REAL emphasized: two segments, a deliberate slow start
            // and then a decisive move. This is the one that makes a big
            // panel feel considered rather than merely fast, and it is
            // the only curve here that needs both segments to work.
            readonly property list<real> emphasizedFull: [0.05, 0.0, 0.133333, 0.06, 0.166667, 0.4, 0.208333, 0.82, 0.25, 1.0, 1.0, 1.0]

            // --- expressive spatial: underdamped, they overshoot
            // `expressive` is the old name for defaultSpatial; identical.
            readonly property list<real> expressive: [0.38, 1.21, 0.22, 1.0, 1.0, 1.0]
            readonly property list<real> fastSpatial: [0.42, 1.67, 0.21, 0.9, 1.0, 1.0]
            readonly property list<real> defaultSpatial: [0.38, 1.21, 0.22, 1.0, 1.0, 1.0]
            readonly property list<real> slowSpatial: [0.39, 1.29, 0.35, 0.98, 1.0, 1.0]

            // --- expressive effects: critically damped, no overshoot
            readonly property list<real> fastEffects: [0.31, 0.94, 0.34, 1.0, 1.0, 1.0]
            readonly property list<real> defaultEffects: [0.34, 0.8, 0.34, 1.0, 1.0, 1.0]
            readonly property list<real> slowEffects: [0.34, 0.88, 0.34, 1.0, 1.0, 1.0]
        }
    }
}
