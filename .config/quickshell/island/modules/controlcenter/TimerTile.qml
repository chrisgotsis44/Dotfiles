import QtQuick
import qs.config
import qs.components
import qs.services

// One clock tile in the Control Center -- the countdown timer or the
// pomodoro. Deliberately shaped like CcToggle (same height, radius and
// surface colours) so the pair reads as another row of the toggle grid
// above it rather than as a separate widget bolted underneath.
//
// Pure view: every button calls into Timers, which owns all the state and
// pushes the matching Activity. Nothing here knows the island exists.
StyledRect {
    id: root

    property string icon
    property string label
    // Live status line under the label.
    property string sub
    // Big monospaced readout on the right.
    property string readout
    property bool running: false
    // 0..1 arc behind the play button; -1 draws nothing.
    property real progress: -1
    // Left button: "remove" when the value is settable, "replay" once a
    // countdown is in flight, "skip_next" for the pomodoro.
    property string leftIcon: ""
    property string rightIcon: ""

    // Right-click anywhere on the tile: switches the clock's mode, or
    // opens the pomodoro's settings.
    property bool hasSecondary: false

    signal primaryClicked
    signal leftClicked
    signal rightClicked
    signal secondaryClicked

    implicitHeight: 68
    radius: 20
    color: Colors.surface

    // Declared first so it sits UNDER the buttons. It only accepts the
    // right button, and the button MouseAreas only accept the left, so
    // neither swallows the other's clicks.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        enabled: root.hasSecondary
        onClicked: root.secondaryClicked()
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        // Play/pause, with the progress arc drawn around it -- the same
        // information the island chip carries, in the place your eye
        // already is when you press the button.
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 42

            Canvas {
                id: arc
                anchors.fill: parent
                // Canvas does not repaint on binding changes by itself.
                readonly property real p: root.progress
                onPChanged: arc.requestPaint()
                visible: root.progress >= 0

                onPaint: {
                    const ctx = arc.getContext("2d");
                    ctx.reset();
                    const r = arc.width / 2 - 1.5;
                    ctx.lineWidth = 3;
                    ctx.lineCap = "round";

                    ctx.beginPath();
                    ctx.arc(arc.width / 2, arc.height / 2, r, 0, Math.PI * 2);
                    ctx.strokeStyle = Colors.surfaceHigh;
                    ctx.stroke();

                    if (arc.p > 0) {
                        ctx.beginPath();
                        ctx.arc(arc.width / 2, arc.height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, arc.p));
                        ctx.strokeStyle = Colors.accent;
                        ctx.stroke();
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 34
                height: 34
                radius: 17
                color: root.running ? Colors.accent : primaryMouse.containsMouse ? Colors.surfaceHover : Colors.surfaceHigh

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.durations.fast
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.running ? "pause" : "play_arrow"
                    font.pixelSize: 19
                    font.variableAxes: ({
                        FILL: 1
                    })
                    color: root.running ? Colors.accentFg : Colors.subtext
                }
            }

            MouseArea {
                id: primaryMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.primaryClicked()
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            width: parent.width - 42 - 10 - controls.width - 10

            Row {
                width: parent.width
                spacing: 4

                StyledText {
                    text: root.label
                    elide: Text.ElideRight
                    font.pixelSize: 14
                    font.weight: 600
                }

                // Quiet affordance for the right-click, rather than a
                // hidden gesture nobody would find.
                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.hasSecondary
                    text: "more_horiz"
                    font.pixelSize: 13
                    color: Colors.faint
                }
            }

            MonoText {
                width: parent.width
                text: root.readout
                elide: Text.ElideRight
                font.pixelSize: 17
                font.weight: 700
                color: root.running ? Colors.accent : Colors.text
            }

            StyledText {
                width: parent.width
                text: root.sub
                elide: Text.ElideRight
                visible: root.sub !== ""
                font.pixelSize: 11
                color: Colors.subtext
            }
        }
    }

    Column {
        id: controls
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        component MiniButton: Rectangle {
            id: mini

            property string glyph
            signal pressed

            width: 26
            height: 24
            radius: 8
            color: miniMouse.containsMouse ? Colors.surfaceHover : "transparent"

            MaterialIcon {
                anchors.centerIn: parent
                text: mini.glyph
                font.pixelSize: 16
                color: Colors.subtext
            }

            MouseArea {
                id: miniMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mini.pressed()
            }
        }

        MiniButton {
            glyph: root.rightIcon
            visible: root.rightIcon !== ""
            onPressed: root.rightClicked()
        }

        MiniButton {
            glyph: root.leftIcon
            visible: root.leftIcon !== ""
            onPressed: root.leftClicked()
        }
    }
}
