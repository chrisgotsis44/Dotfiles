import QtQuick
import QtQuick.Effects
import qs.components
import qs.config
import qs.services

// The hero: hour stacked over minute at display size, hour in the theme
// accent and minute in the foreground colour.
//
// Stacked rather than "16:40" on one line, which is what lets the type run
// this large without spanning the screen -- and it drops the colon, which
// at display size reads as debris. The two rows are pulled together with
// negative leading until they very nearly touch; that tightness is the
// whole effect, and it is why this is a Column with negative spacing
// rather than two separately positioned labels.
Item {
    id: root

    property bool shown: false
    property bool dimmed: false
    // Driven from screen height by the surface, so the clock keeps its
    // proportion on any monitor instead of being pinned to 1080p.
    property int digitSize: 168

    // Measured off hidden labels rather than the rolling rows: those clip
    // their contents and take their width FROM this, so reading it back
    // off them would be a binding loop.
    readonly property real rowWidth: Math.max(hourMetric.implicitWidth, minuteMetric.implicitWidth)

    implicitWidth: stack.implicitWidth
    implicitHeight: stack.implicitHeight

    opacity: root.shown ? (root.dimmed ? 0.5 : 1) : 0

    // Sinks a little as it dims, so going idle reads as settling rather
    // than as the screen just losing brightness.
    transform: Translate {
        y: root.dimmed ? 18 : 0

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
            duration: Appearance.anim.durations.expand
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.curves.standard
        }
    }

    // Display type sits directly on the wallpaper with no surface behind
    // it, so it needs its own separation from whatever is underneath --
    // a soft drop shadow rather than an outline, which at this size would
    // read as a sticker.
    layer.enabled: true
    layer.effect: MultiEffect {
        autoPaddingEnabled: true
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.55)
        shadowBlur: 1.0
        shadowVerticalOffset: 6
    }

    StyledText {
        id: hourMetric
        visible: false
        text: Qt.formatDateTime(Time.now, "HH")
        font.family: Appearance.font.family
        font.pixelSize: root.digitSize
        font.weight: Font.Black
    }

    StyledText {
        id: minuteMetric
        visible: false
        text: Qt.formatDateTime(Time.now, "mm")
        font.family: Appearance.font.family
        font.pixelSize: root.digitSize
        font.weight: Font.Black
    }

    Column {
        id: stack

        // Adwaita Sans reserves ~1.3x the pixel size as line height.
        // Clawing most of that back is what closes the gap between rows;
        // at this weight the two numerals should almost touch.
        spacing: Math.round(-root.digitSize * 0.36)

        RollingDigits {
            value: Qt.formatDateTime(Time.now, "HH")
            pixelSize: root.digitSize
            textColor: Colors.accent
            rowWidth: root.rowWidth

            // The rows enter from opposite sides and settle together.
            transform: Translate {
                x: root.shown ? 0 : -46

                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.anim.durations.expand
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.emphasized
                    }
                }
            }
        }

        RollingDigits {
            value: Qt.formatDateTime(Time.now, "mm")
            pixelSize: root.digitSize
            textColor: Colors.text
            rowWidth: root.rowWidth

            transform: Translate {
                x: root.shown ? 0 : 46

                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.anim.durations.expand
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.emphasized
                    }
                }
            }
        }
    }
}
