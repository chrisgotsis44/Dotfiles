pragma Singleton
import QtQuick

QtObject {
    // Base Palette
    readonly property color bg0: "#14181b"
    readonly property color bg1: "#1e2429"
    readonly property color bg2: "#283036"
    readonly property color bg3: "#323c43"
    readonly property color bg4: "#3c4851"
    readonly property color fg: "#d3c6aa"

    // Colors
    readonly property color red: "#e67e80"
    readonly property color orange: "#e69875"
    readonly property color yellow: "#dbbc7f"
    readonly property color green: "#a7c080"
    readonly property color aqua: "#83c092"
    readonly property color blue: "#7fbbb3"
    readonly property color purple: "#d699b6"

    // Neutrals / Greys
    readonly property color grey0: "#5c6a72"
    readonly property color grey1: "#859289"
    readonly property color grey2: "#657366"

    // Semantic / Material Mappings
    readonly property color background: bg2
    readonly property color onBackground: fg
    readonly property color surface: bg1
    readonly property color surfaceVariant: bg3
    readonly property color primary: green
    readonly property color onPrimary: bg0
    readonly property color primaryContainer: bg3
    readonly property color secondary: blue
    readonly property color onSecondary: bg0
    readonly property color accent: green
    readonly property color border: bg3
    readonly property color outline: grey1
}
