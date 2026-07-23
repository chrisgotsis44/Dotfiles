import QtQuick
import Quickshell
import qs.config

// Replaces the standalone app's config/Settings.qml, which
// wallpaper-selector.sh used to back up, rewrite with whichever theme's
// wallpaper folder was active, then restore on exit -- that dance existed
// only because each open used to be a fresh process. Now the picker is a
// permanent part of the island, so wallpaperDir/thumbDir just track the
// live theme reactively via Colors.themeName instead.
QtObject {
    readonly property string homeDir: Quickshell.env("HOME")

    readonly property string wallpaperDir: homeDir + "/.config/colorschemes/" + Colors.themeName + "/wallpapers"
    readonly property string cacheDir: homeDir + "/.cache/wallpaper_picker"
    readonly property string thumbDir: homeDir + "/.cache/wallpaper_picker/thumbs_" + Colors.themeName

    property bool uiAnimationsEnabled: true
    property real uiAnimationScale: 1.0
    // Color-bucket filter chips (Red/Orange/.../Monochrome) only make sense
    // for matugen's large, varied wallpaper pool -- hand-authored themes
    // ship a small curated set where "All / Video / Search" is all that's
    // useful. Matches both real Settings.qml variants the standalone app
    // ever actually shipped (matugen: true, every other theme: unset/false).
    readonly property bool enableColorFiltering: Colors.themeName === "matugen"

    property string wallpaperTransitionType: "random"
    property real wallpaperTransitionDuration: 0.6
    property int wallpaperTransitionFps: 60

    property int closeDelayMs: 120
    property int scrollThrottleMs: 150
    property int filterAnimationMs: 800
    property int itemAnimationMs: 500

    // Every real deployment of the standalone picker always wrote these
    // false (both the plain-theme and matugen Settings.qml variants) --
    // the matugen color regeneration that "enableMatugen" would have
    // gated is instead handled explicitly by wallpaper-apply-post.sh,
    // called directly from applyWallpaper() below, only for the matugen
    // theme. Kept here only because WallpaperPicker.qml still reads them.
    property bool enableDynamicColors: false
    property bool enableMatugen: false
    property bool enableHyprReload: false
    property bool enableWaybarReload: false
    property bool enableKittyReload: false
    property bool enableCavaReload: false
    property bool enableSwayncReload: false
    property bool enableSwayosdReload: false

    property string hyprColorsPath: homeDir + "/.config/hypr/colors.conf"
    property string waybarColorsPath: homeDir + "/.config/waybar/colors.css"
    property string waybarLaunchPath: homeDir + "/.config/waybar/launch.sh"
    property string kittySignalProcess: ".kitty-wrapped"

    property string extraReloadCommand: ""
}
