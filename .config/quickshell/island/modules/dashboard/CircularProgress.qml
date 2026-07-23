import QtQuick
import QtQuick.Shapes
import qs.config

// Ring progress indicator (Shape/PathAngleArc -- GPU-friendly, no
// Canvas repaints). Content (percentage text etc.) goes in the middle
// via default children.
Item {
    id: root

    property real value: 0 // 0-1
    property real thickness: 7
    property color trackColor: Colors.surfaceHigh
    property color fillColor: Colors.accent

    implicitWidth: 96
    implicitHeight: 96

    // The sweep chases value changes so poll updates glide.
    property real animatedValue: value

    Behavior on animatedValue {
        NumberAnimation {
            duration: Appearance.anim.durations.expand
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.curves.emphasized
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: root.thickness
            strokeColor: root.trackColor
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - root.thickness / 2
                radiusY: root.height / 2 - root.thickness / 2
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeWidth: root.thickness
            strokeColor: root.fillColor
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - root.thickness / 2
                radiusY: root.height / 2 - root.thickness / 2
                startAngle: -90
                sweepAngle: 360 * Math.max(0, Math.min(1, root.animatedValue))
            }
        }
    }
}
