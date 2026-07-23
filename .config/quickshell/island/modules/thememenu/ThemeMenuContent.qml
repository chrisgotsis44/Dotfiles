pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components

// The system theme switcher, folded into the island the same way the
// launcher and Control Center are: a list on the left (active theme
// marked, three swatch dots read live from each theme's own palette
// file), a wallpaper preview on the right that follows whichever theme
// is hovered/selected. Applying a theme (click, or Enter on the
// keyboard-selected row) runs apply-theme.sh and closes the menu;
// nothing here overrides Colors.qml -- once applied, the theme switch
// flows back through Colors.qml's own FileView watchers like any other
// theme change.
Item {
    id: root

    implicitWidth: 940
    implicitHeight: 640

    property string previewTheme: Themes.activeTheme

    // Reset to the active theme, pull fresh swatches/wallpapers, and
    // grab keyboard focus every time the menu opens.
    Connections {
        target: GlobalState
        function onThemeMenuOpenChanged() {
            if (GlobalState.themeMenuOpen) {
                Themes.refresh();
                root.previewTheme = Themes.activeTheme;
                const idx = Themes.list.findIndex(t => t.name === Themes.activeTheme);
                list.currentIndex = idx >= 0 ? idx : 0;
                list.forceActiveFocus();
            }
        }
    }

    function displayFor(name: string): string {
        const entry = Themes.list.find(t => t.name === name);
        return entry ? entry.display : name;
    }

    function applyTheme(name: string): void {
        if (!name)
            return;
        Themes.apply(name);
        GlobalState.themeMenuOpen = false;
    }

    // Explicit, always-wraps cycling -- doesn't rely on ListView's own
    // built-in Up/Down handling (keyNavigationWraps was flaky in
    // practice), so top<->bottom cycling is guaranteed either way.
    function moveSelection(delta: int): void {
        const n = Themes.list.length;
        if (n === 0)
            return;
        list.currentIndex = (list.currentIndex + delta + n) % n;
    }

    Row {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        // ---- LEFT: theme list ----
        Column {
            id: leftPanel
            width: 290
            height: parent.height
            spacing: 8

            StyledText {
                text: "Themes"
                font.pixelSize: 18
                font.weight: 700
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Colors.border
            }

            ListView {
                id: list
                width: parent.width
                height: parent.height - 36
                clip: true
                spacing: 4
                model: Themes.list
                focus: true
                keyNavigationWraps: true
                highlightMoveDuration: Appearance.anim.durations.fast

                onCurrentIndexChanged: {
                    const entry = Themes.list[currentIndex];
                    if (entry)
                        root.previewTheme = entry.name;
                }

                Keys.onReturnPressed: root.applyTheme(root.previewTheme)
                Keys.onEnterPressed: root.applyTheme(root.previewTheme)
                Keys.onEscapePressed: GlobalState.themeMenuOpen = false
                Keys.onUpPressed: root.moveSelection(-1)
                Keys.onDownPressed: root.moveSelection(1)
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_J) {
                        root.moveSelection(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_K) {
                        root.moveSelection(-1);
                        event.accepted = true;
                    }
                }

                delegate: StyledRect {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property bool isActive: modelData.name === Themes.activeTheme
                    readonly property bool isPreviewed: modelData.name === root.previewTheme
                    readonly property var swatch: Themes.swatchFor(modelData.name)

                    width: list.width
                    implicitHeight: 46
                    radius: 12
                    color: row.isPreviewed ? Colors.surfaceHigh : "transparent"
                    border.width: row.isActive ? 1 : 0
                    border.color: Colors.accentDim

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            color: Colors.accent
                            opacity: row.isActive ? 1 : 0
                        }

                        StyledText {
                            width: parent.width - 8 - 6 - 3 * 16 - 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.displayFor(row.modelData.name)
                            elide: Text.ElideRight
                            font.pixelSize: 16
                            font.weight: row.isActive ? 700 : 400
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5

                            Repeater {
                                model: [row.swatch.blue, row.swatch.purple, row.swatch.accent]

                                Rectangle {
                                    required property var modelData
                                    width: 11
                                    height: 11
                                    radius: 5.5
                                    color: modelData
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.15)
                                }
                            }
                        }
                    }

                    HoverHandler {
                        onHoveredChanged: if (hovered)
                            list.currentIndex = row.index
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: root.applyTheme(row.modelData.name)
                    }
                }
            }
        }

        // ---- RIGHT: wallpaper preview ----
        StyledRect {
            id: rightPanel
            width: parent.width - leftPanel.width - parent.spacing
            height: parent.height
            radius: Appearance.rounding.small
            color: Colors.bg
            clip: true

            readonly property string wallpaper: Themes.wallpaperFor(root.previewTheme)
            readonly property var swatch: Themes.swatchFor(root.previewTheme)

            Image {
                id: preview
                anchors.fill: parent
                source: rightPanel.wallpaper ? "file://" + rightPanel.wallpaper : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.durations.normal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 10
                visible: !rightPanel.wallpaper

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "wallpaper"
                    font.pixelSize: 48
                    color: Colors.faint
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No wallpaper saved"
                    font.pixelSize: 14
                    color: Colors.faint
                }
            }

            // Legibility gradient for the bottom overlay.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * 0.42
                visible: preview.opacity > 0.01
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
                }
            }

            // Keyboard hint badge (top-right) -- mirrors the launcher's
            // footer hint so the Themes menu documents itself.
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 16
                width: hintText.implicitWidth + 20
                height: 28
                radius: 14
                color: Qt.rgba(0, 0, 0, 0.45)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)

                StyledText {
                    id: hintText
                    anchors.centerIn: parent
                    text: "↑↓/jk Select · ↵ Apply · Esc Close"
                    font.pixelSize: 12
                    color: Qt.rgba(1, 1, 1, 0.7)
                }
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 18
                spacing: 8

                Row {
                    spacing: 6
                    Repeater {
                        model: [rightPanel.swatch.blue, rightPanel.swatch.purple, rightPanel.swatch.accent]
                        Rectangle {
                            required property var modelData
                            width: 14
                            height: 14
                            radius: 7
                            color: modelData
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.2)
                        }
                    }
                }

                StyledText {
                    text: root.displayFor(root.previewTheme)
                    color: preview.opacity > 0.01 ? "#ffffff" : Colors.text
                    font.pixelSize: 24
                    font.weight: 700
                }

                StyledText {
                    width: rightPanel.width - 36
                    text: rightPanel.wallpaper ? rightPanel.wallpaper.split("/").pop() : "Select a theme to apply it"
                    elide: Text.ElideRight
                    font.pixelSize: 12
                    color: preview.opacity > 0.01 ? Qt.rgba(1, 1, 1, 0.65) : Colors.subtext
                }
            }
        }
    }
}
