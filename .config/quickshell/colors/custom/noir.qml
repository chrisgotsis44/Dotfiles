pragma Singleton
import QtQuick

QtObject {
    // Base Palette
    readonly property color bg0: "#0a0a0a"
    readonly property color bg1: "#141414"
    readonly property color bg2: "#1f1f1f"
    readonly property color bg3: "#2b2b2b"
    readonly property color bg4: "#363636"
    readonly property color fg: "#e6e6e6"

    // Colors
    readonly property color red: "#555555"
    readonly property color orange: "#666666"
    readonly property color yellow: "#777777"
    readonly property color green: "#888888"
    readonly property color aqua: "#999999"
    readonly property color blue: "#aaaaaa"
    readonly property color purple: "#bbbbbb"

    // Neutrals / Greys
    readonly property color grey0: "#141414"
    readonly property color grey1: "#2b2b2b"
    readonly property color grey2: "#555555"

    // Semantic / Material Mappings
    readonly property color background: bg0
    readonly property color onBackground: fg
    readonly property color surface: bg1
    readonly property color surfaceVariant: bg2
    readonly property color primary: fg
    readonly property color onPrimary: bg0
    readonly property color primaryContainer: bg3
    readonly property color secondary: grey2
    readonly property color onSecondary: bg0
    readonly property color accent: fg
    readonly property color border: bg3
    readonly property color outline: grey1
}
