import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.services
import qs.modules.bar
import qs.modules.wallpaper

ShellRoot {
    // One island bar per screen. Every menu (Control Center, launcher,
    // calendar, power) lives INSIDE the island — there are no popup
    // windows, the island morphs around whatever is open.
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    // The wallpaper picker (SUPER+SHIFT+W) -- unlike every menu above, it
    // does NOT morph inside the island pill. It's the same full-screen
    // overlay it always was as a standalone `quickshell -p` app (see
    // modules/wallpaper/WallpaperPicker.qml); it just lives in this
    // process now instead of being spawned as a separate one each time.
    PanelWindow {
        visible: GlobalState.wallpaperPickerOpen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "qs-island-wallpaper-picker"

        WallpaperPicker {
            anchors.fill: parent
            focus: true
        }
    }

    // Full-screen invisible layer that closes any open menu when you
    // click outside the island. Sits on the Top layer; the bar jumps to
    // the Overlay layer while a menu is open, so the island always
    // stacks above this catcher.
    PanelWindow {
        visible: GlobalState.anyMenuOpen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-island-dismiss"

        MouseArea {
            anchors.fill: parent
            onPressed: GlobalState.closeAllMenus()
        }
    }

    // External control:  qs -c island ipc call shell <function>
    IpcHandler {
        target: "shell"

        function toggleControlCenter(): void {
            GlobalState.controlCenterOpen = !GlobalState.controlCenterOpen;
        }
        function toggleLauncher(): void {
            GlobalState.launcherOpen = !GlobalState.launcherOpen;
        }
        function togglePowerMenu(): void {
            GlobalState.powerMenuOpen = !GlobalState.powerMenuOpen;
        }
        function toggleCalendar(): void {
            GlobalState.calendarOpen = !GlobalState.calendarOpen;
        }
        function toggleClipboard(): void {
            GlobalState.clipboardOpen = !GlobalState.clipboardOpen;
        }
        function toggleThemeMenu(): void {
            GlobalState.themeMenuOpen = !GlobalState.themeMenuOpen;
        }
        // Big Island mode: a static, wide three-section layout (workspaces
        // | clock | collapsible tray) that overrides hover-to-expand.
        //   bind = SUPER, B, exec, qs -c island ipc call shell toggleBigIsland
        function toggleBigIsland(): void {
            GlobalState.toggleBigIslandMode();
        }
        // System Dashboard (Customize / Performance). Hyprland triggers:
        //   bind = SUPER, M, exec, qs -c island ipc call shell toggleDashboard
        //   bind = SUPER SHIFT, B, exec, qs -c island ipc call shell toggleDashboard
        // (also right-click on the pill outside a menu, see Bar.qml)
        function toggleDashboard(): void {
            GlobalState.dashboardOpen = !GlobalState.dashboardOpen;
        }
        function closeAll(): void {
            GlobalState.closeAllMenus();
        }
        // Full-screen wallpaper picker -- NOT part of closeAll()/anyMenuOpen,
        // see GlobalState.wallpaperPickerOpen.
        //   bind = SUPER SHIFT, W, exec, qs -c island ipc call shell toggleWallpaperPicker
        function toggleWallpaperPicker(): void {
            GlobalState.wallpaperPickerOpen = !GlobalState.wallpaperPickerOpen;
        }
    }
}
