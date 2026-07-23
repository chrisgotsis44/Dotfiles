import QtQuick
import qs.config

// iOS/macOS-style toggle switch: capsule track that tints to the accent
// when on, with a knob that slides across and squashes slightly while
// pressed (the little "give" real iOS switches have).
Item {
    id: root

    property bool checked: false

    signal toggled()

    implicitWidth: 46
    implicitHeight: 27

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Colors.accent : Colors.surfaceHigh
        border.width: 1
        border.color: root.checked ? "transparent" : Colors.border

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.durations.normal
            }
        }
    }

    Rectangle {
        id: knob

        readonly property real pad: 3

        width: tap.pressed ? height + 4 : height
        height: parent.height - pad * 2
        radius: height / 2
        y: pad
        x: root.checked ? parent.width - width - pad : pad
        color: root.checked ? Colors.accentFg : Colors.text

        Behavior on x {
            NumberAnimation {
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: Appearance.anim.durations.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.standard
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.durations.normal
            }
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        id: tap
        onTapped: root.toggled()
    }
}
