pragma Singleton
import QtQuick

QtObject {
    // Base Palette
    readonly property color bg0: "#191724"
    readonly property color bg1: "#1f1d2e"
    readonly property color bg2: "#26233a"
    readonly property color bg3: "#2a273f"
    readonly property color bg4: "#332e4e"
    readonly property color fg: "#e0def4"

    // Colors
    readonly property color red: "#eb6f92"
    readonly property color orange: "#f6c177"
    readonly property color yellow: "#f6c177"
    readonly property color green: "#9ccfd8"
    readonly property color aqua: "#31748f"
    readonly property color blue: "#569fba"
    readonly property color purple: "#c4a7e7"

    // Neutrals / Greys
    readonly property color grey0: "#6e6a86"
    readonly property color grey1: "#908caa"
    readonly property color grey2: "#e0def4"

    // Semantic / Material Mappings
    readonly property color background: bg0
    readonly property color onBackground: fg
    readonly property color surface: bg1
    readonly property color surfaceVariant: bg2
    readonly property color primary: purple
    readonly property color onPrimary: bg0
    readonly property color primaryContainer: bg3
    readonly property color secondary: aqua
    readonly property color onSecondary: bg0
    readonly property color accent: green
    readonly property color border: bg3
    readonly property color outline: grey1
}
