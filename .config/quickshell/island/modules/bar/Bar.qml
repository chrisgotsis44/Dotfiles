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
import qs.modules.media

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
// pill (everything else is click-through), and NO keyboard focus at all
// while idle/hovering. It only jumps to WlrLayer.Overlay while a menu is
// open, so the click-away catcher (Top layer) can't cover it, and takes
// Exclusive keyboard focus for as long as any menu stays open (see
// WlrLayershell.keyboardFocus below for why every menu needs Exclusive,
// not just the text-input ones).
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
//   "thememenu"       |
//   "dashboard"       /
//   "media"          /   middle-click — universal MPRIS player popup
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
    // Keyboard focus is only ever granted on the island actually showing
    // the open menu (onActiveMonitor). Every open menu gets Exclusive,
    // not just the ones that take real text input (launcher/clipboard/
    // theme menu/polkit) -- an earlier version left Control Center/
    // calendar/power/dashboard on OnDemand to avoid stealing focus from
    // whatever window was active, but OnDemand only grants focus in
    // response to a click *on the already-interactive surface*, and the
    // click that opens one of these menus is the click that toggles
    // controlCenterOpen etc. in the first place -- by the time the
    // surface recommits with keyboard-interactivity=on-demand, that
    // click has already happened, so the compositor never hands over
    // focus and Escape silently does nothing until a second, separate
    // click lands inside the panel. Exclusive is granted immediately on
    // commit, no follow-up click required, which is what actually makes
    // Escape (and the Shortcut below) reliable. Same fix already used by
    // the wallpaper picker in shell.qml.
    WlrLayershell.keyboardFocus: {
        if (!onActiveMonitor)
            return WlrKeyboardFocus.None;
        if (GlobalState.anyMenuOpen || Windows.open)
            return WlrKeyboardFocus.Exclusive;
        return WlrKeyboardFocus.None;
    }

    // Only the pill takes input; the rest of the strip is click-through.
    mask: Region {
        item: island
    }

    // Global Escape fallback. The launcher/clipboard/theme menu/polkit
    // also close themselves via Keys.onEscapePressed on their own focused
    // search field, but Control Center, calendar, power menu and the
    // dashboard have no such field to attach one to -- this is what
    // covers Escape for all of them (and doubles as a catch-all for the
    // text-input menus too), now that keyboardFocus above guarantees
    // this surface actually has focus to receive it.
    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: GlobalState.anyMenuOpen && root.onActiveMonitor
        onActivated: GlobalState.closeAllMenus()
    }

    // Committing on ALT release used to be a Hyprland release-bind firing
    // `switcher select` over IPC. Every ipc call is a separate ~40ms
    // process with no ordering guarantee, so a quick ALT+Tab raced its own
    // release: `select` frequently arrived FIRST, no-oped against a
    // still-closed switcher, and then `cycle` opened it -- leaving the
    // switcher up having never committed, which is exactly why ALT+Tab
    // behaved identically to SUPER+Tab and neither ever switched a window.
    //
    // The island already holds exclusive keyboard focus while the switcher
    // is up (see keyboardFocus above), so it can observe the release
    // itself: in order, in-process, with nothing to race.
    Item {
        id: switcherKeys

        focus: Windows.open && root.onActiveMonitor

        Keys.onReleased: event => {
            // Meta deliberately excluded: SUPER+Tab is the sticky gesture,
            // and committing on its release would collapse the two into
            // one behaviour again.
            if (Windows.open && event.key === Qt.Key_Alt) {
                Windows.select();
                event.accepted = true;
            }
        }
    }

    Connections {
        target: Windows

        function onOpenChanged(): void {
            if (Windows.open && root.onActiveMonitor)
                switcherKeys.forceActiveFocus();
        }
    }

    // The switcher is keyboard-driven, and Hyprland's own binds only cover
    // the modifier combinations. These cover the keys you press once it is
    // already up, which is why the island takes Exclusive focus above while
    // Windows.open.
    Shortcut {
        sequences: ["Return", "Enter"]
        context: Qt.WindowShortcut
        enabled: Windows.open && root.onActiveMonitor
        onActivated: Windows.select()
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: Windows.open && root.onActiveMonitor
        onActivated: Windows.close()
    }

    Shortcut {
        sequences: ["Tab", "Right"]
        context: Qt.WindowShortcut
        enabled: Windows.open && root.onActiveMonitor
        onActivated: Windows.next()
    }

    Shortcut {
        sequences: ["Shift+Tab", "Left"]
        context: Qt.WindowShortcut
        enabled: Windows.open && root.onActiveMonitor
        onActivated: Windows.prev()
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
        // Above the menus: the switcher is a momentary keyboard gesture,
        // and having it silently do nothing because the Control Center
        // happened to be open would be worse than covering the menu.
        if (Windows.open)
            return "switcher";
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
        if (GlobalState.mediaPlayerOpen)
            return "media";
        // SUPER+B: statically replaces idle/hover with the wide Big
        // Island layout -- checked AFTER every menu/notif/osd state (those
        // still preempt it same as they would idle/hover) but BEFORE
        // hover, so hovering the pill no longer does anything while active.
        if (GlobalState.bigIslandMode)
            return "bigisland";
        // Hovering while something is live expands into the activity
        // rather than the usual workspaces/date/weather view: the pill was
        // already advertising it, so that is what the hover is reaching
        // for. Falls back to the normal hover view the moment nothing is
        // running.
        if (hovering && Activities.any)
            return "activity";
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
    //
    // LAZY, THEN STICKY: a section's content is built the first time its
    // state is actually entered, and kept alive from then on. Loader
    // instantiates `sourceComponent` immediately unless told otherwise,
    // which meant every menu -- Dashboard, Control Center, the media
    // popup, the theme menu -- was fully constructed at startup, on
    // EVERY monitor, for UI the user may never open. Keeping them loaded
    // once opened (rather than unloading on close) is the deliberate
    // half of the trade: reopening stays instant and menus keep their
    // scroll position / selected tab, we just no longer pay for them up
    // front.
    component Section: Loader {
        required property bool shown

        // Latches on first show; the binding below never goes back to
        // false, so nothing is ever torn down mid-crossfade either.
        property bool everShown: false
        onShownChanged: if (shown) everShown = true
        // `shown` is already true at construction for the initial state
        // (idle), which fires no onShownChanged -- catch that here.
        Component.onCompleted: if (shown) everShown = true

        active: everShown

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
            case "media": return mediaSection;
            case "bigisland": return bigIslandSection;
            case "switcher": return switcherSection;
            case "activity": return activitySection;
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
        // Accent rim while morphed into a menu. "media" used to be
        // excluded here: that popup's background was a feathered mask
        // fading to transparent inside the island's own bounds, so the
        // rim sat outside the faded content and read as an unwanted ring
        // around it. The popup now paints an opaque surface right out to
        // the island's edge, so the rim lands on the card itself and
        // belongs again, exactly like every other menu.
        border.color: GlobalState.anyMenuOpen && root.onActiveMonitor
            ? Qt.alpha(Colors.accent, 0.45)
            : Colors.islandBorder

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
        //   Middle: toggle media player popup (calendar moved to SUPER+K)
        //   Right:  toggle System Dashboard
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            cursorShape: root.inMenu ? Qt.ArrowCursor : Qt.PointingHandCursor

            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton) {
                    // Same in-menu guard as right-click: inside an open
                    // menu the middle button stays available to content.
                    if (!root.inMenu)
                        GlobalState.mediaPlayerOpen = !GlobalState.mediaPlayerOpen;
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
        //  idle — the clock, plus cover art + spectrum while playing   //
        // ---------------------------------------------------------- //
        Section {
            id: idleSection
            shown: root.islandState === "idle"

            sourceComponent: Item {
                id: idleContent

                // Art and spectrum only EXIST while something is
                // playing. When they don't, this collapses to exactly
                // the clock-only pill it has always been, and the
                // island's own implicitWidth/Height Behaviors do the
                // growing and shrinking -- the visualizer appearing IS
                // the morph, not a separate animation.
                // A live activity outranks the visualizer for the pill's
                // flanks. Both want the same space, and an activity is
                // actionable where the spectrum is decoration -- so while
                // one is running the art and bars step aside entirely
                // rather than the two trying to share.
                readonly property bool activity: Activities.any
                readonly property bool playing: !idleContent.activity && Cava.available && Media.isPlaying
                readonly property bool hasArt: idleContent.playing && Media.artUrl !== "" && art.status === Image.Ready

                // Art is deliberately LARGER than the content box it
                // sits in. The pill carries 11px of vertical padding
                // around this item, so art can overspill the 22px box
                // into that padding and still sit inside the capsule
                // with room to spare -- what actually made the pill grow
                // taller before was letting artSize drive
                // implicitHeight, not the art itself. Keep this under
                // (contentHeight + 2 * Appearance.bar.vPadding) = 44 or
                // the island really will have to stretch.
                readonly property int artSize: 28
                readonly property int barWidth: 3
                readonly property int barGap: 2

                // The two inner gaps are deliberately NOT equal. The
                // spectrum needs air because its outermost bars sit at
                // near-zero most of the time, so the block reads as
                // starting closer to the clock than it measures; the art
                // is a solid square and reads exactly where it is.
                //
                // gapArt also positions the art within the slack its
                // flank carries (see sideTotal): raising it slides the
                // art LEFT, toward the capsule's cap, without moving the
                // clock, the spectrum or the pill's width -- it only
                // trades outer padding for inner gap. It stays free to
                // do that while gapArt + artSize <= sideTotal (50).
                // real, not int: a fractional gap would otherwise be
                // rounded away on assignment.
                readonly property real gapArt: 15.5
                readonly property int gapSpec: 12

                // Explicit width, computed rather than measured off the
                // children, so both flanks are exact by construction.
                readonly property real specWidth: Cava.bars * 2 * barWidth + (Cava.bars * 2 - 1) * barGap

                // The clock is anchored to the centre and NEVER moves.
                // With unequal gaps that only holds if each flank is
                // given the same TOTAL width -- so the wider of the two
                // (gap + content) sets it, and the art side takes the
                // remainder as slack at its outer end, against the
                // capsule's rounded cap where it reads as padding rather
                // than as a hole. The pill still grows outward from the
                // clock in both directions at once.
                readonly property real gapChip: 14
                readonly property real chipBlock: idleContent.activity ? chip.implicitWidth + gapChip : 0

                readonly property real sideTotal: playing
                    ? Math.max(gapArt + artSize, gapSpec + specWidth)
                    : 0

                implicitWidth: clock.implicitWidth + 2 * sideTotal + chipBlock
                // Never varies: the pill grows sideways only, and its
                // height stays exactly what the idle clock-only capsule
                // has always been, playing or not.
                implicitHeight: clock.implicitHeight

                // Time explicitly in Adwaita Sans.
                //
                // The clock is centred, EXCEPT while an activity chip is
                // up: then it slides right by half the chip's block so the
                // chip and clock are centred together as one group. The
                // alternative -- keeping the clock nailed to the middle
                // and letting the right flank carry matching slack, which
                // is what the visualizer does -- leaves an obviously empty
                // right side, because unlike the visualizer there is
                // nothing over there to balance it.
                StyledText {
                    id: clock
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: idleContent.chipBlock / 2
                    text: Time.time
                    font.family: Appearance.font.family
                    font.pixelSize: 18
                    font.weight: 800

                    Behavior on anchors.horizontalCenterOffset {
                        NumberAnimation {
                            duration: Appearance.anim.durations.normal
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.anim.curves.emphasized
                        }
                    }
                }

                // Live activity chip: glyph + one live value, anchored off
                // the clock so its gap is exactly gapChip no matter how
                // much slack the flank carries.
                Row {
                    id: chip
                    anchors.right: clock.left
                    anchors.rightMargin: idleContent.gapChip
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    visible: idleContent.activity

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Activities.primary?.icon ?? "bolt"
                        font.pixelSize: 16
                        color: Colors.accent
                    }

                    MonoText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Activities.primary?.value ?? ""
                        visible: text !== ""
                        font.pixelSize: 14
                        font.weight: 700
                        color: Colors.accent
                    }

                    // Only when something is queued behind the one on
                    // show -- otherwise the chip claims a count of one.
                    MonoText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `+${Activities.count - 1}`
                        visible: Activities.count > 1
                        font.pixelSize: 11
                        font.weight: 700
                        color: Colors.subtext
                    }
                }

                // Cover art, anchored straight off the clock rather than
                // centred in a slot: that pins the art-to-clock gap at
                // exactly gapArt regardless of how much slack the flank
                // is carrying, so widening the spectrum's gap can't drag
                // the art away from the clock too.
                ClippingRectangle {
                    anchors.right: clock.left
                    anchors.rightMargin: idleContent.gapArt
                    anchors.verticalCenter: parent.verticalCenter
                    width: idleContent.artSize
                    height: idleContent.artSize
                    radius: 7
                    color: Colors.surfaceHigh
                    visible: idleContent.hasArt

                    Image {
                        id: art
                        anchors.fill: parent
                        source: Media.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 96
                        sourceSize.height: 96
                    }
                }

                // Right slot: cava's values drawn mirrored, so the
                // lowest band sits in the middle and treble runs out to
                // both edges -- symmetric, so it reads as one object on
                // the pill rather than as a chart lying on it.
                Item {
                    anchors.left: clock.right
                    anchors.leftMargin: idleContent.gapSpec
                    anchors.verticalCenter: parent.verticalCenter
                    width: idleContent.specWidth
                    height: parent.height
                    visible: idleContent.playing

                    Row {
                        anchors.centerIn: parent
                        spacing: idleContent.barGap

                        Repeater {
                            model: Cava.bars * 2

                            Rectangle {
                                required property int index

                                // Mirror: the first half counts down to
                                // the lowest band, the second half back
                                // up.
                                readonly property int band: index < Cava.bars
                                    ? Cava.bars - 1 - index
                                    : index - Cava.bars
                                readonly property real level: Cava.levels[band] ?? 0

                                width: idleContent.barWidth
                                radius: width / 2
                                // Never fully collapses: a row of dots at
                                // silence reads as a resting visualizer,
                                // an empty gap reads as broken.
                                height: Math.max(idleContent.barWidth, level * idleContent.height)
                                anchors.verticalCenter: parent.verticalCenter
                                color: Colors.accent
                                // No Behavior on height: cava already
                                // emits at 60fps, so animating between
                                // frames would only lag behind the audio.
                            }
                        }
                    }
                }
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

                // Right-side group: battery (laptops only) + weather.
                // BatteryPill collapses to nothing when there's no
                // physical battery, so the weather pill just hugs the
                // right edge on its own, alignment intact.
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    BatteryPill {
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    WeatherPill {
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // ---------------------------------------------------------- //
        //  switcher — SUPER+Tab / ALT+Tab window picker                //
        // ---------------------------------------------------------- //
        Section {
            id: switcherSection
            shown: root.islandState === "switcher"

            sourceComponent: WindowSwitcher {}
        }

        // ---------------------------------------------------------- //
        //  activity — hover while something live is running            //
        // ---------------------------------------------------------- //
        Section {
            id: activitySection
            shown: root.islandState === "activity"

            // Fixed width rather than measured: the rows carry elided text
            // and a stretched progress track, so letting them size the
            // island would make it breathe every time a subtitle or a
            // countdown value changed width. It has to be declared on an
            // Item wrapper -- the island binds to implicitWidth, and a
            // Column derives that from its children, which here take their
            // width FROM the column.
            sourceComponent: Item {
                implicitWidth: 480
                implicitHeight: rows.implicitHeight

                Column {
                    id: rows
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: Activities.list

                        ActivityRow {
                            required property var modelData

                            width: rows.width
                            activity: modelData
                        }
                    }
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
                                // ScriptModel for the same reason as
                                // WorkspaceIndicator: a bare array
                                // expression rebuilds every delegate on
                                // any workspace add/remove.
                                model: ScriptModel {
                                    values: [...Hyprland.workspaces.values]
                                        .filter(w => w.id > 0 && w.monitor?.name === Hyprland.monitorFor(root.modelData)?.name)
                                        .sort((a, b) => a.id - b.id)
                                        .slice(0, 5)
                                }

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

                            // Collapses out entirely on a desktop; see
                            // BatteryPill.qml.
                            BatteryPill {
                                anchors.verticalCenter: parent.verticalCenter
                                iconSize: 18
                                textSize: 13
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

        Section {
            id: mediaSection
            shown: root.islandState === "media"

            sourceComponent: MediaPlayerPopup {}
        }
    }
}
