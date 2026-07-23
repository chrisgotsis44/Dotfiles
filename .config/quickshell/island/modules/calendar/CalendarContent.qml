pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components

// Minimal month view, rendered inside the island (transparent root —
// the island supplies the panel). Monday-first grid, today ringed in
// the accent.
Item {
    id: root

    implicitWidth: 340
    implicitHeight: col.implicitHeight

    property date shown: new Date()

    // 42 cells (6 weeks). Depends on Time.now so "today" rolls over at
    // midnight without a restart.
    readonly property var days: {
        const y = shown.getFullYear();
        const m = shown.getMonth();
        const first = new Date(y, m, 1);
        const offset = (first.getDay() + 6) % 7; // Monday = 0
        const today = Time.now;
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(y, m, 1 + i - offset);
            out.push({
                n: d.getDate(),
                inMonth: d.getMonth() === m,
                today: d.toDateString() === today.toDateString()
            });
        }
        return out;
    }

    // Reset to the current month whenever the calendar is reopened.
    Connections {
        target: GlobalState
        function onCalendarOpenChanged() {
            if (GlobalState.calendarOpen)
                root.shown = new Date();
        }
    }

    Column {
        id: col
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10

        // Header: ‹  July 2026  ›
        Item {
            width: grid.width
            height: 36

            IconButton {
                anchors.left: parent.left
                icon: "chevron_left"
                size: 32
                iconSize: 18
                onClicked: root.shown = new Date(root.shown.getFullYear(), root.shown.getMonth() - 1, 1)
            }

            StyledText {
                anchors.centerIn: parent
                text: Qt.formatDate(root.shown, "MMMM yyyy")
                font.pixelSize: 16
                font.weight: 700

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: root.shown = new Date() // back to today
                }
            }

            IconButton {
                anchors.right: parent.right
                icon: "chevron_right"
                size: 32
                iconSize: 18
                onClicked: root.shown = new Date(root.shown.getFullYear(), root.shown.getMonth() + 1, 1)
            }
        }

        Row {
            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                StyledText {
                    required property string modelData
                    width: 46
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.pixelSize: 12
                    font.weight: 600
                    color: Colors.faint
                }
            }
        }

        Grid {
            id: grid
            columns: 7

            Repeater {
                model: root.days

                Item {
                    required property var modelData

                    width: 46
                    height: 40

                    Rectangle {
                        anchors.centerIn: parent
                        width: 34
                        height: 34
                        radius: 17
                        color: parent.modelData.today ? Colors.accent : "transparent"

                        MonoText {
                            anchors.centerIn: parent
                            text: parent.parent.modelData.n
                            font.pixelSize: 14
                            font.weight: parent.parent.modelData.today ? 700 : 400
                            color: parent.parent.modelData.today ? Colors.accentFg
                                 : parent.parent.modelData.inMonth ? Colors.text
                                 : Colors.faint
                        }
                    }
                }
            }
        }
    }
}
