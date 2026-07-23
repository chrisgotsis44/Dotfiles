pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components
import qs.modules.controlcenter
import qs.modules.launcher
import qs.modules.calendar
import qs.modules.power
import qs.modules.clipboard
import qs.modules.thememenu
import qs.modules.dashboard
import qs.modules.polkit

// The Dynamic Island — one pill that IS every surface of the shell.
//
// There are no popup windows: the Control Center, launcher, calendar and
// power menu all render *inside* the island, and the island morphs its
// width, height and corner radius around whichever content is active.
//
// LAYERING — deliberately non-intrusive: the window sits on
// WlrLayer.Top with a fixed exclusiveZone (so tiled/maximized windows
// never resize when the island grows — expanded states just overlay
// content, like the real Dynamic Island), an input mask limited to the
// pill (everything else is click-through), and NO keyboard focus except
// while the launcher's search field is open. It only jumps to
// WlrLayer.Overlay while a menu is open, so the click-away catcher
// (Top layer) can't cover it.
//
// CURSOR-AWARE — one Bar exists per monitor, but only the one on the
// monitor the cursor is on (Hyprland's focused monitor) reacts: hover
// expansion, menus, the OSD and notifications all morph on that island
// alone; the others stay as idle clocks.
//
// State machine (priority order — first match wins):
//   "polkit"         a polkit authentication request is pending; outranks
//                    even a notification since it's blocking and needs an
//                    explicit response (password + Authenticate, or Cancel)
//   "notif"          a notification just arrived; preempts ANYTHING else,
//                    then the island morphs back to the previous state
//   "osd"            volume changed in the last 1.5 s
//   "controlcenter"  \
//   "launcher"        \  menus — the island morphs into a large panel
//   "power"           |  (GlobalState.*Open, mutually exclusive)
//   "calendar"        |
//   "thememenu"       /
//   "dashboard"       /
//   "bigisland"      SUPER+B — static wide layout (workspaces | clock |
//                    collapsible tray), replaces hover/idle entirely
//                    until toggled off again
//   "hover"          pointer is over the pill → extended strip layout
//   "idle"           just the clock
//
// How the transitions work: each state maps to one Section (a Loader
// that crossfades with opacity + scale). The island binds its implicit
// size to the *active* section, so a state change retargets the size
// bindings, and the Behaviors below turn that jump into a smooth morph.
// Pill-to-pill morphs use an overshoot curve for the springy island
// feel; morphs into a menu use a pure decelerate curve (same family as
// Easing.InOutExpo — steep start, asymptotic settle) because a 700px
// panel overshooting looks unhinged. Corner radius morphs alongside:
// capsule (height/2) for pill states, fixed rounding for menus.
PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    // True while the cursor is on this monitor.
    readonly property bool onActiveMonitor: {
        if (Quickshell.screens.length <= 1)
            return true;
        if (Hyprland.focusedMonitor) {
            const mon = Hyprland.monitorFor(root.screen);
            if (mon && mon.name === Hyprland.focusedMonitor.name)
                return true;
        }
        if (Quickshell.cursorScreen) {
            if (root.screen.name === Quickshell.cursorScreen.name)
                return true;
        }
        return false;
    }

    anchors {
        top: true
        left: true
        right: true
    }
    // Headroom for the tallest menu morph. This is a hard ceiling, not
    // just a starting size -- content taller than this gets clipped by
    // the Wayland surface boundary itself, no matter how well an inner
    // animation is timed against the island's own resize (that's a
    // separate concern, handled by Appearance.anim.durations.menu).
    // The Dashboard's Customize tab is the tallest case: each
    // EffectRow's submenu expands independently, not as a shared
    // accordion, so several can be open at once -- Blur+Shadows+
    // Borders+Gaps+Opacity+Rounding all expanded simultaneously,
    // plus the quick-action buttons and animation presets above them,
    // comfortably exceeds 900px. The window itself is transparent and
    // only the island (its own ClippingRectangle) is ever visible, so
    // there's no real cost to over-provisioning rather than tuning
    // this to the exact pixel.
    implicitHeight: 1500
    exclusiveZone: Appearance.bar.exclusiveZone
    color: "transparent"

    WlrLayershell.layer: GlobalState.anyMenuOpen && onActiveMonitor ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "qs-island-bar"
    // Keyboard is only ever grabbed for typing into the launcher/clipboard
    // search or navigating the Themes list, and only on the island
    // actually showing it.
    WlrLayershell.keyboardFocus: (GlobalState.launcherOpen || GlobalState.clipboardOpen || GlobalState.themeMenuOpen || GlobalState.polkitOpen) && onActiveMonitor
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Only the pill takes input; the rest of the strip is click-through.
    mask: Region {
        item: island
    }

    readonly property string islandState: {
        // Everything interactive (menus, hover, OSD, notifications) only
        // happens on the cursor's monitor. Big Island mode is the one
        // exception -- it's a persistent layout choice, not a cursor
        // following interaction, so it still shows on every OTHER monitor
        // too (just without taking part in the interactive priority chain
        // below, since nothing on an inactive monitor can preempt it).
        if (!onActiveMonitor)
            return GlobalState.bigIslandMode ? "bigisland" : "idle";
        if (GlobalState.polkitOpen)
            return "polkit";
        if (GlobalState.islandNotif)
            return "notif";
        if (GlobalState.osdActive)
            return "osd";
        if (GlobalState.controlCenterOpen)
            return "controlcenter";
        if (GlobalState.launcherOpen)
            return "launcher";
        if (GlobalState.clipboardOpen)
            return "clipboard";
        if (GlobalState.powerMenuOpen)
            return "power";
        if (GlobalState.calendarOpen)
            return "calendar";
        if (GlobalState.themeMenuOpen)
            return "thememenu";
        if (GlobalState.dashboardOpen)
            return "dashboard";
        // SUPER+B: statically replaces idle/hover with the wide Big
        // Island layout -- checked AFTER every menu/notif/osd state (those
        // still preempt it same as they would idle/hover) but BEFORE
        // hover, so hovering the pill no longer does anything while active.
        if (GlobalState.bigIslandMode)
            return "bigisland";
        if (hovering)
            return "hover";
        return "idle";
    }

    readonly property bool inMenu: GlobalState.anyMenuOpen && onActiveMonitor
        && islandState !== "notif" && islandState !== "osd"

    // Hover expansion with a short collapse grace so skimming the pill's
    // edge doesn't make it flutter open/closed.
    property bool hovering: false

    Timer {
        id: unhoverDelay
        interval: 200
        onTriggered: root.hovering = false
    }

    // A crossfading island section. Loaders track their item's implicit
    // size, so the island can bind to whichever section is active.
    component Section: Loader {
        required property bool shown

        anchors.centerIn: parent
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.85
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.standard
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
    }

    // ClippingRectangle, not Rectangle: mid-morph the active section is
    // often larger than the island, and clipping (with the animated
    // radius) is what makes content look like it unfurls from inside
    // the pill instead of floating on top of it.
    ClippingRectangle {
        id: island

        readonly property Item active: {
            switch (root.islandState) {
            case "polkit": return polkitSection;
            case "notif": return notifSection;
            case "osd": return osdSection;
            case "controlcenter": return ccSection;
            case "launcher": return launcherSection;
            case "clipboard": return clipboardSection;
            case "power": return powerSection;
            case "calendar": return calendarSection;
            case "thememenu": return themeMenuSection;
            case "dashboard": return dashboardSection;
            case "bigisland": return bigIslandSection;
            case "hover": return hoverSection;
            default: return idleSection;
            }
        }

        anchors.horizontalCenter: parent.horizontalCenter
        y: Appearance.bar.topMargin

        // === The morph ===
        // Size chases the active section; radius flips between capsule
        // and panel rounding. All three are driven by the Behaviors
        // below — nothing else animates the island's geometry.
        implicitWidth: active.implicitWidth + Appearance.bar.hPadding * 2
        implicitHeight: active.implicitHeight + Appearance.bar.vPadding * 2
        radius: root.inMenu ? Appearance.rounding.large : implicitHeight / 2

        color: root.islandState === "bigisland" ? Colors.islandExtended : Colors.island
        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.durations.normal
            }
        }
        border.width: 1
        // Accent rim while morphed into a menu.
        border.color: GlobalState.anyMenuOpen && root.onActiveMonitor
            ? Qt.alpha(Colors.accent, 0.45) : Colors.islandBorder

        Behavior on implicitWidth {
            NumberAnimation {
                duration: root.inMenu ? Appearance.anim.durations.menu : Appearance.anim.durations.expand
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.inMenu ? Appearance.anim.curves.emphasized : Appearance.anim.curves.expressive
            }
        }
        Behavior on implicitHeight {
            NumberAnimation {
                duration: root.inMenu ? Appearance.anim.durations.menu : Appearance.anim.durations.expand
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.inMenu ? Appearance.anim.curves.emphasized : Appearance.anim.curves.expressive
            }
        }
        Behavior on radius {
            NumberAnimation {
                duration: Appearance.anim.durations.expand
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: Appearance.anim.durations.normal
            }
        }

        HoverHandler {
            // HoverHandler (not MouseArea hover) on purpose: it stays
            // `hovered` even while child MouseAreas — sliders, buttons —
            // grab the pointer, so the island can't collapse under an
            // open menu or mid-drag.
            id: hover
            onHoveredChanged: {
                if (hovered) {
                    unhoverDelay.stop();
                    root.hovering = true;
                } else {
                    unhoverDelay.restart();
                }
            }
        }

        // Mouse bindings. Declared BEFORE the sections so every
        // interactive element inside a menu stacks above it and wins
        // the click; only presses on "dead" island area land here.
        //   Left:   toggle Control Center / dismiss notification
        //   Middle: toggle calendar
        //   Right:  nothing (power menu is IPC/keybind only)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            cursorShape: root.inMenu ? Qt.ArrowCursor : Qt.PointingHandCursor

            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton) {
                    GlobalState.calendarOpen = !GlobalState.calendarOpen;
                    return;
                }
                if (mouse.button === Qt.RightButton) {
                    // Only from the pill states -- inside an open menu the
                    // right button stays available to the menu's content.
                    if (!root.inMenu)
                        GlobalState.dashboardOpen = !GlobalState.dashboardOpen;
                    return;
                }
                // Left button
                if (root.islandState === "notif") {
                    GlobalState.dismissIslandNotif();
                    return;
                }
                if (root.islandState === "osd")
                    return;
                if (!root.inMenu)
                    GlobalState.controlCenterOpen = !GlobalState.controlCenterOpen;
            }

            onWheel: wheel => {
                if (root.islandState === "idle" || root.islandState === "hover")
                    Audio.setVolume(Audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05));
                else
                    wheel.accepted = false;
            }
        }

        // ---------------------------------------------------------- //
        //  idle — just the clock                                      //
        // ---------------------------------------------------------- //
        Section {
            id: idleSection
            shown: root.islandState === "idle"

            // Time explicitly in Adwaita Sans.
            sourceComponent: StyledText {
                text: Time.time
                font.family: Appearance.font.family
                font.pixelSize: 18
                font.weight: 800
            }
        }

        // ---------------------------------------------------------- //
        //  hover — workspaces | clock + date | weather                //
        // ---------------------------------------------------------- //
        Section {
            id: hoverSection
            shown: root.islandState === "hover"

            sourceComponent: Item {
                implicitWidth: 540
                implicitHeight: 46

                WorkspaceIndicator {
                    screen: root.modelData
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 1

                    // Time explicitly in Adwaita Sans.
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Time.time
                        font.family: Appearance.font.family
                        font.pixelSize: 17
                        font.weight: 800
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Time.dateStr
                        font.pixelSize: 11
                        color: Colors.subtext
                    }
                }

                WeatherPill {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // ---------------------------------------------------------- //
        //  bigisland — SUPER+B: workspaces | clock | collapsible tray  //
        // ---------------------------------------------------------- //
        Section {
            id: bigIslandSection
            shown: root.islandState === "bigisland"

            sourceComponent: Item {
                id: biRoot

                readonly property int outerGap: 40
                // Left and right slots are always the SAME width (whichever
                // of workspaces/the right-side row is currently wider) --
                // that's what keeps the clock genuinely centered on the
                // whole bar instead of just centered on its own leftover
                // space, which would drift off-true whenever the two sides
                // differ in width (they normally do).
                readonly property int sideSlotWidth: Math.max(wsRow.implicitWidth, rightRow.implicitWidth)

                // Spans almost the full screen width (outerGap clear on
                // each side, before the island's own hPadding on top of
                // that) instead of a tight sum-of-content pill -- "Big
                // Island" reads as a wide bar, not a scaled-up normal pill.
                // Height stays close to the idle/hover pill's own ~46px
                // total (24 + the 22px of vPadding) -- "big" means wide,
                // not thick.
                implicitWidth: root.modelData.width - outerGap * 2 - Appearance.bar.hPadding * 2
                implicitHeight: 26

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Left: this monitor's workspaces only, capped at 5.
                    // Plain mono-font numbers -- only the focused workspace
                    // gets a colored circle behind its number, the rest are
                    // just text, no chip/background.
                    Item {
                        Layout.preferredWidth: biRoot.sideSlotWidth
                        Layout.fillHeight: true

                        Row {
                            id: wsRow
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 16

                            Repeater {
                                model: [...Hyprland.workspaces.values]
                                    .filter(w => w.id > 0 && w.monitor?.name === Hyprland.monitorFor(root.modelData)?.name)
                                    .sort((a, b) => a.id - b.id)
                                    .slice(0, 5)

                                Item {
                                    id: wsItem
                                    required property var modelData
                                    readonly property bool focused: modelData.focused

                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 26
                                    height: 26

                                    Rectangle {
                                        anchors.centerIn: parent
                                        visible: wsItem.focused
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: Colors.accent
                                    }

                                    MonoText {
                                        anchors.centerIn: parent
                                        text: wsItem.modelData.id
                                        font.pixelSize: 13
                                        font.weight: 700
                                        color: wsItem.focused ? Colors.accentFg : Colors.subtext
                                    }

                                    HoverHandler {
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                    TapHandler {
                                        onTapped: Hyprland.dispatch("workspace " + wsItem.modelData.id)
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    // Center: a single-line clock, genuinely centered via
                    // the two equal-width fillWidth spacers on either side
                    // (not anchors.centerIn, which only centers relative to
                    // its own parent's box and would drift off-true if the
                    // slots either side weren't kept equal).
                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        text: Time.time
                        font.family: Appearance.font.family
                        font.pixelSize: 18
                        font.weight: 800
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    // Right: sound / battery / power modules.
                    Item {
                        Layout.preferredWidth: biRoot.sideSlotWidth
                        Layout.fillHeight: true

                        Row {
                            id: rightRow
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 16

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Audio.muted ? "volume_off" : "volume_up"
                                font.pixelSize: 18
                                color: Audio.muted ? Colors.subtext : Colors.text

                                HoverHandler {
                                    cursorShape: Qt.PointingHandCursor
                                }
                                TapHandler {
                                    onTapped: Audio.toggleMute()
                                }
                            }

                            // Only rendered when a real, physical battery is
                            // present -- Battery.available checks UPower's
                            // isLaptopBattery, so a mouse/keyboard's own
                            // battery never makes this show up on a desktop.
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                visible: Battery.available

                                MaterialIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Battery.icon
                                    font.pixelSize: 18
                                    color: Battery.charging ? Colors.accent : Colors.text
                                }
                                MonoText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Battery.percent + "%"
                                    font.pixelSize: 13
                                    font.weight: 600
                                    color: Colors.subtext
                                }
                            }

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "power_settings_new"
                                font.pixelSize: 18
                                color: Colors.danger

                                HoverHandler {
                                    cursorShape: Qt.PointingHandCursor
                                }
                                TapHandler {
                                    // Opens the existing Power Menu rather
                                    // than calling systemctl poweroff
                                    // directly -- one tap on an always
                                    // -visible icon is too easy to hit by
                                    // accident for a hard shutdown.
                                    onTapped: GlobalState.powerMenuOpen = true
                                }
                            }
                        } // rightRow
                    }
                }
            }
        }

        // ---------------------------------------------------------- //
        //  osd — volume slider                                        //
        // ---------------------------------------------------------- //
        Section {
            id: osdSection
            shown: root.islandState === "osd"

            sourceComponent: Row {
                spacing: 12

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Audio.muted ? "volume_off" : "volume_up"
                    font.pixelSize: 20
                    color: Audio.muted ? Colors.subtext : Colors.text

                    TapHandler {
                        onTapped: Audio.toggleMute()
                    }
                }

                CcSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 260
                    implicitHeight: 26
                    value: Audio.volume
                    onMoved: v => Audio.setVolume(v)
                }

                MonoText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(Audio.volume * 100) + "%"
                    width: 44
                    horizontalAlignment: Text.AlignRight
                    font.pixelSize: 14
                    font.weight: 600
                    color: Colors.subtext
                }
            }
        }

        // ---------------------------------------------------------- //
        //  polkit — pending authentication request (outranks notif)   //
        // ---------------------------------------------------------- //
        Section {
            id: polkitSection
            shown: root.islandState === "polkit"

            sourceComponent: PolkitContent {}
        }

        // ---------------------------------------------------------- //
        //  notif — icon, title, body (preempts everything)            //
        // ---------------------------------------------------------- //
        Section {
            id: notifSection
            shown: root.islandState === "notif"

            sourceComponent: Item {
                implicitWidth: 480
                implicitHeight: 48

                IconImage {
                    id: notifIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 36
                    source: {
                        const n = GlobalState.islandNotif;
                        if (!n)
                            return "";
                        if (n.image)
                            return n.image;
                        return Quickshell.iconPath(n.appIcon || "dialog-information", "dialog-information");
                    }
                }

                Column {
                    anchors.left: notifIcon.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    StyledText {
                        width: parent.width
                        text: GlobalState.islandNotif?.summary ?? ""
                        elide: Text.ElideRight
                        font.pixelSize: 15
                        font.weight: 600
                    }
                    StyledText {
                        width: parent.width
                        text: GlobalState.islandNotif?.body ?? ""
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        textFormat: Text.StyledText
                        font.pixelSize: 13
                        color: Colors.subtext
                    }
                }
            }
        }

        // ---------------------------------------------------------- //
        //  Menus — the island morphs around these                     //
        // ---------------------------------------------------------- //
        Section {
            id: ccSection
            shown: root.islandState === "controlcenter"

            sourceComponent: ControlCenterContent {}
        }

        Section {
            id: launcherSection
            shown: root.islandState === "launcher"

            sourceComponent: LauncherContent {}
        }

        Section {
            id: clipboardSection
            shown: root.islandState === "clipboard"

            sourceComponent: ClipboardManager {}
        }

        Section {
            id: calendarSection
            shown: root.islandState === "calendar"

            sourceComponent: CalendarContent {}
        }

        Section {
            id: powerSection
            shown: root.islandState === "power"

            sourceComponent: PowerMenuContent {}
        }

        Section {
            id: themeMenuSection
            shown: root.islandState === "thememenu"

            sourceComponent: ThemeMenuContent {}
        }

        Section {
            id: dashboardSection
            shown: root.islandState === "dashboard"

            sourceComponent: Dashboard {}
        }
    }
}
