pragma Singleton
import QtQuick

QtObject {
    // Base Palette
    readonly property color bg0: "#1F1F28"
    readonly property color bg1: "#2A2A37"
    readonly property color bg2: "#223249"
    readonly property color bg3: "#363646"
    readonly property color bg4: "#54546D"
    readonly property color fg: "#DCD7BA"

    // Colors
    readonly property color red: "#E82424"
    readonly property color orange: "#FFA066"
    readonly property color yellow: "#DCA561"
    readonly property color green: "#98BB6C"
    readonly property color aqua: "#7AA89F"
    readonly property color blue: "#7E9CD8"
    readonly property color purple: "#957FB8"

    // Neutrals / Greys
    readonly property color grey0: "#54546D"
    readonly property color grey1: "#727169"
    readonly property color grey2: "#C8C093"

    // Semantic / Material Mappings
    readonly property color background: bg0
    readonly property color onBackground: fg
    readonly property color surface: bg1
    readonly property color surfaceVariant: bg3
    readonly property color primary: blue
    readonly property color onPrimary: bg0
    readonly property color primaryContainer: bg2
    readonly property color secondary: purple
    readonly property color onSecondary: bg0
    readonly property color accent: green
    readonly property color border: bg3
    readonly property color outline: grey1
}
