pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// The Settings panel (SUPER+S).
//
// Deliberately NOT a Section the pill morphs into: like the wallpaper
// picker it is its own centered overlay (see shell.qml), because a
// settings surface is a place you stay and adjust several things, not a
// state the island passes through. Search + category sidebar on the
// left, one scrollable page on the right -- the same shape as
// caelestia's and DankMaterialShell's settings windows.
//
// Two backends behind one UI, and each page's footer says which:
//   Shell / Theme -> ~/.config/island/config.json via Config, and the
//                    Themes service. Hot-reloads both ways.
//   Effects /     -> HyprConfig: `hyprctl keyword` applied instantly and
//   Window /         persisted back into the Hyprland config.
//   Animations
FocusScope {
    id: root

    readonly property int pageCount: card.pages.length

    // ------------------------------------------------------------ //
    //  Click-away                                                   //
    // ------------------------------------------------------------ //
    // A MouseArea, NOT a TapHandler. TapHandler takes a passive grab and
    // does not consume the press, so a full-screen one fires even when
    // the click landed on the card above it -- which meant clicking ANY
    // control in the panel also closed the panel. MouseArea hit-testing
    // is z-ordered and consuming, which is why Bar.qml's backdrop uses
    // one too. The card declares its own eater below.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onPressed: GlobalState.settingsOpen = false
    }

    // ------------------------------------------------------------ //
    //  Elevation                                                    //
    // ------------------------------------------------------------ //
    // Stacked translucent rounded rects rather than a MultiEffect drop
    // shadow: MultiEffect renders its source *itself*, so shadowing an
    // interactive card means hiding the real one and losing all input.
    // Six cheap layers read as a soft shadow and cost nothing.
    //
    // This is what replaces the old full-screen scrim -- the panel still
    // separates from the desktop without dimming everything behind it.
    Repeater {
        model: 6

        Rectangle {
            required property int index

            x: card.x - (index + 1) * 4
            y: card.y - (index + 1) * 4 + 5
            width: card.width + (index + 1) * 8
            height: card.height + (index + 1) * 8
            radius: card.radius + (index + 1) * 4
            color: Qt.rgba(0, 0, 0, 0.055)
            opacity: card.opacity
        }
    }

    // ------------------------------------------------------------ //
    //  Lifecycle                                                    //
    // ------------------------------------------------------------ //
    Connections {
        target: GlobalState

        function onSettingsOpenChanged(): void {
            if (GlobalState.settingsOpen)
                root.open();
        }
    }

    Component.onCompleted: root.open()

    function open(): void {
        HyprConfig.refresh();
        Themes.refresh();
        Monitors.refresh();
        DesktopTheme.refresh();
        searchField.text = "";
        card.page = 0;
        card.enter();
        searchField.forceActiveFocus();
    }

    // ------------------------------------------------------------ //
    //  The card                                                     //
    // ------------------------------------------------------------ //
    StyledRect {
        id: card

        anchors.centerIn: parent
        width: Math.min(940, parent.width - 80)
        height: Math.min(660, parent.height - 80)
        radius: Appearance.rounding.large
        color: Colors.island
        border.width: 1
        border.color: Colors.islandBorder
        clip: true

        property int page: 0

        readonly property var pages: [
            { label: "Shell", icon: "tune", sub: "Fonts, layout, motion, timing" },
            { label: "Island", icon: "density_small", sub: "Pill, workspaces, tray" },
            { label: "Modules", icon: "widgets", sub: "Clock, audio, launcher" },
            { label: "Monitors", icon: "monitor", sub: "Resolution, scale, layout" },
            { label: "Theme", icon: "palette", sub: "Color scheme, wallpaper" },
            { label: "Apps", icon: "desktop_windows", sub: "GTK & Qt, icons, cursor" },
            { label: "Effects", icon: "blur_on", sub: "Blur, shadows, borders" },
            { label: "Window", icon: "space_dashboard", sub: "Gaps, opacity, rounding" },
            { label: "Animations", icon: "animation", sub: "Hyprland presets" },
            { label: "About", icon: "info", sub: "Versions, paths, actions" }
        ]

        // Flat index of every individual setting, for search. Keeping it
        // declarative here (rather than scraping the built pages) is the
        // only way to match against settings on pages that have not been
        // instantiated yet -- the Loader below only ever builds one.
        readonly property var searchIndex: [
            { page: 0, section: "Appearance", label: "Font size" },
            { page: 0, section: "Appearance", label: "Corner rounding" },
            { page: 0, section: "Appearance", label: "Bar top margin" },
            { page: 0, section: "Motion", label: "Animation duration" },
            { page: 0, section: "Timing", label: "Volume OSD lingers for" },
            { page: 0, section: "Timing", label: "Notification stays for" },
            { page: 0, section: "Appearance", label: "Font family" },
            { page: 1, section: "Pill", label: "Horizontal padding" },
            { page: 1, section: "Pill", label: "Vertical padding" },
            { page: 1, section: "Pill", label: "Hover grace period" },
            { page: 1, section: "Workspaces", label: "Workspaces shown" },
            { page: 1, section: "Big Island", label: "Edge gap" },
            { page: 1, section: "Tray", label: "Show system tray" },
            { page: 1, section: "Tray", label: "Tray icon size" },
            { page: 2, section: "Clock", label: "24-hour clock" },
            { page: 2, section: "Clock", label: "Show seconds" },
            { page: 2, section: "Clock", label: "Date format" },
            { page: 2, section: "Audio", label: "Volume step" },
            { page: 2, section: "Audio", label: "Visualizer bars" },
            { page: 2, section: "Launcher", label: "Maximum results" },
            { page: 2, section: "Clipboard", label: "History entries" },
            { page: 2, section: "Weather", label: "Refresh interval" },
            { page: 2, section: "Control Center tiles", label: "Timer / Stopwatch" },
            { page: 2, section: "Control Center tiles", label: "Pomodoro" },
            { page: 2, section: "Control Center tiles", label: "System update" },
            { page: 5, section: "Fonts", label: "GTK font and size" },
            { page: 5, section: "Fonts", label: "Qt font and size" },
            { page: 0, section: "Border", label: "Shell border" },
            { page: 0, section: "Border", label: "Border width" },
            { page: 0, section: "Border", label: "Border opacity" },
            { page: 0, section: "Border", label: "Accent rim on menus" },
            { page: 3, section: "Monitors", label: "Resolution" },
            { page: 3, section: "Monitors", label: "Refresh rate" },
            { page: 3, section: "Monitors", label: "Display scale" },
            { page: 3, section: "Monitors", label: "Rotation / transform" },
            { page: 3, section: "Monitors", label: "Position" },
            { page: 3, section: "Monitors", label: "VRR / adaptive sync" },
            { page: 4, section: "Theme", label: "Color scheme" },
            { page: 4, section: "Theme", label: "Wallpaper" },
            { page: 5, section: "GTK", label: "GTK theme" },
            { page: 5, section: "GTK", label: "Icon theme" },
            { page: 5, section: "GTK", label: "Cursor theme and size" },
            { page: 5, section: "GTK", label: "Application font" },
            { page: 5, section: "GTK", label: "Prefer dark" },
            { page: 5, section: "Qt", label: "Qt style" },
            { page: 5, section: "Qt", label: "Kvantum theme" },
            { page: 6, section: "Effects", label: "Blur" },
            { page: 6, section: "Effects", label: "Blur size, passes, vibrancy" },
            { page: 6, section: "Effects", label: "Shadows" },
            { page: 6, section: "Effects", label: "Shadow range, render power, sharp" },
            { page: 6, section: "Effects", label: "Borders" },
            { page: 7, section: "Window", label: "Gaps in / out" },
            { page: 7, section: "Window", label: "Active / inactive opacity" },
            { page: 7, section: "Window", label: "Rounding, rounding power" },
            { page: 8, section: "Animations", label: "Hyprland animation preset" },
            { page: 9, section: "About", label: "Reload shell" },
            { page: 9, section: "About", label: "Open config.json" }
        ]

        readonly property string query: searchField.text.trim().toLowerCase()
        readonly property bool searching: query !== ""

        readonly property var results: {
            if (!searching)
                return [];
            return searchIndex.filter(e => e.label.toLowerCase().includes(query)
                || e.section.toLowerCase().includes(query)
                || pages[e.page].label.toLowerCase().includes(query));
        }

        function enter(): void {
            enterAnim.restart();
        }

        // Pop-in on the same spatial family as the island's own morphs,
        // so the two surfaces read as one system.
        ParallelAnimation {
            id: enterAnim

            NumberAnimation {
                target: card
                property: "scale"
                from: 0.94
                to: 1
                duration: Appearance.anim.durations.fastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.fastSpatial
            }
            NumberAnimation {
                target: card
                property: "opacity"
                from: 0
                to: 1
                duration: Appearance.anim.durations.slowEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.defaultEffects
            }
        }

        // Declared FIRST so every interactive child stacks above it and
        // wins its own clicks; this only catches presses on dead card
        // area, and exists purely to stop them reaching the click-away
        // MouseArea underneath.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ---------------------------------------------------- //
            //  Sidebar                                              //
            // ---------------------------------------------------- //
            Rectangle {
                Layout.preferredWidth: 236
                Layout.fillHeight: true
                color: Colors.surface
                // Per-corner radius, because the card's `clip: true`
                // cannot do this: QML clipping is a rectangular scissor
                // and ignores `radius` entirely, so this opaque sidebar
                // was painting square corners straight over the card's
                // rounded left edge.
                topLeftRadius: card.radius
                bottomLeftRadius: card.radius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 10
                        Layout.topMargin: 4
                        Layout.leftMargin: 6
                        spacing: 10

                        MaterialIcon {
                            text: "settings"
                            font.pixelSize: Appearance.font.px(22)
                            color: Colors.accent
                        }
                        StyledText {
                            text: "Settings"
                            font.pixelSize: Appearance.font.px(18)
                            font.weight: 800
                        }
                    }

                    // ---- Search ----
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 8
                        implicitHeight: 38
                        radius: 19
                        color: Colors.surfaceHigh
                        border.width: 1
                        border.color: searchField.activeFocus ? Qt.alpha(Colors.accent, 0.45) : Colors.border

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 8

                            MaterialIcon {
                                text: "search"
                                font.pixelSize: Appearance.font.px(16)
                                color: Colors.subtext
                            }

                            TextInput {
                                id: searchField

                                Layout.fillWidth: true
                                color: Colors.text
                                font.family: Appearance.font.family
                                font.pixelSize: Appearance.font.px(13)
                                clip: true
                                focus: true

                                // Escape clears a query first, and only
                                // closes the panel on a second press --
                                // closing outright would be a surprising
                                // amount of destruction for one key.
                                Keys.onEscapePressed: {
                                    if (text !== "")
                                        text = "";
                                    else
                                        GlobalState.settingsOpen = false;
                                }
                                Keys.onDownPressed: card.page = Math.min(card.page + 1, root.pageCount - 1)
                                Keys.onUpPressed: card.page = Math.max(card.page - 1, 0)
                                Keys.onReturnPressed: {
                                    if (card.results.length > 0) {
                                        card.page = card.results[0].page;
                                        text = "";
                                    }
                                }

                                StyledText {
                                    visible: searchField.text === ""
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Search settings…"
                                    font.pixelSize: Appearance.font.px(13)
                                    color: Colors.faint
                                }
                            }

                            MaterialIcon {
                                visible: searchField.text !== ""
                                text: "close"
                                font.pixelSize: Appearance.font.px(15)
                                color: Colors.subtext

                                HoverHandler {
                                    cursorShape: Qt.PointingHandCursor
                                }
                                TapHandler {
                                    onTapped: searchField.text = ""
                                }
                            }
                        }
                    }

                    Repeater {
                        model: card.pages

                        StyledRect {
                            id: navItem

                            required property var modelData
                            required property int index

                            readonly property bool current: card.page === index && !card.searching

                            Layout.fillWidth: true
                            implicitHeight: 50
                            radius: Appearance.rounding.small
                            color: current ? Colors.surfaceHigh
                                 : navHover.hovered ? Colors.surfaceHover
                                 : "transparent"
                            border.width: 1
                            border.color: current ? Qt.alpha(Colors.accent, 0.35) : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 11

                                MaterialIcon {
                                    text: navItem.modelData.icon
                                    font.pixelSize: Appearance.font.px(18)
                                    color: navItem.current ? Colors.accent : Colors.subtext
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        text: navItem.modelData.label
                                        font.pixelSize: Appearance.font.px(13)
                                        font.weight: navItem.current ? 700 : 500
                                    }
                                    StyledText {
                                        width: parent.width
                                        text: navItem.modelData.sub
                                        elide: Text.ElideRight
                                        font.pixelSize: Appearance.font.px(10)
                                        color: Colors.faint
                                    }
                                }
                            }

                            HoverHandler {
                                id: navHover
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: {
                                    searchField.text = "";
                                    card.page = navItem.index;
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6
                        Layout.bottomMargin: 2
                        text: "↑↓ to move · Esc to close"
                        font.pixelSize: Appearance.font.px(10)
                        color: Colors.faint
                    }
                }
            }

            // ---------------------------------------------------- //
            //  Content                                              //
            // ---------------------------------------------------- //
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    anchors.bottomMargin: 14
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            text: card.searching ? "Results" : card.pages[card.page].label
                            font.pixelSize: Appearance.font.px(20)
                            font.weight: 800
                        }
                        StyledText {
                            visible: card.searching
                            text: card.results.length + " match" + (card.results.length === 1 ? "" : "es")
                            font.pixelSize: Appearance.font.px(12)
                            color: Colors.faint
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        IconButton {
                            icon: "close"
                            size: 34
                            iconSize: 17
                            onClicked: GlobalState.settingsOpen = false
                        }
                    }

                    // ---- Search results ----
                    Flickable {
                        visible: card.searching
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: resultsCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: resultsCol
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: card.results

                                StyledRect {
                                    id: res

                                    required property var modelData

                                    width: parent.width
                                    implicitHeight: 54
                                    radius: Appearance.rounding.small
                                    color: resHover.hovered ? Colors.surfaceHover : Colors.surface
                                    border.width: 1
                                    border.color: Colors.border

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        spacing: 12

                                        MaterialIcon {
                                            text: card.pages[res.modelData.page].icon
                                            font.pixelSize: Appearance.font.px(18)
                                            color: Colors.accent
                                        }

                                        Column {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            StyledText {
                                                text: res.modelData.label
                                                font.pixelSize: Appearance.font.px(13)
                                                font.weight: 600
                                            }
                                            StyledText {
                                                text: card.pages[res.modelData.page].label + " · " + res.modelData.section
                                                font.pixelSize: Appearance.font.px(10)
                                                color: Colors.faint
                                            }
                                        }

                                        MaterialIcon {
                                            text: "chevron_right"
                                            font.pixelSize: Appearance.font.px(16)
                                            color: Colors.subtext
                                        }
                                    }

                                    HoverHandler {
                                        id: resHover
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                    TapHandler {
                                        onTapped: {
                                            card.page = res.modelData.page;
                                            searchField.text = "";
                                        }
                                    }
                                }
                            }

                            StyledText {
                                visible: card.results.length === 0
                                width: parent.width
                                text: "Nothing matches that."
                                font.pixelSize: Appearance.font.px(13)
                                color: Colors.faint
                            }
                        }
                    }

                    // ---- Page ----
                    Item {
                        visible: !card.searching
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Flickable {
                            id: flick

                            anchors.fill: parent
                            contentHeight: pageLoader.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Loader {
                                id: pageLoader

                                width: flick.width
                                sourceComponent: {
                                    switch (card.page) {
                                    case 1: return islandPage;
                                    case 2: return modulesPage;
                                    case 3: return monitorsPage;
                                    case 4: return themePage;
                                    case 5: return appsPage;
                                    case 6: return effectsPage;
                                    case 7: return windowPage;
                                    case 8: return animationsPage;
                                    case 9: return aboutPage;
                                    default: return shellPage;
                                    }
                                }

                                onLoaded: {
                                    flick.contentY = 0;
                                    pageAnim.restart();
                                }

                                ParallelAnimation {
                                    id: pageAnim

                                    NumberAnimation {
                                        target: pageLoader
                                        property: "opacity"
                                        from: 0
                                        to: 1
                                        duration: Appearance.anim.durations.defaultEffects
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Appearance.anim.curves.defaultEffects
                                    }
                                    NumberAnimation {
                                        target: pageLoader
                                        property: "y"
                                        from: 8
                                        to: 0
                                        duration: Appearance.anim.durations.fastSpatial
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Appearance.anim.curves.fastSpatial
                                    }
                                }
                            }
                        }

                        // Slim scroll indicator; only present when the
                        // page actually overflows.
                        Rectangle {
                            visible: flick.contentHeight > flick.height
                            anchors.right: parent.right
                            anchors.rightMargin: 1
                            width: 3
                            radius: 1.5
                            color: Qt.alpha(Colors.subtext, 0.45)
                            y: flick.visibleArea.yPosition * parent.height
                            height: Math.max(28, flick.visibleArea.heightRatio * parent.height)
                        }
                    }
                }
            }
        }
    }

    // ============================================================ //
    //  Shared building blocks                                       //
    // ============================================================ //

    component SectionCard: StyledRect {
        id: sc

        property string title
        property string icon
        // Shows a small reset affordance in the header when connected.
        property bool resettable: false
        default property alias content: scCol.data

        signal reset()

        width: parent.width
        implicitHeight: scOuter.implicitHeight + 32
        radius: Appearance.rounding.normal
        color: Colors.surface
        border.width: 1
        border.color: Colors.border

        Column {
            id: scOuter
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 16
            spacing: sc.title !== "" ? 8 : 0

            Item {
                width: parent.width
                height: sc.title !== "" ? 24 : 0
                visible: sc.title !== ""

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: sc.icon
                        font.pixelSize: Appearance.font.px(17)
                        color: Colors.accent
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: sc.title
                        font.pixelSize: Appearance.font.px(12)
                        font.weight: 700
                        color: Colors.subtext
                    }
                }

                MaterialIcon {
                    visible: sc.resettable
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "restart_alt"
                    font.pixelSize: Appearance.font.px(16)
                    color: resetHover.hovered ? Colors.accent : Colors.faint

                    HoverHandler {
                        id: resetHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: sc.reset()
                    }
                }
            }

            Column {
                id: scCol
                width: parent.width
                spacing: 10
            }
        }
    }

    component SettingSlider: Column {
        id: ss

        required property string label
        required property real value
        required property real min
        required property real max
        property bool integer: true
        property string display: ""

        signal moved(real newValue)

        width: parent.width
        spacing: 4

        RowLayout {
            width: parent.width

            StyledText {
                Layout.fillWidth: true
                text: ss.label
                font.pixelSize: Appearance.font.px(12)
                color: Colors.subtext
            }
            MonoText {
                text: ss.display !== "" ? ss.display
                    : ss.integer ? Math.round(ss.value) : ss.value.toFixed(2)
                font.pixelSize: Appearance.font.px(12)
                font.weight: 700
                color: Colors.accent
            }
        }

        CcSlider {
            width: parent.width
            implicitHeight: 30
            value: ss.max > ss.min ? (ss.value - ss.min) / (ss.max - ss.min) : 0
            onMoved: v => {
                const raw = ss.min + v * (ss.max - ss.min);
                ss.moved(ss.integer ? Math.round(raw) : Math.round(raw * 100) / 100);
            }
        }
    }

    // Label/sub + expand chevron (+ optional switch) with a height-
    // animated reveal underneath. Ported from the Dashboard's old
    // Customize tab -- see its comments for why the tap zone stops
    // before the switch rather than spanning the row.
    component ExpandRow: Column {
        id: er

        required property string label
        required property string sub
        property bool hasSwitch: true
        property bool checked: false
        default property alias submenu: submenuCol.data

        signal toggled()

        property bool expanded: false

        width: parent.width
        spacing: 0

        Item {
            width: parent.width
            height: 46

            Item {
                anchors.left: parent.left
                anchors.right: er.hasSwitch ? erSwitch.left : parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                TapHandler {
                    onTapped: er.expanded = !er.expanded
                }
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    StyledText {
                        text: er.label
                        font.pixelSize: Appearance.font.px(14)
                        font.weight: 600
                    }
                    StyledText {
                        text: er.sub
                        font.pixelSize: Appearance.font.px(11)
                        color: Colors.faint
                    }
                }

                MaterialIcon {
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: er.expanded ? "expand_less" : "expand_more"
                    font.pixelSize: Appearance.font.px(16)
                    color: Colors.faint
                }
            }

            ToggleSwitch {
                id: erSwitch
                visible: er.hasSwitch
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: er.checked
                onToggled: er.toggled()
            }
        }

        Item {
            width: parent.width
            height: er.expanded ? submenuCol.implicitHeight + 10 : 0
            visible: height > 0.5
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: Appearance.anim.durations.expand
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }

            Column {
                id: submenuCol
                y: 6
                width: parent.width
                spacing: 10
            }
        }
    }

    component ActionButton: StyledRect {
        id: ab

        required property string label
        property string icon: ""

        signal activated()

        implicitWidth: abRow.implicitWidth + 30
        implicitHeight: 34
        radius: 17
        color: abHover.hovered ? Colors.surfaceHover : Colors.surfaceHigh
        border.width: 1
        border.color: Colors.border

        Row {
            id: abRow
            anchors.centerIn: parent
            spacing: 7

            MaterialIcon {
                visible: ab.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: ab.icon
                font.pixelSize: Appearance.font.px(15)
                color: Colors.accent
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: ab.label
                font.pixelSize: Appearance.font.px(12)
                font.weight: 600
            }
        }

        HoverHandler {
            id: abHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: ab.activated()
        }
    }

    // Label/sub + a switch. The plain sibling of ExpandRow, for
    // settings that are simply on or off.
    component SwitchRow: RowLayout {
        id: sr

        required property string label
        property string sub: ""
        property bool checked: false

        signal toggled()

        width: parent.width

        Column {
            Layout.fillWidth: true
            spacing: 1

            StyledText {
                text: sr.label
                font.pixelSize: Appearance.font.px(13)
            }
            StyledText {
                visible: sr.sub !== ""
                text: sr.sub
                font.pixelSize: Appearance.font.px(10)
                color: Colors.faint
            }
        }

        ToggleSwitch {
            checked: sr.checked
            onToggled: sr.toggled()
        }
    }

    // Label + a row of chips, one of which is current. For settings with
    // a handful of named values rather than a range.
    component ChoiceRow: Column {
        id: cr

        required property string label
        required property var options   // [{ value, display }]
        required property var current

        signal picked(var value)

        width: parent.width
        spacing: 6

        StyledText {
            text: cr.label
            font.pixelSize: Appearance.font.px(12)
            color: Colors.subtext
        }

        Flow {
            width: parent.width
            spacing: 6

            Repeater {
                model: cr.options

                StyledRect {
                    id: opt

                    required property var modelData

                    readonly property bool active: modelData.value === cr.current

                    implicitWidth: optLabel.implicitWidth + 24
                    implicitHeight: 30
                    radius: 15
                    color: active ? Colors.accent
                         : optHover.hovered ? Colors.surfaceHover
                         : Colors.surfaceHigh

                    StyledText {
                        id: optLabel
                        anchors.centerIn: parent
                        text: opt.modelData.display
                        font.pixelSize: Appearance.font.px(12)
                        font.weight: opt.active ? 700 : 500
                        color: opt.active ? Colors.accentFg : Colors.text
                    }

                    HoverHandler {
                        id: optHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: cr.picked(opt.modelData.value)
                    }
                }
            }
        }
    }

    component FootNote: StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        font.pixelSize: Appearance.font.px(11)
        color: Colors.faint
    }

    component InfoRow: RowLayout {
        required property string label
        required property string value

        width: parent.width

        StyledText {
            Layout.fillWidth: true
            text: parent.label
            font.pixelSize: Appearance.font.px(12)
            color: Colors.subtext
        }
        MonoText {
            Layout.maximumWidth: 320
            text: parent.value
            elide: Text.ElideMiddle
            font.pixelSize: Appearance.font.px(11)
            color: Colors.text
        }
    }

    // ============================================================ //
    //  Pages                                                        //
    // ============================================================ //

    // ---- Shell -------------------------------------------------- //
    Component {
        id: shellPage

        Column {
            spacing: 12

            SectionCard {
                title: "Appearance"
                icon: "text_fields"
                resettable: true
                onReset: {
                    Config.settings.fontSize = 15;
                    Config.settings.fontFamily = "Adwaita Sans";
                    Config.settings.roundingScale = 1.0;
                    Config.settings.barTopMargin = 8;
                }

                SettingSlider {
                    label: "Font size"
                    value: Config.settings.fontSize
                    min: 11
                    max: 20
                    onMoved: v => Config.settings.fontSize = v
                }
                ChoiceRow {
                    label: "Font family"
                    current: Config.settings.fontFamily
                    options: [
                        { value: "Adwaita Sans", display: "Adwaita" },
                        { value: "Inter", display: "Inter" },
                        { value: "Cantarell", display: "Cantarell" },
                        { value: "Noto Sans", display: "Noto Sans" },
                        { value: "JetBrainsMono Nerd Font Propo", display: "JetBrains" }
                    ]
                    onPicked: v => Config.settings.fontFamily = v
                }
                SettingSlider {
                    label: "Corner rounding"
                    value: Config.settings.roundingScale
                    min: 0.5
                    max: 1.5
                    integer: false
                    display: Math.round(Config.settings.roundingScale * 100) + "%"
                    onMoved: v => Config.settings.roundingScale = v
                }
                SettingSlider {
                    label: "Bar top margin"
                    value: Config.settings.barTopMargin
                    min: 0
                    max: 24
                    display: Config.settings.barTopMargin + " px"
                    onMoved: v => Config.settings.barTopMargin = v
                }
            }

            SectionCard {
                title: "Motion"
                icon: "animation"
                resettable: true
                onReset: {
                    Config.settings.animScale = 1.0;
                    Config.settings.islandSnappy = true;
                }

                SettingSlider {
                    label: "Animation duration"
                    value: Config.settings.animScale
                    min: 0
                    max: 2
                    integer: false
                    display: Config.settings.animScale === 0 ? "off"
                           : "×" + Config.settings.animScale.toFixed(2)
                    onMoved: v => Config.settings.animScale = v
                }

                FootNote {
                    text: "Scales every animation in the shell. 0 disables animation entirely; ×2 runs at half speed."
                }

                SwitchRow {
                    label: "Snappy pill morphs"
                    sub: "350ms with a stronger overshoot, instead of 500ms"
                    checked: Config.settings.islandSnappy
                    onToggled: Config.settings.islandSnappy = !Config.settings.islandSnappy
                }
            }

            SectionCard {
                title: "Border"
                icon: "select_all"
                resettable: true
                onReset: {
                    Config.settings.borderEnabled = true;
                    Config.settings.borderWidth = 1;
                    Config.settings.borderOpacity = 0.22;
                    Config.settings.borderAccentOnMenu = true;
                    Config.settings.borderAccentOpacity = 0.45;
                }

                SwitchRow {
                    label: "Shell border"
                    sub: "Hairline rim around the island and its menus"
                    checked: Config.settings.borderEnabled
                    onToggled: Config.settings.borderEnabled = !Config.settings.borderEnabled
                }
                SettingSlider {
                    label: "Width"
                    value: Config.settings.borderWidth
                    min: 0
                    max: 6
                    display: Config.settings.borderWidth + " px"
                    onMoved: v => Config.settings.borderWidth = v
                }
                SettingSlider {
                    label: "Opacity at rest"
                    value: Config.settings.borderOpacity
                    min: 0
                    max: 1
                    integer: false
                    display: Math.round(Config.settings.borderOpacity * 100) + "%"
                    onMoved: v => Config.settings.borderOpacity = v
                }
                SwitchRow {
                    label: "Accent rim on menus"
                    sub: "Tint the border while a menu is open"
                    checked: Config.settings.borderAccentOnMenu
                    onToggled: Config.settings.borderAccentOnMenu = !Config.settings.borderAccentOnMenu
                }
                SettingSlider {
                    label: "Accent rim opacity"
                    value: Config.settings.borderAccentOpacity
                    min: 0
                    max: 1
                    integer: false
                    display: Math.round(Config.settings.borderAccentOpacity * 100) + "%"
                    onMoved: v => Config.settings.borderAccentOpacity = v
                }

                FootNote {
                    text: "The rim at rest follows the active theme's border colour; only its alpha is set here."
                }
            }

            SectionCard {
                title: "Timing"
                icon: "timer"
                resettable: true
                onReset: {
                    Config.settings.osdDurationMs = 1500;
                    Config.settings.notifDurationMs = 5000;
                }

                SettingSlider {
                    label: "Volume OSD lingers for"
                    value: Config.settings.osdDurationMs
                    min: 500
                    max: 4000
                    display: (Config.settings.osdDurationMs / 1000).toFixed(1) + " s"
                    onMoved: v => Config.settings.osdDurationMs = Math.round(v / 100) * 100
                }
                SettingSlider {
                    label: "Notification stays for"
                    value: Config.settings.notifDurationMs
                    min: 2000
                    max: 10000
                    display: (Config.settings.notifDurationMs / 1000).toFixed(1) + " s"
                    onMoved: v => Config.settings.notifDurationMs = Math.round(v / 500) * 500
                }
            }

            FootNote {
                text: "Saved to ~/.config/island/config.json — edit it by hand and changes appear here live."
            }
        }
    }

    // ---- Island ------------------------------------------------- //
    Component {
        id: islandPage

        Column {
            spacing: 12

            SectionCard {
                title: "Pill"
                icon: "density_small"
                resettable: true
                onReset: {
                    Config.settings.barHPadding = 22;
                    Config.settings.barVPadding = 11;
                    Config.settings.hoverGraceMs = 200;
                }

                SettingSlider {
                    label: "Horizontal padding"
                    value: Config.settings.barHPadding
                    min: 8
                    max: 48
                    display: Config.settings.barHPadding + " px"
                    onMoved: v => Config.settings.barHPadding = v
                }
                SettingSlider {
                    label: "Vertical padding"
                    value: Config.settings.barVPadding
                    min: 4
                    max: 28
                    display: Config.settings.barVPadding + " px"
                    onMoved: v => Config.settings.barVPadding = v
                }
                SettingSlider {
                    label: "Hover grace period"
                    value: Config.settings.hoverGraceMs
                    min: 0
                    max: 600
                    display: Config.settings.hoverGraceMs + " ms"
                    onMoved: v => Config.settings.hoverGraceMs = Math.round(v / 25) * 25
                }

                FootNote {
                    text: "Vertical padding also sets the reserved strip at the top of the screen, so raising it moves tiled windows down."
                }
            }

            SectionCard {
                title: "Workspaces & Big Island"
                icon: "view_column"
                resettable: true
                onReset: {
                    Config.settings.maxWorkspaces = 5;
                    Config.settings.bigIslandGap = 40;
                }

                SettingSlider {
                    label: "Workspaces shown"
                    value: Config.settings.maxWorkspaces
                    min: 1
                    max: 10
                    onMoved: v => Config.settings.maxWorkspaces = v
                }
                SettingSlider {
                    label: "Big Island edge gap"
                    value: Config.settings.bigIslandGap
                    min: 0
                    max: 200
                    display: Config.settings.bigIslandGap + " px"
                    onMoved: v => Config.settings.bigIslandGap = Math.round(v / 5) * 5
                }
            }

            SectionCard {
                title: "System tray"
                icon: "widgets"
                resettable: true
                onReset: {
                    Config.settings.showTray = true;
                    Config.settings.trayIconSize = 17;
                }

                SwitchRow {
                    label: "Show system tray"
                    sub: "In the Big Island cluster (SUPER+B)"
                    checked: Config.settings.showTray
                    onToggled: Config.settings.showTray = !Config.settings.showTray
                }
                SettingSlider {
                    label: "Icon size"
                    value: Config.settings.trayIconSize
                    min: 12
                    max: 26
                    display: Config.settings.trayIconSize + " px"
                    onMoved: v => Config.settings.trayIconSize = v
                }
            }
        }
    }

    // ---- Modules ------------------------------------------------ //
    Component {
        id: modulesPage

        Column {
            spacing: 12

            SectionCard {
                title: "Control Center tiles"
                icon: "dashboard"
                resettable: true
                onReset: {
                    Config.settings.showTimer = true;
                    Config.settings.showPomodoro = true;
                    Config.settings.showUpdates = true;
                }

                SwitchRow {
                    label: "Timer / Stopwatch"
                    sub: "Right-click the tile switches between the two"
                    checked: Config.settings.showTimer
                    onToggled: Config.settings.showTimer = !Config.settings.showTimer
                }
                SwitchRow {
                    label: "Pomodoro"
                    sub: Timers.pomoActive ? "Running — " + Timers.pomoLabel
                                           : "Focus / break cycles"
                    checked: Config.settings.showPomodoro
                    onToggled: Config.settings.showPomodoro = !Config.settings.showPomodoro
                }
                SwitchRow {
                    label: "System update"
                    sub: Updates.summary
                    checked: Config.settings.showUpdates
                    onToggled: Config.settings.showUpdates = !Config.settings.showUpdates
                }

                FootNote {
                    text: "Hiding a tile only removes it from the Control Center — a running timer keeps running and still shows on the pill as a Live Activity."
                }
            }

            SectionCard {
                title: "Clock"
                icon: "schedule"
                resettable: true
                onReset: {
                    Config.settings.clock24h = true;
                    Config.settings.showSeconds = false;
                    Config.settings.dateFormat = "ddd d MMM";
                }

                SwitchRow {
                    label: "24-hour clock"
                    sub: Time.time
                    checked: Config.settings.clock24h
                    onToggled: Config.settings.clock24h = !Config.settings.clock24h
                }
                SwitchRow {
                    label: "Show seconds"
                    sub: "Ticks the clock every second instead of every minute"
                    checked: Config.settings.showSeconds
                    onToggled: Config.settings.showSeconds = !Config.settings.showSeconds
                }
                ChoiceRow {
                    label: "Date format — " + Time.dateStr
                    current: Config.settings.dateFormat
                    options: [
                        { value: "ddd d MMM", display: "Mon 3 Jun" },
                        { value: "dddd d MMMM", display: "Monday 3 June" },
                        { value: "d MMM yyyy", display: "3 Jun 2026" },
                        { value: "dd/MM/yyyy", display: "03/06/2026" },
                        { value: "MMM d", display: "Jun 3" }
                    ]
                    onPicked: v => Config.settings.dateFormat = v
                }
            }

            SectionCard {
                title: "Audio"
                icon: "volume_up"
                resettable: true
                onReset: {
                    Config.settings.volumeStep = 5;
                    Config.settings.cavaBars = 4;
                }

                SettingSlider {
                    label: "Volume step per scroll"
                    value: Config.settings.volumeStep
                    min: 1
                    max: 20
                    display: Config.settings.volumeStep + "%"
                    onMoved: v => Config.settings.volumeStep = v
                }
                SettingSlider {
                    label: "Visualizer bars"
                    value: Config.settings.cavaBars
                    min: 2
                    max: 12
                    display: Config.settings.cavaBars + " (" + (Config.settings.cavaBars * 2) + " drawn)"
                    onMoved: v => Config.settings.cavaBars = v
                }

                FootNote {
                    text: "The spectrum is mirrored, so the pill draws twice this many bars. cava only runs while music plays, so a change lands the next time it starts."
                }
            }

            SectionCard {
                title: "Launcher & clipboard"
                icon: "search"
                resettable: true
                onReset: {
                    Config.settings.launcherMaxResults = 50;
                    Config.settings.clipboardLimit = 60;
                }

                SettingSlider {
                    label: "Launcher results"
                    value: Config.settings.launcherMaxResults
                    min: 10
                    max: 100
                    onMoved: v => Config.settings.launcherMaxResults = Math.round(v / 5) * 5
                }
                SettingSlider {
                    label: "Clipboard history entries"
                    value: Config.settings.clipboardLimit
                    min: 10
                    max: 200
                    onMoved: v => Config.settings.clipboardLimit = Math.round(v / 10) * 10
                }
            }

            SectionCard {
                title: "Weather"
                icon: "partly_cloudy_day"
                resettable: true
                onReset: Config.settings.weatherRefreshMin = 30

                SettingSlider {
                    label: "Refresh interval"
                    value: Config.settings.weatherRefreshMin
                    min: 5
                    max: 180
                    display: Config.settings.weatherRefreshMin + " min"
                    onMoved: v => Config.settings.weatherRefreshMin = Math.round(v / 5) * 5
                }

                InfoRow {
                    label: "Location"
                    value: WeatherData.city || "resolving…"
                }
            }
        }
    }

    // ---- Monitors ----------------------------------------------- //
    Component {
        id: monitorsPage

        Column {
            spacing: 12

            Repeater {
                model: Monitors.list

                SectionCard {
                    id: monCard

                    required property var modelData

                    readonly property var mon: modelData
                    readonly property var resolutions: Monitors.resolutionsFor(modelData)
                    readonly property string currentRes: modelData.width + "x" + modelData.height
                    readonly property var currentRates: {
                        const r = resolutions.find(x => x.key === currentRes);
                        return r ? r.rates : [];
                    }

                    title: modelData.name + (modelData.disabled ? " · off" : "")
                    icon: "monitor"

                    StyledText {
                        width: parent.width
                        text: monCard.mon.description || monCard.mon.model || ""
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.px(11)
                        color: Colors.faint
                    }

                    SwitchRow {
                        label: "Enabled"
                        // The last active output has no switch: turning it
                        // off leaves no screen to turn it back on from.
                        sub: Monitors.activeCount <= 1 && !monCard.mon.disabled
                             ? "Only active display — cannot be disabled"
                             : "Off removes it from the layout entirely"
                        checked: !monCard.mon.disabled
                        onToggled: {
                            if (Monitors.activeCount <= 1 && !monCard.mon.disabled)
                                return;
                            Monitors.setDisabled(monCard.mon, !monCard.mon.disabled);
                        }
                    }

                    ChoiceRow {
                        visible: !monCard.mon.disabled
                        label: "Resolution"
                        current: monCard.currentRes
                        options: monCard.resolutions.map(r => ({ value: r.key, display: r.label }))
                        onPicked: v => {
                            const r = monCard.resolutions.find(x => x.key === v);
                            if (r)
                                Monitors.apply(monCard.mon, { width: r.w, height: r.h, rate: r.rates[0] });
                        }
                    }

                    ChoiceRow {
                        visible: !monCard.mon.disabled && monCard.currentRates.length > 1
                        label: "Refresh rate"
                        current: Math.round(monCard.mon.refreshRate)
                        options: monCard.currentRates.map(r => ({ value: Math.round(r), display: Math.round(r) + " Hz" }))
                        onPicked: v => {
                            const exact = monCard.currentRates.find(r => Math.round(r) === v);
                            Monitors.apply(monCard.mon, { rate: exact !== undefined ? exact : v });
                        }
                    }

                    ChoiceRow {
                        visible: !monCard.mon.disabled
                        label: "Scale"
                        current: Number(monCard.mon.scale).toFixed(2)
                        options: [
                            { value: "1.00", display: "100%" },
                            { value: "1.25", display: "125%" },
                            { value: "1.50", display: "150%" },
                            { value: "1.75", display: "175%" },
                            { value: "2.00", display: "200%" }
                        ]
                        onPicked: v => Monitors.apply(monCard.mon, { scale: parseFloat(v) })
                    }

                    ChoiceRow {
                        visible: !monCard.mon.disabled
                        label: "Rotation"
                        current: monCard.mon.transform
                        options: [
                            { value: 0, display: "Normal" },
                            { value: 1, display: "90°" },
                            { value: 2, display: "180°" },
                            { value: 3, display: "270°" },
                            { value: 4, display: "Flipped" }
                        ]
                        onPicked: v => Monitors.apply(monCard.mon, { transform: v })
                    }

                    SwitchRow {
                        visible: !monCard.mon.disabled
                        label: "Adaptive sync (VRR)"
                        sub: "Variable refresh rate"
                        checked: monCard.mon.vrr
                        onToggled: Monitors.apply(monCard.mon, { vrr: !monCard.mon.vrr })
                    }

                    InfoRow {
                        visible: !monCard.mon.disabled
                        label: "Position"
                        value: monCard.mon.x + ", " + monCard.mon.y
                    }
                }
            }

            StyledText {
                visible: !Monitors.ready
                width: parent.width
                text: "No monitors reported."
                font.pixelSize: Appearance.font.px(13)
                color: Colors.faint
            }

            FootNote {
                text: "Applied live via hyprctl eval. NOT written to monitors.lua — that file is hand-written Lua with a workspace-rule loop in it, and rewriting Lua from a slider is how configs get eaten. A Hyprland reload restores whatever it declares."
            }
        }
    }

    // ---- Apps (GTK & Qt) ---------------------------------------- //
    Component {
        id: appsPage

        Column {
            spacing: 12

            SectionCard {
                title: "Fonts"
                icon: "text_fields"

                ChoiceRow {
                    label: "GTK font — " + (DesktopTheme.gtkFontFamily || "—")
                    current: DesktopTheme.gtkFontFamily
                    options: DesktopTheme.fontFamilies.map(f => ({ value: f, display: f }))
                    onPicked: v => DesktopTheme.setGtkFontFamily(v)
                }
                SettingSlider {
                    label: "GTK font size"
                    value: DesktopTheme.gtkFontSize
                    min: 8
                    max: 18
                    integer: false
                    display: DesktopTheme.gtkFontSize + " pt"
                    onMoved: v => DesktopTheme.setGtkFontSize(Math.round(v * 2) / 2)
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Colors.border
                }

                ChoiceRow {
                    label: "Qt font — " + (DesktopTheme.qtFontFamily || "—")
                    current: DesktopTheme.qtFontFamily
                    options: DesktopTheme.fontFamilies.map(f => ({ value: f, display: f }))
                    onPicked: v => DesktopTheme.setQtFont(v, DesktopTheme.qtFontSize)
                }
                SettingSlider {
                    label: "Qt font size"
                    value: DesktopTheme.qtFontSize
                    min: 8
                    max: 18
                    integer: false
                    display: DesktopTheme.qtFontSize + " pt"
                    onMoved: v => DesktopTheme.setQtFont(DesktopTheme.qtFontFamily, Math.round(v * 2) / 2)
                }

                ActionButton {
                    label: "Match Qt to GTK"
                    icon: "sync"
                    onActivated: DesktopTheme.setQtFont(DesktopTheme.gtkFontFamily, DesktopTheme.gtkFontSize)
                }

                FootNote {
                    text: "GTK applies live. Qt is written to qt5ct.conf and qt6ct.conf and lands on each app's next start. This is the toolkit font for your applications — the shell's own text size is under Shell."
                }
            }

            SectionCard {
                title: "GTK"
                icon: "apps"

                ChoiceRow {
                    label: "Theme"
                    current: DesktopTheme.gtkTheme
                    options: DesktopTheme.gtkThemes.map(t => ({ value: t, display: t }))
                    onPicked: v => DesktopTheme.setGtkTheme(v)
                }

                SwitchRow {
                    label: "Prefer dark"
                    sub: "Asks apps for their dark variant"
                    checked: DesktopTheme.preferDark
                    onToggled: DesktopTheme.setPreferDark(!DesktopTheme.preferDark)
                }


            }

            SectionCard {
                title: "Icons & cursor"
                icon: "mouse"

                ChoiceRow {
                    label: "Icon theme"
                    current: DesktopTheme.iconTheme
                    options: DesktopTheme.iconThemes.map(t => ({ value: t, display: t }))
                    onPicked: v => DesktopTheme.setIconTheme(v)
                }

                ChoiceRow {
                    label: "Cursor theme"
                    current: DesktopTheme.cursorTheme
                    options: DesktopTheme.cursorThemes.map(t => ({ value: t, display: t }))
                    onPicked: v => DesktopTheme.setCursorTheme(v)
                }

                SettingSlider {
                    label: "Cursor size"
                    value: DesktopTheme.cursorSize
                    min: 16
                    max: 48
                    display: DesktopTheme.cursorSize + " px"
                    onMoved: v => DesktopTheme.setCursorSize(Math.round(v / 4) * 4)
                }

                FootNote {
                    text: "Icon theme is applied to GTK and Qt together. Cursor also goes to the compositor via hyprctl setcursor, which gsettings alone does not reach."
                }
            }

            SectionCard {
                title: "Qt"
                icon: "widgets"

                ChoiceRow {
                    label: "Style"
                    current: DesktopTheme.qtStyle
                    options: DesktopTheme.qtStyles.map(t => ({ value: t, display: t }))
                    onPicked: v => DesktopTheme.setQtStyle(v)
                }

                ChoiceRow {
                    label: "Kvantum theme"
                    current: DesktopTheme.kvantumTheme
                    options: DesktopTheme.kvantumThemes.map(t => ({ value: t, display: t }))
                    onPicked: v => DesktopTheme.setKvantumTheme(v)
                }

                FootNote {
                    text: "Written to qt5ct.conf and qt6ct.conf; Qt apps pick it up on their next start. GTK changes apply live."
                }
            }

            FootNote {
                text: "The shell's own theme switcher (Theme tab) owns the colour scheme — applying a scheme overwrites the GTK and Kvantum theme names above. Icon theme, cursor and Qt style are left alone by it."
            }
        }
    }

    // ---- Theme -------------------------------------------------- //
    Component {
        id: themePage

        Column {
            spacing: 12

            SectionCard {
                title: "Color scheme"
                icon: "palette"

                Flow {
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: Themes.list

                        StyledRect {
                            id: themeCard

                            required property var modelData

                            readonly property bool current: modelData.name === Themes.activeTheme
                            readonly property var swatch: Themes.swatchFor(modelData.name)

                            implicitWidth: 132
                            implicitHeight: 62
                            radius: Appearance.rounding.small
                            color: current ? Colors.surfaceHigh
                                 : themeHover.hovered ? Colors.surfaceHover
                                 : Colors.bg
                            border.width: 1
                            border.color: current ? Colors.accent : Colors.border

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 11
                                anchors.rightMargin: 11
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Row {
                                    spacing: 5

                                    Repeater {
                                        model: [themeCard.swatch.accent, themeCard.swatch.blue, themeCard.swatch.purple]

                                        Rectangle {
                                            required property var modelData

                                            width: 14
                                            height: 14
                                            radius: 7
                                            color: modelData
                                            border.width: 1
                                            border.color: Qt.alpha("#000000", 0.25)
                                        }
                                    }
                                }

                                StyledText {
                                    width: parent.width
                                    text: themeCard.modelData.display
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.px(12)
                                    font.weight: themeCard.current ? 700 : 500
                                    color: themeCard.current ? Colors.text : Colors.subtext
                                }
                            }

                            HoverHandler {
                                id: themeHover
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: Themes.apply(themeCard.modelData.name)
                            }
                        }
                    }
                }

                FootNote {
                    text: "Applied by apply-theme.sh — repaints this shell, Hyprland, kitty, GTK and Qt together."
                }
            }

            SectionCard {
                title: "Wallpaper"
                icon: "wallpaper"

                RowLayout {
                    width: parent.width
                    spacing: 10

                    StyledText {
                        Layout.fillWidth: true
                        text: "The picker is a full-screen overlay, so this closes Settings."
                        wrapMode: Text.WordWrap
                        font.pixelSize: Appearance.font.px(12)
                        color: Colors.subtext
                    }

                    ActionButton {
                        label: "Open picker"
                        icon: "image"
                        onActivated: {
                            GlobalState.settingsOpen = false;
                            Themes.openWallpaperPicker();
                        }
                    }
                }
            }
        }
    }

    // ---- Effects ------------------------------------------------ //
    Component {
        id: effectsPage

        Column {
            spacing: 12

            SectionCard {
                ExpandRow {
                    label: "Blur"
                    sub: "Background blur behind windows"
                    checked: HyprConfig.blurEnabled
                    onToggled: HyprConfig.toggleBlur()

                    SettingSlider {
                        label: "Size"
                        value: HyprConfig.blurSize
                        min: 1
                        max: 30
                        onMoved: v => HyprConfig.setBlurSize(v)
                    }
                    SettingSlider {
                        label: "Passes"
                        value: HyprConfig.blurPasses
                        min: 1
                        max: 6
                        onMoved: v => HyprConfig.setBlurPasses(v)
                    }
                    SettingSlider {
                        label: "Vibrancy"
                        value: HyprConfig.blurVibrancy
                        min: 0
                        max: 1
                        integer: false
                        onMoved: v => HyprConfig.setBlurVibrancy(v)
                    }
                    SettingSlider {
                        label: "Vibrancy Darkness"
                        value: HyprConfig.blurVibrancyDarkness
                        min: 0
                        max: 1
                        integer: false
                        onMoved: v => HyprConfig.setBlurVibrancyDarkness(v)
                    }
                }

                ExpandRow {
                    label: "Shadows"
                    sub: "Drop shadows under windows"
                    checked: HyprConfig.shadowsEnabled
                    onToggled: HyprConfig.toggleShadows()

                    SettingSlider {
                        label: "Range"
                        value: HyprConfig.shadowRange
                        min: 1
                        max: 40
                        onMoved: v => HyprConfig.setShadowRange(v)
                    }
                    SettingSlider {
                        label: "Render Power"
                        value: HyprConfig.shadowRenderPower
                        min: 1
                        max: 4
                        onMoved: v => HyprConfig.setShadowRenderPower(v)
                    }
                    RowLayout {
                        width: parent.width

                        StyledText {
                            Layout.fillWidth: true
                            text: "Sharp"
                            font.pixelSize: Appearance.font.px(12)
                            color: Colors.subtext
                        }
                        ToggleSwitch {
                            checked: HyprConfig.shadowSharp
                            onToggled: HyprConfig.toggleShadowSharp()
                        }
                    }
                }

                ExpandRow {
                    label: "Borders"
                    sub: "Window border frames"
                    checked: HyprConfig.bordersEnabled
                    onToggled: HyprConfig.toggleBorders()

                    SettingSlider {
                        label: "Border Size"
                        value: HyprConfig.savedBorderSize
                        min: 1
                        max: 5
                        onMoved: v => HyprConfig.setBorderSize(v)
                    }
                }
            }

            FootNote {
                text: "Applied instantly and saved to your Hyprland config — survives reloads and restarts."
            }
        }
    }

    // ---- Window ------------------------------------------------- //
    Component {
        id: windowPage

        Column {
            spacing: 12

            SectionCard {
                ExpandRow {
                    label: "Gaps"
                    sub: "Space between and around windows"
                    hasSwitch: false

                    SettingSlider {
                        label: "Gaps In"
                        value: HyprConfig.gapsIn
                        min: 0
                        max: 30
                        onMoved: v => HyprConfig.setGapsIn(v)
                    }
                    SettingSlider {
                        label: "Gaps Out"
                        value: HyprConfig.gapsOut
                        min: 0
                        max: 40
                        onMoved: v => HyprConfig.setGapsOut(v)
                    }
                }

                ExpandRow {
                    label: "Opacity"
                    sub: "Window transparency"
                    hasSwitch: false

                    SettingSlider {
                        label: "Active Opacity"
                        value: HyprConfig.activeOpacity
                        min: 0.2
                        max: 1
                        integer: false
                        onMoved: v => HyprConfig.setActiveOpacity(v)
                    }
                    SettingSlider {
                        label: "Inactive Opacity"
                        value: HyprConfig.inactiveOpacity
                        min: 0.2
                        max: 1
                        integer: false
                        onMoved: v => HyprConfig.setInactiveOpacity(v)
                    }
                }

                ExpandRow {
                    label: "Rounding"
                    sub: "Corner radius"
                    hasSwitch: false

                    SettingSlider {
                        label: "Rounding"
                        value: HyprConfig.rounding
                        min: 0
                        max: 25
                        onMoved: v => HyprConfig.setRounding(v)
                    }
                    SettingSlider {
                        label: "Rounding Power"
                        value: HyprConfig.roundingPower
                        min: 2
                        max: 4
                        integer: false
                        onMoved: v => HyprConfig.setRoundingPower(v)
                    }
                }
            }

            FootNote {
                text: "Applied instantly and saved to your Hyprland config — survives reloads and restarts."
            }
        }
    }

    // ---- Animations --------------------------------------------- //
    Component {
        id: animationsPage

        Column {
            spacing: 12

            SectionCard {
                title: "Preset"
                icon: "animation"

                RowLayout {
                    width: parent.width

                    StyledText {
                        Layout.fillWidth: true
                        text: "Active"
                        font.pixelSize: Appearance.font.px(12)
                        color: Colors.subtext
                    }
                    StyledText {
                        text: HyprConfig.currentAnimation
                        font.pixelSize: Appearance.font.px(12)
                        font.weight: 700
                        color: Colors.accent
                    }
                }

                Flow {
                    width: parent.width
                    spacing: 7

                    Repeater {
                        model: HyprConfig.animations

                        StyledRect {
                            id: chip

                            required property string modelData

                            readonly property bool current: modelData === HyprConfig.currentAnimation

                            implicitWidth: chipLabel.implicitWidth + 26
                            implicitHeight: 32
                            radius: 16
                            color: current ? Colors.accent
                                 : chipHover.hovered ? Colors.surfaceHover
                                 : Colors.surfaceHigh

                            StyledText {
                                id: chipLabel
                                anchors.centerIn: parent
                                text: chip.modelData
                                font.pixelSize: Appearance.font.px(12)
                                font.weight: chip.current ? 700 : 500
                                color: chip.current ? Colors.accentFg : Colors.text
                            }

                            HoverHandler {
                                id: chipHover
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: HyprConfig.setAnimation(chip.modelData)
                            }
                        }
                    }
                }
            }

            FootNote {
                text: "Hyprland animation presets from ~/.config/hypr/modules/animations — applied and persisted via the same symlink mechanism as the theme switcher."
            }
        }
    }

    // ---- About -------------------------------------------------- //
    Component {
        id: aboutPage

        Column {
            id: about

            property string qsVersion: "…"

            spacing: 12

            Process {
                id: verProc
                running: true
                command: ["qs", "--version"]
                stdout: StdioCollector {
                    // "Quickshell 0.3.0 (revision abc..., distributed
                    // by AUR (...))" -- the revision and packaging half
                    // is noise here and only forces an ellipsis.
                    onStreamFinished: about.qsVersion = text.trim().split("\n")[0].split(" (")[0]
                }
            }

            SectionCard {
                title: "Environment"
                icon: "info"

                InfoRow {
                    label: "Quickshell"
                    value: about.qsVersion
                }
                InfoRow {
                    label: "Active theme"
                    value: Themes.activeTheme
                }
                InfoRow {
                    label: "Animation preset"
                    value: HyprConfig.currentAnimation
                }
                InfoRow {
                    label: "Screens"
                    value: Quickshell.screens.length + " · " + Quickshell.screens.map(s => s.name).join(", ")
                }
            }

            SectionCard {
                title: "Paths"
                icon: "folder"

                InfoRow {
                    label: "Shell config"
                    value: "~/.config/island/config.json"
                }
                InfoRow {
                    label: "Shell source"
                    value: "~/.config/quickshell/island"
                }
                InfoRow {
                    label: "Hyprland"
                    value: "~/.config/hypr"
                }
            }

            SectionCard {
                title: "Actions"
                icon: "bolt"

                Flow {
                    width: parent.width
                    spacing: 8

                    ActionButton {
                        label: "Open config.json"
                        icon: "edit"
                        onActivated: Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/.config/island/config.json"])
                    }
                    ActionButton {
                        label: "Reset all shell settings"
                        icon: "restart_alt"
                        onActivated: Config.resetToDefaults()
                    }
                    ActionButton {
                        label: "Reload shell"
                        icon: "refresh"
                        // Restarts this very process, so the panel goes
                        // with it -- detached so the script outlives us.
                        onActivated: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/island-reload.sh"])
                    }
                }

                FootNote {
                    text: "Reloading restarts the shell process; the panel closes with it."
                }
            }
        }
    }
}
