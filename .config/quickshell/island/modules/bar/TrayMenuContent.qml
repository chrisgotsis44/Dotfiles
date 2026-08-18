pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// A tray item's DBus menu, drawn inside the island.
//
// The alternative was the item's own display() / QsMenuAnchor, which
// hands the menu to Qt and gets back a platform popup window -- a second
// surface, in someone else's styling, floating next to a shell whose one
// rule is that there are no popup windows. QsMenuOpener gives us the
// same menu as a model instead (text, icon, separators, check state,
// submenus) and we draw it ourselves.
//
// Submenus DRILL rather than cascade. A cascading menu needs somewhere to
// put the second column, and the island is a centred pill with no notion
// of "to the right of" -- so entering a submenu replaces the list and
// puts a Back row at the top, and the island morphs its height to match.
Item {
    id: root

    // Deep menus (Steam's, notably) would otherwise push the island past
    // the PanelWindow's implicitHeight ceiling and get clipped by the
    // Wayland surface itself, which no amount of animation timing fixes.
    readonly property int maxListHeight: 460
    readonly property int rowHeight: 34

    // Drill-down stack of QsMenuHandles: [0] is the item's root menu and
    // each submenu entered is appended. Only the last one is ever shown.
    property var stack: []
    readonly property var current: stack.length > 0 ? stack[stack.length - 1] : null
    readonly property bool nested: stack.length > 1

    implicitWidth: 300
    implicitHeight: header.height + 6 + Math.min(list.contentHeight, root.maxListHeight)

    function reset(): void {
        stack = GlobalState.trayMenuHandle ? [GlobalState.trayMenuHandle] : [];
    }

    // The Section that hosts this latches loaded on first show and is
    // never torn down, so a second tray item's menu arrives as a property
    // change on an already-built tree rather than a fresh construction.
    // Keying the reset on trayMenuOpen rather than on the handle covers
    // reopening the SAME item too -- that changes no handle, and without
    // this you would come back to whatever submenu you left it in.
    Connections {
        target: GlobalState

        function onTrayMenuOpenChanged(): void {
            if (GlobalState.trayMenuOpen)
                root.reset();
        }
    }

    // First open: the state change above has already happened by the time
    // the Loader builds this.
    Component.onCompleted: root.reset()

    QsMenuOpener {
        id: opener
        menu: root.current
    }

    // Header: the item's name, or a Back row once drilled in.
    Item {
        id: header
        width: parent.width
        height: 32

        StyledRect {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: root.nested && backHover.hovered ? Colors.surfaceHover : "transparent"
        }

        MaterialIcon {
            id: backIcon
            visible: root.nested
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: "chevron_left"
            font.pixelSize: Appearance.font.px(18)
            color: Colors.subtext
        }

        StyledText {
            anchors.left: root.nested ? backIcon.right : parent.left
            anchors.leftMargin: root.nested ? 2 : 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.nested ? "Back" : GlobalState.trayMenuTitle
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.px(12)
            font.weight: 700
            color: Colors.subtext
        }

        HoverHandler {
            id: backHover
            enabled: root.nested
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: root.nested
            onTapped: root.stack = root.stack.slice(0, -1)
        }
    }

    ListView {
        id: list

        anchors.top: header.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.min(contentHeight, root.maxListHeight)

        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        spacing: 1

        model: opener.children

        delegate: Item {
            id: entry

            required property QsMenuEntry modelData

            // Every read below goes through these rather than touching
            // modelData directly. A DBus menu updates itself in place --
            // nm-applet rewrites its whole list as networks come and go --
            // and QsMenuEntry objects are destroyed on the C++ side while
            // the ListView still holds delegates bound to them, so
            // modelData is briefly null and every direct property read
            // throws a TypeError.
            readonly property bool isSep: modelData?.isSeparator ?? false
            readonly property bool isEnabled: modelData?.enabled ?? false
            readonly property string label: modelData?.text ?? ""
            readonly property int btnType: modelData?.buttonType ?? QsMenuButtonType.None
            readonly property int chk: modelData?.checkState ?? Qt.Unchecked
            readonly property bool kids: modelData?.hasChildren ?? false
            readonly property string iconSource: modelData?.icon ?? ""

            width: list.width
            height: isSep ? 9 : root.rowHeight

            Rectangle {
                visible: entry.isSep
                anchors.centerIn: parent
                width: parent.width - 16
                height: 1
                color: Colors.border
            }

            StyledRect {
                visible: !entry.isSep
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: !entry.isEnabled ? "transparent"
                     : rowTap.pressed ? Colors.surfacePressed
                     : rowHover.hovered ? Colors.surfaceHover
                     : "transparent"
            }

            RowLayout {
                visible: !entry.isSep
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Leading slot, always present so labels line up down the
                // column whether or not a given row has anything in it.
                // Carries the check state when there is one, otherwise the
                // entry's icon.
                Item {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: entry.btnType !== QsMenuButtonType.None
                        text: {
                            if (entry.btnType === QsMenuButtonType.CheckBox)
                                return entry.chk === Qt.Checked ? "check_box" : "check_box_outline_blank";
                            return entry.chk === Qt.Checked ? "radio_button_checked" : "radio_button_unchecked";
                        }
                        font.pixelSize: Appearance.font.px(16)
                        color: entry.chk === Qt.Checked ? Colors.accent : Colors.subtext
                    }

                    IconImage {
                        anchors.centerIn: parent
                        visible: entry.btnType === QsMenuButtonType.None
                            && entry.iconSource !== ""
                        implicitSize: 16
                        source: entry.iconSource
                        asynchronous: true
                    }
                }

                // Second slot, and it collapses to nothing unless the entry
                // has BOTH a check state and an icon. Checkable rows with a
                // meaningful icon are real -- a colour picker's palette is
                // exactly that, swatch plus tick -- and folding both into
                // one slot silently drops the swatch, which is the half
                // that tells you which entry you are looking at.
                IconImage {
                    visible: entry.btnType !== QsMenuButtonType.None
                        && entry.iconSource !== ""
                    Layout.preferredWidth: visible ? 16 : 0
                    Layout.preferredHeight: 16
                    implicitSize: 16
                    source: entry.iconSource
                    asynchronous: true
                }

                StyledText {
                    Layout.fillWidth: true
                    // Rendered verbatim, mnemonic underscores and all.
                    // Stripping them is the obvious-looking thing to do
                    // and it is wrong: almost nothing on this bus actually
                    // sends mnemonics, while plenty of entries are user
                    // data with real underscores in them. Stripping turned
                    // the SSID "Chris_Internet-Panw_5G" into
                    // "ChrisInternet-Panw5G" -- a corrupted name is far
                    // worse than a stray underscore on the rare app that
                    // does send one.
                    text: entry.label
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.px(13)
                    color: entry.isEnabled ? Colors.text : Colors.faint
                }

                MaterialIcon {
                    visible: entry.kids
                    Layout.preferredWidth: visible ? 16 : 0
                    text: "chevron_right"
                    font.pixelSize: Appearance.font.px(16)
                    color: Colors.subtext
                }
            }

            HoverHandler {
                id: rowHover
                enabled: entry.isEnabled && !entry.isSep
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: rowTap
                enabled: entry.isEnabled && !entry.isSep
                onTapped: {
                    if (!entry.modelData)
                        return;
                    if (entry.kids) {
                        root.stack = [...root.stack, entry.modelData];
                        return;
                    }
                    entry.modelData.triggered();
                    // Checkboxes and radios are the one case where staying
                    // open is right -- they are settings you may want to
                    // flip several of, and the row updates in place.
                    if (entry.btnType === QsMenuButtonType.None)
                        GlobalState.trayMenuOpen = false;
                }
            }
        }
    }
}
