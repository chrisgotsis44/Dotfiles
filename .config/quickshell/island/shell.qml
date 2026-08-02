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

        // Lazy, then sticky — same deal as the island's Sections. The
        // picker is a large tree (grid delegates, video output, three
        // FolderListModels scanning the wallpaper + thumbnail caches),
        // and a PanelWindow builds its content whether or not the window
        // is visible, so all of that was being constructed at startup for
        // a picker that only opens on SUPER+SHIFT+W. It stays loaded once
        // opened so reopening keeps its scroll position and filter.
        //
        // Constructing it already-visible is safe: the picker's own
        // onVisibleChanged only does work on the false edge (closing).
        Loader {
            id: pickerLoader
            anchors.fill: parent
            active: false
            focus: true

            Connections {
                target: GlobalState
                function onWallpaperPickerOpenChanged(): void {
                    if (GlobalState.wallpaperPickerOpen)
                        pickerLoader.active = true;
                }
            }

            sourceComponent: WallpaperPicker {
                focus: true
            }
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
        // Calendar keybind:
        //   bind = SUPER, K, exec, qs -c island ipc call shell toggleCalendar
        function toggleCalendar(): void {
            GlobalState.calendarOpen = !GlobalState.calendarOpen;
        }
        // Universal MPRIS media popup -- also middle-click on the pill.
        function toggleMediaPlayer(): void {
            GlobalState.mediaPlayerOpen = !GlobalState.mediaPlayerOpen;
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

    // Window switcher (SUPER+Tab sticky, ALT+Tab hold-to-cycle):
    //   cycle   open it, or advance if already open. NOT named `show`:
    //           that name is swallowed by Quickshell's own IPC CLI and the
    //           call silently prints the handler's usage instead of running.
    //   next / prev / select / close
    // `select` is also bound to ALT release, and is a no-op when the
    // switcher is not open -- so the release bind can fire freely.
    IpcHandler {
        target: "switcher"

        function cycle(): void {
            Windows.cycle();
        }
        function next(): void {
            Windows.next();
        }
        function prev(): void {
            Windows.prev();
        }
        function select(): void {
            Windows.select();
        }
        function close(): void {
            Windows.close();
        }
        function dump(): string {
            return JSON.stringify({
                open: Windows.open,
                index: Windows.index,
                count: Windows.count,
                pending: Windows.pendingSelect,
                active: Windows.active ? Windows.active.appId : null,
                mru: Windows.mru.map(t => t ? t.appId : "?"),
                list: Windows.list.map(t => t ? t.appId : "?"),
                selected: Windows.selected ? Windows.selected.appId : null
            });
        }
    }

    // Live Activities, for scripts:
    //
    //   qs -c island ipc call activity push  dl download "Downloading" "linux-firmware" "0%" 0
    //   qs -c island ipc call activity update dl "linux-firmware" "63%" 0.63
    //   qs -c island ipc call activity remove dl
    //
    // Pushing an id that already exists updates it in place, so a script
    // can call push in a loop and never worry about which it wants.
    // `progress` is 0..1, or negative for indeterminate (the bar animates
    // instead of sitting at zero, which reads as stalled).
    //
    // Anything pushed this way gets no transport controls -- only a
    // dismiss. The shell cannot pause someone else's download, and a
    // button that pretends otherwise is worse than no button.
    IpcHandler {
        target: "activity"

        function push(id: string, icon: string, title: string, subtitle: string, value: string, progress: real): void {
            Activities.push({
                id: id,
                icon: icon,
                title: title,
                subtitle: subtitle,
                value: value,
                progress: progress
            });
        }

        function update(id: string, subtitle: string, value: string, progress: real): void {
            Activities.update(id, {
                subtitle: subtitle,
                value: value,
                progress: progress
            });
        }

        function remove(id: string): void {
            Activities.remove(id);
        }

        function clear(): void {
            Activities.clear();
        }

        function list(): string {
            return JSON.stringify(Activities.list);
        }
    }
}
