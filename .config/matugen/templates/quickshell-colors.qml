pragma Singleton
import QtQuick

QtObject {
    // Background & Surfaces
    readonly property color background: "{{ colors.background.default.hex }}"
    readonly property color onBackground: "{{ colors.on_background.default.hex }}"
    readonly property color surface: "{{ colors.surface.default.hex }}"
    readonly property color surfaceVariant: "{{ colors.surface_variant.default.hex }}"

    // Primary Colors
    readonly property color primary: "{{ colors.primary.default.hex }}"
    readonly property color onPrimary: "{{ colors.on_primary.default.hex }}"
    readonly property color primaryContainer: "{{ colors.primary_container.default.hex }}"

    // Secondary Colors
    readonly property color secondary: "{{ colors.secondary.default.hex }}"
    readonly property color onSecondary: "{{ colors.on_secondary.default.hex }}"

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
    readonly property color bg0: "{{ colors.surface_container_low.default.hex }}"
    readonly property color bg1: "{{ colors.surface_container.default.hex }}"
    readonly property color bg2: "{{ colors.surface_container_high.default.hex }}"
    readonly property color bg3: "{{ colors.surface_container_highest.default.hex }}"
    readonly property color bg4: "{{ colors.surface_bright.default.hex }}"
    // `on_surface` (M3's plain "text on background" role) is deliberately
    // near-neutral by design -- far less saturated than a hand-picked
    // theme's fg. `primary_fixed` is matugen's light-but-fully-chromatic
    // tone from the same hue family, and lands at roughly the same
    // saturation as catppuccin's fg -- so text/sliders/etc actually read
    // as "colored" instead of off-white.
    readonly property color fg: "{{ colors.primary_fixed.default.hex }}"

    readonly property color grey0: "{{ colors.outline_variant.default.hex }}"
    readonly property color grey1: "{{ colors.outline.default.hex }}"
    readonly property color grey2: "{{ colors.on_surface_variant.default.hex }}"

    readonly property color green: "{{ colors.primary.default.hex }}"
    readonly property color red: "{{ colors.error.default.hex }}"
    // Used only for the Themes menu's swatch preview (never Colors.qml's
    // own derivation) -- distinct hue families from green/primary so the
    // three dots don't collapse into near-duplicates.
    readonly property color blue: "{{ colors.secondary.default.hex }}"
    readonly property color purple: "{{ colors.tertiary.default.hex }}"
}
