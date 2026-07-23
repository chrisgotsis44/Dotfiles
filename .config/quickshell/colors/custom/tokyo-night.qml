pragma Singleton
import QtQuick

QtObject {
    // Base Palette
    readonly property color bg0: "#1a1b26"
    readonly property color bg1: "#292e42"
    readonly property color bg2: "#283457"
    readonly property color bg3: "#414868"
    readonly property color bg4: "#545c7e"
    readonly property color fg: "#c0caf5"

    // Colors
    readonly property color red: "#f7768e"
    readonly property color orange: "#ff9e64"
    readonly property color yellow: "#e0af68"
    readonly property color green: "#9ece6a"
    readonly property color aqua: "#7dcfff"
    readonly property color blue: "#7aa2f7"
    readonly property color purple: "#bb9af7"

    // Neutrals / Greys
    readonly property color grey0: "#545c7e"
    readonly property color grey1: "#a9b1d6"
    readonly property color grey2: "#c0caf5"

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
