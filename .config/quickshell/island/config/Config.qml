pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// The shell's runtime config: ~/.config/island/config.json.
//
// This is what makes Appearance.qml's tokens LIVE values instead of
// compile-time constants -- Appearance binds to the properties below, so
// a change lands everywhere the moment it happens, from either
// direction:
//
//   - the Settings panel (SUPER+S) writes these properties; a debounced
//     writeAdapter() persists them to disk.
//   - editing config.json by hand (or from a script) hot-reloads: the
//     FileView watches the file and reload() re-fills the adapter.
//
// The JsonAdapter's property defaults double as the canonical default
// values -- a missing file or a missing key falls back to them, so a
// partial config.json (or none at all) is always valid.
Singleton {
    id: root

    // The adapter is the public surface: Config.settings.fontSize etc.
    readonly property JsonAdapter settings: adapter

    function resetToDefaults(): void {
        // Appearance
        adapter.fontSize = 15;
        adapter.fontFamily = "Adwaita Sans";
        adapter.roundingScale = 1.0;
        adapter.barTopMargin = 8;
        adapter.barHPadding = 22;
        adapter.barVPadding = 11;
        // Island border
        adapter.borderEnabled = true;
        adapter.borderWidth = 1;
        adapter.borderOpacity = 0.22;
        adapter.borderAccentOnMenu = true;
        adapter.borderAccentOpacity = 0.45;
        // Motion
        adapter.animScale = 1.0;
        adapter.islandSnappy = true;
        adapter.hoverGraceMs = 200;
        // Timing
        adapter.osdDurationMs = 1500;
        adapter.notifDurationMs = 5000;
        adapter.weatherRefreshMin = 30;
        // Island
        adapter.maxWorkspaces = 5;
        adapter.bigIslandGap = 40;
        adapter.showTray = true;
        adapter.trayIconSize = 17;
        // Clock
        adapter.clock24h = true;
        adapter.showSeconds = false;
        adapter.dateFormat = "ddd d MMM";
        // Modules
        adapter.volumeStep = 5;
        adapter.cavaBars = 4;
        adapter.clipboardLimit = 60;
        adapter.launcherMaxResults = 50;
        adapter.showTimer = true;
        adapter.showPomodoro = true;
        adapter.showUpdates = true;
    }

    FileView {
        id: file

        path: Quickshell.env("HOME") + "/.config/island/config.json"
        watchChanges: true
        // Write to a temp file and rename, so an external watcher (or
        // our own reload) can never read a half-written JSON.
        atomicWrites: true

        onFileChanged: reload()
        // Normalise the file once per session so every key the shell
        // knows about is present on disk -- otherwise a config.json
        // written by an older version stays half-empty and the new
        // settings are undiscoverable by hand. Guarded, because this
        // write re-triggers onFileChanged -> reload() -> loaded.
        property bool synced: false
        onLoaded: {
            if (!synced) {
                synced = true;
                writeAdapter();
            }
        }
        // Fires when any adapter property changes -- from the Settings
        // UI or from a reload. Debounced so a slider drag is one write,
        // not sixty. A reload-triggered save rewrites identical content
        // and the cycle terminates because unchanged properties don't
        // re-fire this signal.
        onAdapterUpdated: saveTimer.restart()
        onLoadFailed: error => {
            // First run: no config.json yet. Create it from the
            // defaults so the user has a file to discover and edit.
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            // ---- Appearance ----
            // Base UI text size (StyledText/MonoText read it through
            // Appearance.font.size).
            property int fontSize: 15
            // UI text face. Anything Qt can resolve; an unknown name
            // silently falls back to the system default rather than
            // failing, so a typo here is survivable.
            property string fontFamily: "Adwaita Sans"
            // Multiplies Appearance.rounding.small/normal/large.
            property real roundingScale: 1.0
            // Gap between the screen edge and the idle pill.
            property int barTopMargin: 8
            // Padding inside the pill. vPadding also feeds the reserved
            // exclusive zone, so raising it moves tiled windows down.
            property int barHPadding: 22
            property int barVPadding: 11

            // ---- Island border ----
            property bool borderEnabled: true
            property int borderWidth: 1
            // Rim opacity at rest. The accent rim shown while a menu is
            // open has its own opacity below.
            property real borderOpacity: 0.22
            // Tint the rim with the accent colour while a menu is open.
            property bool borderAccentOnMenu: true
            property real borderAccentOpacity: 0.45

            // ---- Motion ----
            // Multiplies every animation duration. 0 disables animation
            // outright; 2 is half speed.
            property real animScale: 1.0
            // Pill-to-pill morphs: true = the fast spatial token (350ms,
            // pronounced overshoot), false = the default one (500ms,
            // gentler). Menus are unaffected -- they always use the
            // decelerate curve, see Bar.qml.
            property bool islandSnappy: true
            // Grace period before the hover strip collapses, so skimming
            // the pill's edge doesn't make it flutter.
            property int hoverGraceMs: 200

            // ---- Timing ----
            // How long the volume OSD lingers after the last change.
            property int osdDurationMs: 1500
            // How long a notification holds the island.
            property int notifDurationMs: 5000
            // Weather poll interval.
            property int weatherRefreshMin: 30

            // ---- Island ----
            // Workspaces drawn in the hover strip and Big Island.
            property int maxWorkspaces: 5
            // Clear space either side of the Big Island bar.
            property int bigIslandGap: 40
            // System tray in the Big Island cluster.
            property bool showTray: true
            property int trayIconSize: 17

            // ---- Clock ----
            property bool clock24h: true
            property bool showSeconds: false
            // Qt.formatDateTime pattern for the hover strip's date line.
            property string dateFormat: "ddd d MMM"

            // ---- Modules ----
            // Volume change per scroll notch on the pill, in percent.
            property int volumeStep: 5
            // Spectrum values cava computes; the pill mirrors them, so
            // it draws twice this many bars.
            property int cavaBars: 4
            // Clipboard history entries kept in the picker.
            property int clipboardLimit: 60
            // Control Center clock tiles. Hiding both collapses the row
            // entirely rather than leaving a gap.
            property bool showTimer: true
            property bool showPomodoro: true
            // Slim system-update row in the Control Center.
            property bool showUpdates: true
            // Launcher results before the list is truncated.
            property int launcherMaxResults: 50
        }
    }

    Timer {
        id: saveTimer
        interval: 400
        onTriggered: file.writeAdapter()
    }
}
