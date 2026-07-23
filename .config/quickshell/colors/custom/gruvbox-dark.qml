pragma Singleton
import QtQuick

QtObject {
    // Base Palette
    readonly property color bg0: "#1d2021"
    readonly property color bg1: "#3c3836"
    readonly property color bg2: "#504945"
    readonly property color bg3: "#665c54"
    readonly property color bg4: "#7c6f64"
    readonly property color fg: "#ebdbb2"

    // Colors
    readonly property color red: "#cc241d"
    readonly property color orange: "#d65d0e"
    readonly property color yellow: "#d79921"
    readonly property color green: "#98971a"
    readonly property color aqua: "#689d6a"
    readonly property color blue: "#458588"
    readonly property color purple: "#b16286"

    // Neutrals / Greys
    readonly property color grey0: "#a89984"
    readonly property color grey1: "#928374"
    readonly property color grey2: "#7c6f64"

    // Semantic / Material Mappings
    readonly property color background: bg0
    readonly property color onBackground: fg
    readonly property color surface: bg1
    readonly property color surfaceVariant: bg2
    readonly property color primary: yellow
    readonly property color onPrimary: bg0
    readonly property color primaryContainer: bg2
    readonly property color secondary: orange
    readonly property color onSecondary: bg0
    readonly property color accent: yellow
    readonly property color border: bg3
    readonly property color outline: grey1
}
