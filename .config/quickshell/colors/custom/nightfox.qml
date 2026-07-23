pragma Singleton
import QtQuick

QtObject {
    // Base Palette
    readonly property color bg0: "#192330"
    readonly property color bg1: "#252f3c"
    readonly property color bg2: "#313b48"
    readonly property color bg3: "#3d4754"
    readonly property color bg4: "#495360"
    readonly property color fg: "#c0c8d5"

    // Colors
    readonly property color red: "#c94f6d"
    readonly property color orange: "#fe9373"
    readonly property color yellow: "#dbc074"
    readonly property color green: "#8ebaa4"
    readonly property color aqua: "#7ad4d6"
    readonly property color blue: "#719cd6"
    readonly property color purple: "#baa1e2"

    // Neutrals / Greys
    readonly property color grey0: "#495360"
    readonly property color grey1: "#5c6775"
    readonly property color grey2: "#718093"

    // Semantic / Material Mappings
    readonly property color background: bg0
    readonly property color onBackground: fg
    readonly property color surface: bg1
    readonly property color surfaceVariant: bg2
    readonly property color primary: blue
    readonly property color onPrimary: bg0
    readonly property color primaryContainer: bg3
    readonly property color secondary: purple
    readonly property color onSecondary: bg0
    readonly property color accent: green
    readonly property color border: bg3
    readonly property color outline: grey1
}
