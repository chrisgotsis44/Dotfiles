pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.config
import qs.components
import qs.services

// The StatusNotifierItem tray, as a bare row of icons.
//
// Collapses out entirely when nothing is registered -- a Positioner skips
// invisible children including their spacing, so both callers (the hover
// strip and Big Island's right cluster) can include it unconditionally
// and it simply isn't there on a machine running no tray apps. Same
// contract as BatteryPill on a desktop.
//
// Menus deliberately do NOT go through the item's own display() or a
// QsMenuAnchor. Both open a real platform popup window: unthemed, drawn
// by Qt rather than by us, and against the island's whole premise that
// there are no popup windows. Clicking an item instead parks its
// QsMenuHandle on GlobalState and lets the island morph into the "tray"
// Section, which walks the same DBus menu with QsMenuOpener and draws it
// in the shell's own styling -- see TrayMenuContent.qml.
Row {
    id: root

    property int iconSize: 18
    property int itemSize: 24

    spacing: 8
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        Item {
            id: entry

            required property SystemTrayItem modelData

            // No anchors: a Row owns its children's positions and warns
            // about vertical anchors on them. Every icon is itemSize
            // square, so the caller centres the Row as a whole instead.
            width: root.itemSize
            height: root.itemSize

            StyledRect {
                anchors.fill: parent
                radius: width / 2
                color: press.pressed ? Colors.surfacePressed
                     : hover.hovered ? Colors.surfaceHover
                     : "transparent"
            }

            // Passive is the SNI spec's "there is nothing to show" state,
            // but far too many apps (Steam, and most Electron wrappers)
            // register Passive and never move off it -- filtering on it
            // hides exactly the icons whose absence people notice. So
            // everything registered is drawn, and Passive is only dimmed.
            IconImage {
                anchors.centerIn: parent
                implicitSize: root.iconSize
                source: entry.modelData.icon
                asynchronous: true
                opacity: entry.modelData.status === Status.Passive ? 0.6 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.durations.fast
                    }
                }
            }

            // NeedsAttention is the one status worth spending pixels on:
            // it is the app saying something is waiting. Ringed in the
            // island's own background so it reads as a badge sitting on
            // the icon rather than a stray dot beside it.
            Rectangle {
                visible: entry.modelData.status === Status.NeedsAttention
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 1
                width: 7
                height: 7
                radius: 3.5
                color: Colors.accent
                border.width: 1.5
                border.color: Colors.island
            }

            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }

            // onlyMenu means the app has told us a left click has no
            // primary action and the menu IS the interaction -- calling
            // activate() on one of those does nothing at all, which reads
            // as a dead icon.
            TapHandler {
                id: press
                acceptedButtons: Qt.LeftButton
                onTapped: {
                    if (entry.modelData.onlyMenu)
                        GlobalState.openTrayMenu(entry.modelData);
                    else
                        entry.modelData.activate();
                }
            }

            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: GlobalState.openTrayMenu(entry.modelData)
            }

            TapHandler {
                acceptedButtons: Qt.MiddleButton
                onTapped: entry.modelData.secondaryActivate()
            }

            // Volume-style scroll passthrough (mixer applets and the like
            // use it). The second argument is the *horizontal* flag, so a
            // vertical wheel has to report false even though the delta it
            // carries is the y one.
            WheelHandler {
                onWheel: event => {
                    if (event.angleDelta.y !== 0)
                        entry.modelData.scroll(event.angleDelta.y, false);
                    else if (event.angleDelta.x !== 0)
                        entry.modelData.scroll(event.angleDelta.x, true);
                }
            }

            scale: press.pressed ? 0.9 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.durations.fast
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }
        }
    }
}
