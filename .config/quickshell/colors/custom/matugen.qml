pragma Singleton
import QtQuick

QtObject {
    // Background & Surfaces
    readonly property color background: "#1c1015"
    readonly property color onBackground: "#f5dce3"
    readonly property color surface: "#1c1015"
    readonly property color surfaceVariant: "#534248"

    // Primary Colors
    readonly property color primary: "#ffb0cf"
    readonly property color onPrimary: "#63003b"
    readonly property color primaryContainer: "#8c0055"

    // Secondary Colors
    readonly property color secondary: "#f2b7c1"
    readonly property color onSecondary: "#4b252d"

    // Add additional Material Design 3 tokens here as needed

    // --- Compat base palette ---
    // Every other quickshell theme file (catppuccin, gruvbox-dark, ...) is
    // hand-written with this same set of keys, and quickshell/island's
    // Colors.qml reads ONLY these keys (never the Material tokens above)
    // to derive the shell's colors. Without this block, the island falls
    // back to its default palette instead of following matugen.
    //
    // bg0 was originally surface_container_lowest -- M3's absolute darkest
    // surface role (tone ~4), which crushed down to near-black and read
    // noticeably darker than every hand-picked theme's bg0 (all land
    // somewhere in the tone ~7-20 range: catppuccin #11111b, tokyo-night
    // #1a1b26, nord-darker #2e3440, ...). Shifted the whole bg0-4 ramp up
    // by one M3 surface-container step so bg0 keeps some visible tint
    // instead of reading as plain black, ending on surface_bright (M3's
    // dedicated "brightest dark-mode surface" role) for bg4.
    readonly property color bg0: "#25181d"
    readonly property color bg1: "#291c21"
    readonly property color bg2: "#34262b"
    readonly property color bg3: "#403136"
    readonly property color bg4: "#44353a"
    // `on_surface` (M3's plain "text on background" role) is deliberately
    // near-neutral by design -- far less saturated than a hand-picked
    // theme's fg. `primary_fixed` is matugen's light-but-fully-chromatic
    // tone from the same hue family, and lands at roughly the same
    // saturation as catppuccin's fg -- so text/sliders/etc actually read
    // as "colored" instead of off-white.
    readonly property color fg: "#ffd9e5"

    readonly property color grey0: "#534248"
    readonly property color grey1: "#a08b92"
    readonly property color grey2: "#d8c1c7"

    readonly property color green: "#ffb0cf"
    readonly property color red: "#ffb4ab"
    // Used only for the Themes menu's swatch preview (never Colors.qml's
    // own derivation) -- distinct hue families from green/primary so the
    // three dots don't collapse into near-duplicates.
    readonly property color blue: "#f2b7c1"
    readonly property color purple: "#ffb3b0"
}
