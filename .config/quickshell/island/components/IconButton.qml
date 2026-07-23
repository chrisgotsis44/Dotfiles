import QtQuick
import qs.config

// Round icon button with hover/press/active feedback.
StyledRect {
    id: root

    property string icon
    property bool active: false
    property real size: 44
    property real iconSize: 21
    property color activeColor: Colors.accent

    signal clicked()

    implicitWidth: size
    implicitHeight: size
    radius: size / 2

    color: active ? activeColor
         : tap.pressed ? Colors.surfacePressed
         : hover.hovered ? Colors.surfaceHover
         : Colors.surfaceHigh

    MaterialIcon {
        anchors.centerIn: parent
        text: root.icon
        font.pixelSize: root.iconSize
        color: root.active ? Colors.accentFg : Colors.text
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap
        onTapped: root.clicked()
    }

    scale: tap.pressed ? 0.92 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Appearance.anim.durations.fast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.curves.standard
        }
    }
}
