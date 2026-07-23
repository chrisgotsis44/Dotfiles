pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// Search bar on top, app list below. Enter launches the highlighted
// entry, arrows navigate, Escape closes. Rendered inside the island
// (transparent root — the island supplies the panel).
Item {
    id: root

    implicitWidth: 600
    implicitHeight: 520

    readonly property var filtered: {
        const q = search.text.toLowerCase().trim();
        let apps = [...DesktopEntries.applications.values].filter(a => !a.noDisplay);

        // Frequently-launched apps break ties in their favor -- most
        // used first with no query (rofi-style), or ranked above
        // equally-good text matches once you start typing.
        const byUsage = (a, b) => AppUsage.countFor(b.id) - AppUsage.countFor(a.id);

        if (q) {
            // Rank: name prefix > name substring > comment/keywords
            const score = a => {
                const name = a.name.toLowerCase();
                if (name.startsWith(q))
                    return 0;
                if (name.includes(q))
                    return 1;
                if ((a.comment ?? "").toLowerCase().includes(q) || (a.genericName ?? "").toLowerCase().includes(q))
                    return 2;
                return 3;
            };
            apps = apps.filter(a => score(a) < 3).sort((a, b) => score(a) - score(b) || byUsage(a, b) || a.name.localeCompare(b.name));
        } else {
            apps.sort((a, b) => byUsage(a, b) || a.name.localeCompare(b.name));
        }

        return apps.slice(0, 50);
    }

    function launch(entry: var): void {
        if (!entry)
            return;
        AppUsage.recordLaunch(entry.id);
        entry.execute();
        GlobalState.launcherOpen = false;
    }

    // Reset + focus the search field every time the launcher opens.
    Connections {
        target: GlobalState
        function onLauncherOpenChanged() {
            if (GlobalState.launcherOpen) {
                search.text = "";
                list.currentIndex = 0;
                search.forceActiveFocus();
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        StyledRect {
            width: parent.width
            height: 52
            radius: 16
            color: Colors.surface
            border.width: 1
            border.color: search.activeFocus ? Colors.accentDim : Colors.border

            Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "search"
                    font.pixelSize: 20
                    color: Colors.subtext
                }

                TextInput {
                    id: search
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 36
                    color: Colors.text
                    font.family: Appearance.font.family
                    font.pixelSize: 16
                    clip: true

                    onTextChanged: list.currentIndex = 0
                    onAccepted: root.launch(root.filtered[list.currentIndex])

                    Keys.onEscapePressed: GlobalState.launcherOpen = false
                    Keys.onDownPressed: list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1)
                    Keys.onUpPressed: list.currentIndex = Math.max(list.currentIndex - 1, 0)

                    StyledText {
                        visible: search.text === ""
                        text: "Search apps…"
                        font.pixelSize: 16
                        color: Colors.faint
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        ListView {
            id: list
            width: parent.width
            height: parent.height - 62
            clip: true
            spacing: 4
            model: root.filtered
            currentIndex: 0
            highlightMoveDuration: Appearance.anim.durations.fast

            delegate: StyledRect {
                id: appItem

                required property var modelData
                required property int index

                width: list.width
                implicitHeight: 56
                radius: 14
                color: list.currentIndex === index ? Colors.surfaceHigh
                     : appHover.hovered ? Colors.surfaceHover
                     : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 34
                        source: Quickshell.iconPath(appItem.modelData.icon, "application-x-executable")
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 48
                        spacing: 1

                        StyledText {
                            width: parent.width
                            text: appItem.modelData.name
                            elide: Text.ElideRight
                            font.pixelSize: 15
                            font.weight: 600
                        }
                        StyledText {
                            width: parent.width
                            visible: text !== ""
                            text: appItem.modelData.comment ?? ""
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            color: Colors.subtext
                        }
                    }
                }

                HoverHandler {
                    id: appHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: root.launch(appItem.modelData)
                }
            }
        }
    }
}
