import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// The island's window switcher: one card per open window, the highlighted
// one lit in the accent.
//
// Icons rather than live thumbnails on purpose -- the screencopy needed
// for real previews means a capture per window per frame, which is a lot
// of GPU for something on screen for half a second. The app icon plus the
// window title is what you actually read when picking anyway.
Item {
    id: root

    readonly property int cardW: 108
    readonly property int cardH: 92
    readonly property int gap: 10

    implicitWidth: Math.max(320, row.implicitWidth)
    implicitHeight: root.cardH

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.gap

        Repeater {
            model: Windows.list

            delegate: Item {
                id: card

                required property var modelData
                required property int index

                readonly property bool current: card.index === Windows.index

                width: root.cardW
                height: root.cardH

                StyledRect {
                    id: surface
                    anchors.fill: parent
                    radius: 16
                    color: card.current ? Colors.accentDim : cardHover.hovered ? Colors.surfaceHover : Colors.surface
                    border.width: 1
                    border.color: card.current ? Colors.accent : "transparent"

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Appearance.anim.durations.fast
                        }
                    }
                }

                // Lifts slightly when selected, so the highlight reads
                // even at a glance while you are cycling quickly.
                scale: card.current ? 1.04 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.anim.durations.fast
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.expressive
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    width: parent.width - 16

                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitSize: 40
                        source: Quickshell.iconPath(card.modelData?.appId ?? "", "application-x-executable")
                    }

                    StyledText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: card.modelData?.title ?? ""
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.pixelSize: Appearance.font.px(11)
                        color: card.current ? Colors.text : Colors.subtext
                    }
                }

                HoverHandler {
                    id: cardHover
                }

                TapHandler {
                    onTapped: Windows.activateAt(card.index)
                }
            }
        }
    }
}
