pragma Singleton
import QtQuick

QtObject {
    // Active / Base Palette
    property color bg0: "#1e1e2e"
    property color bg1: "#181825"
    property color bg2: "#11111b"
    property color bg3: "#313244"
    property color bg4: "#45475a"
    property color fg: "#cdd6f4"

    // Colors
    property color red: "#f38ba8"
    property color orange: "#fab387"
    property color yellow: "#f9e2af"
    property color green: "#a6e3a1"
    property color aqua: "#94e2d5"
    property color blue: "#89b4fa"
    property color purple: "#cba6f7"

    // Neutrals / Greys
    property color grey0: "#585b70"
    property color grey1: "#6c7086"
    property color grey2: "#7f849c"

    // Semantic / Material Mappings
    property color background: bg0
    property color onBackground: fg
    property color surface: bg1
    property color surfaceVariant: bg3
    property color primary: blue
    property color onPrimary: bg2
    property color primaryContainer: bg3
    property color secondary: purple
    property color onSecondary: bg2
    property color accent: green
    property color border: bg3
    property color outline: grey1
}
