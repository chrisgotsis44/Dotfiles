pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Live theme bridge. Colors are read from whichever theme the system-wide
// theme switcher currently has active:
//   ~/.config/colorschemes/.current-theme         — active theme's name
//   ~/.config/quickshell/colors/custom/<name>.qml — that theme's palette
//
// Both files are watched, so picking a new theme in the switcher (or a
// theme file being regenerated in place, e.g. matugen re-deriving colors
// from a new wallpaper) updates every color here live — and everything in
// the shell reads from here, so the whole UI re-themes without a restart.
//
// Only the "base palette" keys (bg0-4, fg, red/orange/yellow/green/aqua/
// blue/purple, grey0-2) are pulled out of the theme file. Those are always
// literal hex in every theme file. The "Semantic / Material Mappings"
// section further down in those files is NOT parsed — it sometimes just
// aliases another key in the same file (e.g. `accent: primary`, `border:
// outline`), which a value-only regex can't safely resolve. Instead, the
// semantic tokens the rest of the shell actually uses (bg, surface,
// accent, danger, ...) are derived from the base palette below, once,
// consistently, the same way for every theme.
Singleton {
    id: root

    readonly property string themeDir: Quickshell.env("HOME") + "/.config/quickshell/colors/custom"
    readonly property string themeNamePath: Quickshell.env("HOME") + "/.config/colorschemes/.current-theme"

    property string themeName: "catppuccin"
    property var palette: ({})

    // Used until the first successful load, and as a per-key fallback if a
    // theme file is ever missing a base-palette key.
    readonly property var fallback: ({
        bg0: "#121613", bg1: "#1A201B", bg2: "#242C25", bg3: "#2C352D", bg4: "#343E35",
        fg: "#ECF2ED", grey0: "#5D6A60", grey1: "#454F47", grey2: "#9CAA9F",
        green: "#7FE0B4", red: "#E57A6B"
    })

    function pal(key) {
        return root.palette[key] || root.fallback[key];
    }

    function hexToRgb(hex) {
        const h = hex.replace("#", "");
        return {
            r: parseInt(h.substring(0, 2), 16) / 255,
            g: parseInt(h.substring(2, 4), 16) / 255,
            b: parseInt(h.substring(4, 6), 16) / 255
        };
    }

    function luminance(hex) {
        const c = root.hexToRgb(hex);
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    }

    // Solid blend of two hex colors (t=0 -> a, t=1 -> b). Used for muted
    // "tinted surface" tones that need to stay fully opaque (e.g. borders).
    function mix(hexA, hexB, t) {
        const a = root.hexToRgb(hexA);
        const b = root.hexToRgb(hexB);
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    function withAlpha(hex, alpha) {
        const c = root.hexToRgb(hex);
        return Qt.rgba(c.r, c.g, c.b, alpha);
    }

    // Pulls out every `property color name: "#hex"` line, readonly or not.
    // Anything that aliases another property instead of a literal hex
    // (e.g. `accent: primary`) is silently skipped.
    function parsePalette(txt) {
        const out = {};
        const re = /property\s+color\s+(\w+)\s*:\s*"(#[0-9a-fA-F]{6,8})"/g;
        let m;
        while ((m = re.exec(txt)) !== null)
            out[m[1]] = m[2];
        return out;
    }

    // ---- Which theme is active ----
    FileView {
        id: themeNameFile
        path: root.themeNamePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const name = text().trim();
            if (name)
                root.themeName = name;
        }
        onLoadFailed: error => {}
    }

    // ---- That theme's palette file ----
    FileView {
        id: paletteFile
        path: root.themeDir + "/" + root.themeName + ".qml"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const parsed = root.parsePalette(text());
            if (Object.keys(parsed).length > 0)
                root.palette = parsed;
        }
        onLoadFailed: error => {}
    }

    // ---- Base surfaces (bg0 darkest -> bg4 lightest, per theme) ----
    readonly property color bg: pal("bg0")
    readonly property color surface: pal("bg1")
    readonly property color surfaceHigh: pal("bg2")
    readonly property color surfaceHover: pal("bg3")
    readonly property color surfacePressed: pal("bg4")
    readonly property color border: pal("bg3")

    // The island itself (slightly translucent, near-black)
    readonly property color island: withAlpha(pal("bg0"), 0.96)
    // A bit more see-through than the base pill -- used only for Big
    // Island mode (the wide, screen-spanning "extended" bar), NOT the
    // transient hover-expanded state. Big Island sits there persistently
    // over whatever's beneath it, so the extra transparency reads better
    // there than on a normal small pill.
    readonly property color islandExtended: withAlpha(pal("bg0"), 0.80)
    readonly property color islandBorder: withAlpha(pal("bg3"), 0.22)

    // Type
    readonly property color text: pal("fg")
    readonly property color subtext: pal("grey2")
    readonly property color faint: pal("grey0")

    // Accent — every theme file defines a "green" key specifically as its
    // designated accent alias, even themes that aren't literally green
    // (matugen's is a rose tone, monochrome's is a mid grey, etc).
    readonly property color accent: pal("green")
    readonly property color accentFg: luminance(pal("green")) > 0.55 ? "#08130D" : "#ECF2ED"
    readonly property color accentDim: mix(pal("bg1"), pal("green"), 0.35)

    // Sliders (theme surface track; fill is Colors.accent directly, same
    // as every other "active" surface in the Control Center)
    readonly property color sliderTrack: pal("bg2")
    readonly property color sliderIcon: pal("grey1")

    // Misc
    readonly property color danger: pal("red")
    readonly property color scrim: withAlpha(pal("bg0"), 0.65) // legibility layer over album art
}
