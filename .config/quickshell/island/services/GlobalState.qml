pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import qs.config

// The single coordination point of the shell.
//
// Services (Audio, Media, Notifs, ...) own *system* state and push events
// here; GlobalState owns *UI* state — which menu the island is morphed
// into and what transient content (OSD/notification) it is flashing.
// The Bar derives its entire state machine from this singleton, so any
// widget anywhere can open/close a menu by flipping one property.
Singleton {
    id: root

    // ---------------------------------------------------------------- //
    //  Island menus (mutually exclusive — the island morphs into one)   //
    // ---------------------------------------------------------------- //
    property bool controlCenterOpen: false
    property bool launcherOpen: false
    property bool powerMenuOpen: false
    property bool calendarOpen: false
    property bool clipboardOpen: false
    property bool themeMenuOpen: false
    property bool dashboardOpen: false
    property bool mediaPlayerOpen: false
    // Character pickers, split off the launcher's old ":" prefix mode:
    // emoji on SUPER+, and Unicode symbols + Nerd Font icons on SUPER+.
    property bool emojiPickerOpen: false
    property bool glyphPickerOpen: false

    // A tray item's DBus menu, morphed into like any other menu rather
    // than opened as a platform popup -- see modules/bar/TrayMenuContent.
    // The handle is deliberately NOT cleared on close: the Section is
    // still crossfading out at that point and blanking it would empty the
    // panel mid-fade. It's replaced on the next open instead, and
    // TrayMenuContent keys its own reset off trayMenuOpen for that reason.
    property bool trayMenuOpen: false
    property var trayMenuHandle: null
    property string trayMenuTitle: ""

    function openTrayMenu(item): void {
        // hasMenu false means the app exports no menu at all; opening an
        // empty panel over the pill would just look broken.
        if (!item || !item.hasMenu)
            return;
        trayMenuHandle = item.menu;
        trayMenuTitle = item.tooltipTitle || item.title || item.id;
        trayMenuOpen = true;
    }

    // Polkit isn't a user-toggled menu -- it's driven entirely by Polkit.active
    // (an external authentication request arriving/finishing), but it still
    // needs to raise the island to the Overlay layer and be dismissible by
    // the same click-away catcher as everything else, hence folding it into
    // anyMenuOpen here rather than adding a matching toggle function.
    readonly property bool polkitOpen: Polkit.active

    readonly property bool anyMenuOpen: controlCenterOpen || launcherOpen || powerMenuOpen || calendarOpen || clipboardOpen || themeMenuOpen || dashboardOpen || mediaPlayerOpen || emojiPickerOpen || glyphPickerOpen || trayMenuOpen || polkitOpen

    function closeAllMenus(): void {
        controlCenterOpen = false;
        launcherOpen = false;
        powerMenuOpen = false;
        calendarOpen = false;
        clipboardOpen = false;
        themeMenuOpen = false;
        dashboardOpen = false;
        mediaPlayerOpen = false;
        emojiPickerOpen = false;
        glyphPickerOpen = false;
        trayMenuOpen = false;
        // Clicking away from a pending auth prompt cancels it, same as
        // clicking Cancel inside it would.
        if (Polkit.flow)
            Polkit.flow.cancelAuthenticationRequest();
    }

    // Opening one menu closes the others and clears any notification
    // pill — the user is acting, the island should follow their intent.
    function menuOpened(which: string): void {
        if (which !== "controlcenter")
            controlCenterOpen = false;
        if (which !== "launcher")
            launcherOpen = false;
        if (which !== "power")
            powerMenuOpen = false;
        if (which !== "calendar")
            calendarOpen = false;
        if (which !== "clipboard")
            clipboardOpen = false;
        if (which !== "thememenu")
            themeMenuOpen = false;
        if (which !== "dashboard")
            dashboardOpen = false;
        if (which !== "media")
            mediaPlayerOpen = false;
        if (which !== "emoji")
            emojiPickerOpen = false;
        if (which !== "glyph")
            glyphPickerOpen = false;
        if (which !== "tray")
            trayMenuOpen = false;
        dismissIslandNotif();
    }

    onControlCenterOpenChanged: if (controlCenterOpen) {
        menuOpened("controlcenter");
        osdTimer.stop();
    }
    onLauncherOpenChanged: if (launcherOpen) menuOpened("launcher")
    onPowerMenuOpenChanged: if (powerMenuOpen) menuOpened("power")
    onCalendarOpenChanged: if (calendarOpen) menuOpened("calendar")
    onClipboardOpenChanged: if (clipboardOpen) menuOpened("clipboard")
    onThemeMenuOpenChanged: if (themeMenuOpen) menuOpened("thememenu")
    onDashboardOpenChanged: if (dashboardOpen) menuOpened("dashboard")
    onMediaPlayerOpenChanged: if (mediaPlayerOpen) menuOpened("media")
    onEmojiPickerOpenChanged: if (emojiPickerOpen) menuOpened("emoji")
    onGlyphPickerOpenChanged: if (glyphPickerOpen) menuOpened("glyph")
    onTrayMenuOpenChanged: if (trayMenuOpen) menuOpened("tray")

    // ---------------------------------------------------------------- //
    //  Wallpaper picker (SUPER+SHIFT+W)                                  //
    // ---------------------------------------------------------------- //
    // Deliberately NOT one of the island menus above: it's a full-screen
    // overlay window in its own right (see WallpaperPicker in shell.qml),
    // not a Section the island pill morphs into, and it isn't dismissed
    // by the shared click-away catcher -- it has its own Escape handling.
    property bool wallpaperPickerOpen: false

    // ---------------------------------------------------------------- //
    //  Settings panel (SUPER+S)                                         //
    // ---------------------------------------------------------------- //
    // Like the wallpaper picker: its own centered overlay window (see
    // shell.qml), NOT a Section the pill morphs into, and not part of
    // anyMenuOpen. Opening it does close whatever island menu is up --
    // two competing panels of controls on screen at once is noise.
    property bool settingsOpen: false

    onSettingsOpenChanged: if (settingsOpen) closeAllMenus()

    // ---------------------------------------------------------------- //
    //  Control Center toggles                                           //
    // ---------------------------------------------------------------- //
    property bool dnd: false        // "Peace" — mutes island notification pills
    property bool nightLight: false
    property bool keepAwake: false  // "Display"

    // Both of these change how the machine behaves and then stay that way
    // silently, which is exactly the class of thing you leave on by
    // accident -- a suppressed lock at 3am, or notifications you never
    // saw. Surfacing them as Live Activities means the pill carries a
    // standing reminder for as long as they are on, and nothing at all
    // once they are off. They are modes, not tasks, so they carry an icon
    // and no value or progress.
    //
    // Both are currently OFF. Flip either to true to bring its chip back;
    // the logic below is intact and unused rather than deleted. The
    // remove() calls stay unconditional so flipping one off at runtime
    // clears any chip it had already pushed.
    readonly property bool keepAwakeActivity: false
    readonly property bool dndActivity: false

    onKeepAwakeChanged: GlobalState.syncModeActivities()
    onDndChanged: GlobalState.syncModeActivities()

    function syncModeActivities(): void {
        if (root.keepAwake && root.keepAwakeActivity) {
            Activities.push({
                id: "keepawake",
                icon: "coffee",
                title: "Keeping awake",
                subtitle: "Sleep and lock suppressed",
                kind: "mode",
                controls: "keepawake"
            });
        } else {
            Activities.remove("keepawake");
        }

        if (root.dnd && root.dndActivity) {
            Activities.push({
                id: "dnd",
                icon: "do_not_disturb_on",
                title: "Peace",
                subtitle: "Notifications muted",
                kind: "mode",
                controls: "dnd"
            });
        } else {
            Activities.remove("dnd");
        }
    }

    // ---------------------------------------------------------------- //
    //  Big Island mode (SUPER+B)                                        //
    // ---------------------------------------------------------------- //
    // Global, not per-monitor. While true, the island statically shows
    // the wide three-section "Big Island" layout (workspaces | clock |
    // collapsible tray) on every screen instead of the idle clock, and
    // the usual hover-to-expand behavior is suppressed entirely — see
    // Bar.qml's islandState, which checks this before "hover"/"idle".
    property bool bigIslandMode: false

    function toggleBigIslandMode(): void {
        bigIslandMode = !bigIslandMode;
    }

    // Both tiles delegate to user scripts. execDetached forks the
    // process off the shell entirely — the UI never blocks on it.
    // The booleans here are optimistic UI highlights; the scripts own
    // the real system state.
    function toggleKeepAwake(): void {
        keepAwake = !keepAwake;
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/idle-inhibitor.sh"]);
    }

    function toggleNightLight(): void {
        nightLight = !nightLight;
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/night-mode.sh"]);
    }

    // ---------------------------------------------------------------- //
    //  Island transient states                                          //
    // ---------------------------------------------------------------- //
    // Priority in the Bar (highest first): notification > OSD > menu >
    // hover > idle. Notifications preempt whatever the island shows and
    // it morphs back to the previous state when the timer runs out.

    readonly property bool osdActive: osdTimer.running
    property Notification islandNotif: null

    function showOsd(): void {
        // The Control Center has its own slider on screen — don't
        // morph away from it just to show the same information.
        if (controlCenterOpen)
            return;
        osdTimer.restart();
    }

    function pushNotif(notif: Notification): void {
        if (dnd)
            return;
        islandNotif = notif;
        notifTimer.restart();
    }

    function dismissIslandNotif(): void {
        notifTimer.stop();
        islandNotif = null;
    }

    Timer {
        id: osdTimer
        interval: Config.settings.osdDurationMs
    }

    Timer {
        id: notifTimer
        interval: Config.settings.notifDurationMs
        onTriggered: root.islandNotif = null
    }
}
