pragma Singleton
import QtQuick

QtObject {
    // Base Palette
    readonly property color bg0: "#2e3440"
    readonly property color bg1: "#3b4252"
    readonly property color bg2: "#434c5e"
    readonly property color bg3: "#4c566a"
    readonly property color bg4: "#5f6c84"
    readonly property color fg: "#d8dee9"

    // Colors
    readonly property color red: "#bf616a"
    readonly property color orange: "#d08770"
    readonly property color yellow: "#ebcb8b"
    readonly property color green: "#a3be8c"
    readonly property color aqua: "#8fbcbb"
    readonly property color blue: "#5e81ac"
    readonly property color purple: "#b48ead"

    // Neutrals / Greys
    readonly property color grey0: "#616e88"
    readonly property color grey1: "#bfc5cd"
    readonly property color grey2: "#e4e9ef"

    // Semantic / Material Mappings
    readonly property color background: bg0
    readonly property color onBackground: fg
    readonly property color surface: bg1
    readonly property color surfaceVariant: bg2
    readonly property color primary: blue
    readonly property color onPrimary: bg0
    readonly property color primaryContainer: bg3
    readonly property color secondary: aqua
    readonly property color onSecondary: bg0
    readonly property color accent: green
    readonly property color border: bg3
    readonly property color outline: grey1
}
