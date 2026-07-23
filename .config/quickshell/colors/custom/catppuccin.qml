pragma Singleton
import QtQuick

QtObject {
    // Base Palette
    readonly property color bg0: "#11111b"
    readonly property color bg1: "#181825"
    readonly property color bg2: "#1e1e2e"
    readonly property color bg3: "#313244"
    readonly property color bg4: "#45475a"
    readonly property color fg: "#cdd6f4"

    // Colors
    readonly property color red: "#f38ba8"
    readonly property color orange: "#fab387"
    readonly property color yellow: "#f9e2af"
    readonly property color green: "#a6e3a1"
    readonly property color aqua: "#94e2d5"
    readonly property color blue: "#89b4fa"
    readonly property color purple: "#cba6f7"

    // Neutrals / Greys
    readonly property color grey0: "#585b70"
    readonly property color grey1: "#6c7086"
    readonly property color grey2: "#7f849c"

    // Semantic / Material Mappings
    readonly property color background: bg2
    readonly property color onBackground: fg
    readonly property color surface: bg1
    readonly property color surfaceVariant: bg3
    readonly property color primary: blue
    readonly property color onPrimary: bg0
    readonly property color primaryContainer: bg3
    readonly property color secondary: purple
    readonly property color onSecondary: bg0
    readonly property color accent: green
    readonly property color border: bg3
    readonly property color outline: grey1
}
