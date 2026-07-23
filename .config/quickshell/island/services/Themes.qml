pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Bridges the system-wide theme switcher (apply-theme.sh + the
// ~/.config/colorschemes/<name> directories) into the island's own
// Themes menu.
//
// The per-theme swatch preview is read straight out of each theme's own
// custom/<name>.qml -- the exact same base-palette keys Colors.qml itself
// derives the live UI palette from (see config/Colors.qml) -- so the
// list always shows the real colors the island is (or would be)
// rendering with, matugen's current wallpaper-driven one included.
Singleton {
    id: root

    readonly property string colorschemesDir: Quickshell.env("HOME") + "/.config/colorschemes"
    readonly property string themeDir: Quickshell.env("HOME") + "/.config/quickshell/colors/custom"

    // Same set/order as the original standalone theme switcher. Excludes
    // "monochrome" -- its custom/*.qml exists but it has no matching
    // ~/.config/colorschemes/monochrome directory for apply-theme.sh.
    readonly property var list: [
        { name: "catppuccin", display: "Catppuccin" },
        { name: "e-ink", display: "E Ink" },
        { name: "everforest-dark", display: "Everforest Dark" },
        { name: "gruvbox-dark", display: "Gruvbox Dark" },
        { name: "kanagawa", display: "Kanagawa" },
        { name: "matugen", display: "Matugen" },
        { name: "nightfox", display: "Nightfox" },
        { name: "noir", display: "Noir" },
        { name: "nord-darker", display: "Nord Darker" },
        { name: "rose-pine", display: "Rose Pine" },
        { name: "tokyo-night", display: "Tokyo Night" }
    ]

    property string activeTheme: "catppuccin"
    property var wallpapers: ({}) // themeName -> absolute path
    property var swatches: ({}) // themeName -> { blue, purple, accent }

    function wallpaperFor(name: string): string {
        return root.wallpapers[name] || "";
    }

    // blue/purple/green -- three of each theme's always-literal named
    // hues (see config/Colors.qml), all colorful accent tones. NOT bg0:
    // every dark theme's darkest background tier is, by definition,
    // close to black, so using it here made every theme's first swatch
    // converge on the same near-black dot instead of showing the
    // theme's actual character.
    readonly property var fallbackSwatch: ({ blue: "#5FA8E8", purple: "#B98BE8", accent: "#7FE0B4" })

    function swatchFor(name: string): var {
        return root.swatches[name] || root.fallbackSwatch;
    }

    // Refreshed every time the menu opens -- cheap (three short-lived
    // reads), and keeps matugen's swatch current with the last wallpaper.
    function refresh(): void {
        swatchProc.running = true;
    }

    function apply(name: string): void {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/apply-theme.sh", name]);
    }

    // The wallpaper picker now lives inside the island itself (see
    // modules/wallpaper/WallpaperPicker.qml + GlobalState.wallpaperPickerOpen)
    // rather than being spawned as a separate quickshell process. It
    // already tracks whichever theme is active reactively, so there's no
    // more "redirect to the matugen picker" special case to make here --
    // that's handled inside the picker's own Settings.qml.
    function openWallpaperPicker(): void {
        GlobalState.wallpaperPickerOpen = !GlobalState.wallpaperPickerOpen;
    }

    FileView {
        id: themeNameFile
        path: root.colorschemesDir + "/.current-theme"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const name = text().trim();
            if (name)
                root.activeTheme = name;
        }
        onLoadFailed: error => {}
    }

    FileView {
        id: wallpaperStateFile
        path: root.colorschemesDir + "/.wallpaper-state"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const map = {};
            for (const line of text().trim().split("\n")) {
                const i = line.indexOf(":");
                if (i > 0) {
                    const theme = line.substring(0, i).trim();
                    const path = line.substring(i + 1).trim();
                    if (theme && path)
                        map[theme] = path;
                }
            }
            root.wallpapers = map;
        }
        onLoadFailed: error => {}
    }

    Process {
        id: swatchProc
        command: ["grep", "-H", "-E", "property color (blue|purple|green):"].concat(root.list.map(t => root.themeDir + "/" + t.name + ".qml"))

        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                const re = /^(.+?)\/([^/\s]+)\.qml:\s*(?:readonly\s+)?property\s+color\s+(\w+)\s*:\s*"(#[0-9a-fA-F]{6,8})"$/;
                for (const line of text.split("\n")) {
                    const m = line.match(re);
                    if (!m)
                        continue;
                    const themeName = m[2];
                    const key = m[3];
                    const hex = m[4];
                    if (!out[themeName])
                        out[themeName] = Object.assign({}, root.fallbackSwatch);
                    if (key === "blue")
                        out[themeName].blue = hex;
                    else if (key === "purple")
                        out[themeName].purple = hex;
                    else if (key === "green")
                        out[themeName].accent = hex;
                }
                root.swatches = out;
            }
        }
    }
}
