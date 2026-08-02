pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// System Dashboard -- rendered INSIDE the island like every other menu
// (transparent root; the island supplies the panel, border, clipping).
//
// Three tabs behind an animated segmented control:
//   Performance  (left) live system stats from SysMonitor, which only
//                polls while this dashboard is open.
//   Weather      (middle) full forecast panel (WeatherTab.qml) fed by
//                services/WeatherData.qml -- hero card with ambient
//                condition animations, hourly curve, 7-day list,
//                sun arc & moon phase.
//   Customize    (right) Hyprland animation presets (same symlink +
//                hyprctl reload mechanism as animation-switcher.sh)
//                plus expandable blur/shadow/border effect rows -- tap
//                a row to reveal its actual values as sliders, all live
//                `hyprctl keyword` tweaks. There's no decoration-preset
//                switcher anymore: that folder used to hold whole
//                swappable decoration.lua files, but it's now a fixed,
//                hand-edited config the sliders read/adjust directly.
//
// Tab switches slide+fade the same way Control Center's detail pages
// do; the island morphs its height around whichever tab is active.
Item {
    id: root

    implicitWidth: 724
    implicitHeight: header.height + 14 + pages.implicitHeight

    property int tab: 0 // 0 = Performance, 1 = Weather, 2 = Customize

    function handleOpen(): void {
        HyprConfig.refresh();
        WeatherData.refresh();
    }

    Connections {
        target: GlobalState
        function onDashboardOpenChanged() {
            if (GlobalState.dashboardOpen)
                root.handleOpen();
        }
    }

    // Constructed on first open, after the signal above has already
    // fired -- without this the first open would show stale Hyprland
    // options and weather. See LauncherContent for the full explanation.
    Component.onCompleted: Qt.callLater(root.handleOpen)

    // ------------------------------------------------------------ //
    //  Animated segmented control                                   //
    // ------------------------------------------------------------ //
    StyledRect {
        id: header
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: 470
        height: 44
        radius: 22
        color: Colors.surface
        border.width: 1
        border.color: Colors.border

        // The sliding thumb.
        Rectangle {
            id: thumb
            width: parent.width / 3 - 5
            height: parent.height - 8
            radius: height / 2
            y: 4
            x: root.tab === 0 ? 4
             : root.tab === 1 ? (parent.width - width) / 2
             : parent.width - width - 4
            color: Colors.surfaceHigh
            border.width: 1
            border.color: Qt.alpha(Colors.accent, 0.35)

            Behavior on x {
                NumberAnimation {
                    duration: Appearance.anim.durations.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }
        }

        Row {
            anchors.fill: parent

            Repeater {
                model: [
                    { label: "Performance", icon: "speed" },
                    { label: "Weather", icon: "partly_cloudy_day" },
                    { label: "Customize", icon: "palette" }
                ]

                Item {
                    id: segment

                    required property var modelData
                    required property int index

                    width: header.width / 3
                    height: header.height

                    Row {
                        anchors.centerIn: parent
                        spacing: 7

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: segment.modelData.icon
                            font.pixelSize: 17
                            color: root.tab === segment.index ? Colors.accent : Colors.faint

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.durations.normal
                                }
                            }
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: segment.modelData.label
                            font.pixelSize: 14
                            font.weight: root.tab === segment.index ? 700 : 500
                            color: root.tab === segment.index ? Colors.text : Colors.subtext

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.durations.normal
                                }
                            }
                        }
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: root.tab = segment.index
                    }
                }
            }
        }
    }

    // A labeled slider row, normalized internally to the CcSlider's 0-1
    // range from [min, max]. Root-level so every Customize card can
    // reuse it, not just the Effects one.
    component EffectSlider: Column {
        id: es

        required property string label
        required property real value
        required property real min
        required property real max
        property bool integer: true

        signal moved(real newValue)

        width: parent.width
        spacing: 6

        RowLayout {
            width: parent.width

            StyledText {
                Layout.fillWidth: true
                text: es.label
                font.pixelSize: 12
                color: Colors.subtext
            }
            MonoText {
                text: es.integer ? Math.round(es.value) : es.value.toFixed(2)
                font.pixelSize: 12
                font.weight: 700
                color: Colors.accent
            }
        }

        CcSlider {
            width: parent.width
            implicitHeight: 32
            value: es.max > es.min ? (es.value - es.min) / (es.max - es.min) : 0
            onMoved: v => {
                const raw = es.min + v * (es.max - es.min);
                es.moved(es.integer ? Math.round(raw) : Math.round(raw * 100) / 100);
            }
        }
    }

    // One row: label/sub + expand chevron (+ optional on/off switch),
    // and a height-animated panel underneath revealing whatever's put
    // inside (typically EffectSlider). Root-level, like EffectSlider, so
    // every Customize card can use it -- Blur/Shadows/Borders each have
    // a switch, Gaps/Opacity/Rounding don't (there's no "off" for those).
    // Expansion is local to each row (not a shared accordion), so
    // there's no coordination needed with whatever card it's dropped in.
    //
    // The TapHandler is declared before the switch so the switch's own
    // tap area still wins over its own bounds (child items get input
    // priority; only taps elsewhere in the row reach this one).
    component EffectRow: Column {
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

            // Tap-to-expand zone: deliberately stops BEFORE the switch
            // (anchors.right) instead of spanning the whole row. A
            // TapHandler here that covered the full row width ALSO fired
            // when the switch itself was tapped -- sibling TapHandlers
            // don't reliably respect item z-order/containment for
            // exclusivity the way old MouseArea hit-testing did, so the
            // switch's own toggle and this row's expand/collapse both
            // triggered on the same tap. Physically not overlapping the
            // switch's bounds avoids relying on that ambiguity.
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
                        font.pixelSize: 14
                        font.weight: 600
                    }
                    StyledText {
                        text: er.sub
                        font.pixelSize: 11
                        color: Colors.faint
                    }
                }

                MaterialIcon {
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: er.expanded ? "expand_less" : "expand_more"
                    font.pixelSize: 16
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

            // Matches the island's own inMenu resize duration (see
            // Bar.qml) so the outer panel doesn't lag behind this
            // reveal and clip it mid-animation.
            Behavior on height {
                NumberAnimation {
                    duration: Appearance.anim.durations.menu
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

    // A sliding tab page (same pattern as Control Center's detail
    // pages): retreats toward its own side while fading out.
    component Page: Item {
        id: page

        required property bool shown
        property int edge: 1

        width: parent.width
        x: shown ? 0 : 34 * edge
        opacity: shown ? 1 : 0
        visible: opacity > 0.01

        Behavior on x {
            NumberAnimation {
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.standard
            }
        }
    }

    Item {
        id: pages
        anchors.top: header.bottom
        anchors.topMargin: 14
        width: parent.width
        implicitHeight: root.tab === 0 ? performancePage.implicitHeight
                      : root.tab === 1 ? weatherPage.implicitHeight
                      : customizePage.implicitHeight

        // ============================================================ //
        //  WEATHER                                                      //
        // ============================================================ //
        Page {
            id: weatherPage
            shown: root.tab === 1
            // Middle tab: retreat toward whichever side the now-active
            // tab is on, so the slide direction always reads correctly.
            edge: root.tab === 2 ? -1 : 1
            implicitHeight: weatherContent.implicitHeight

            WeatherTab {
                id: weatherContent
                width: parent.width
            }
        }

        // ============================================================ //
        //  CUSTOMIZE                                                    //
        // ============================================================ //
        Page {
            id: customizePage
            shown: root.tab === 2
            implicitHeight: customizeCol.implicitHeight

            ColumnLayout {
                id: customizeCol
                width: parent.width
                spacing: 12

                // ---- Quick actions: theme switcher / wallpaper switcher ----
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 16

                    component QuickActionButton: StyledRect {
                        id: qab

                        required property string icon
                        required property string label

                        signal activated()

                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 100
                        radius: Appearance.rounding.normal
                        color: qabHover.hovered ? Colors.surfaceHover : Colors.surfaceHigh
                        border.width: 1
                        border.color: Colors.border

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            MaterialIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qab.icon
                                font.pixelSize: 34
                                color: Colors.accent
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qab.label
                                font.pixelSize: 12
                                font.weight: 600
                            }
                        }

                        HoverHandler {
                            id: qabHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: qab.activated()
                        }
                    }

                    QuickActionButton {
                        icon: "palette"
                        label: "Theme"
                        // Setting themeMenuOpen morphs the island straight
                        // from the dashboard into the (already fully
                        // integrated) Themes menu -- GlobalState's own
                        // mutual-exclusion closes the dashboard for us.
                        onActivated: GlobalState.themeMenuOpen = true
                    }
                    QuickActionButton {
                        icon: "wallpaper"
                        label: "Wallpaper"
                        // The wallpaper picker is its own full-screen overlay,
                        // not a Section the dashboard morphs into, so close
                        // the dashboard ourselves before it pops up.
                        onActivated: {
                            Themes.openWallpaperPicker();
                            GlobalState.dashboardOpen = false;
                        }
                    }
                }

                // ---- Animation presets ----
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: animCol.implicitHeight + 32
                    radius: 20
                    color: Colors.surface
                    border.width: 1
                    border.color: Colors.border

                    Column {
                        id: animCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 16
                        spacing: 10

                        RowLayout {
                            width: parent.width

                            MaterialIcon {
                                text: "animation"
                                font.pixelSize: 18
                                color: Colors.accent
                            }
                            StyledText {
                                text: "Animations"
                                font.pixelSize: 13
                                font.weight: 700
                                color: Colors.subtext
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            StyledText {
                                text: HyprConfig.currentAnimation
                                font.pixelSize: 12
                                color: Colors.accent
                            }
                        }

                        // Preset chips; the active one is an accent pill.
                        Flickable {
                            width: parent.width
                            height: 168
                            contentHeight: chipFlow.height
                            clip: true

                            Flow {
                                id: chipFlow
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
                                            font.pixelSize: 12
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
                    }
                }

                // ---- Effects: blur / shadows / borders ----
                // Tap a row (not its switch) to expand a small panel of
                // its actual values -- all live `hyprctl eval` tweaks,
                // like the on/off switches already were.
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: fxCol.implicitHeight + 32
                    radius: 20
                    color: Colors.surface
                    border.width: 1
                    border.color: Colors.border

                    Column {
                        id: fxCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 16
                        spacing: 4

                        Row {
                            spacing: 8
                            height: 28

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "blur_on"
                                font.pixelSize: 18
                                color: Colors.accent
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Effects"
                                font.pixelSize: 13
                                font.weight: 700
                                color: Colors.subtext
                            }
                        }

                        EffectRow {
                            label: "Blur"
                            sub: "Background blur behind windows"
                            checked: HyprConfig.blurEnabled
                            onToggled: HyprConfig.toggleBlur()

                            EffectSlider {
                                label: "Size"
                                value: HyprConfig.blurSize
                                min: 1
                                max: 30
                                onMoved: v => HyprConfig.setBlurSize(v)
                            }
                            EffectSlider {
                                label: "Passes"
                                value: HyprConfig.blurPasses
                                min: 1
                                max: 6
                                onMoved: v => HyprConfig.setBlurPasses(v)
                            }
                            EffectSlider {
                                label: "Vibrancy"
                                value: HyprConfig.blurVibrancy
                                min: 0
                                max: 1
                                integer: false
                                onMoved: v => HyprConfig.setBlurVibrancy(v)
                            }
                            EffectSlider {
                                label: "Vibrancy Darkness"
                                value: HyprConfig.blurVibrancyDarkness
                                min: 0
                                max: 1
                                integer: false
                                onMoved: v => HyprConfig.setBlurVibrancyDarkness(v)
                            }
                        }

                        EffectRow {
                            label: "Shadows"
                            sub: "Drop shadows under windows"
                            checked: HyprConfig.shadowsEnabled
                            onToggled: HyprConfig.toggleShadows()

                            EffectSlider {
                                label: "Range"
                                value: HyprConfig.shadowRange
                                min: 1
                                max: 40
                                onMoved: v => HyprConfig.setShadowRange(v)
                            }
                            EffectSlider {
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
                                    font.pixelSize: 12
                                    color: Colors.subtext
                                }
                                ToggleSwitch {
                                    checked: HyprConfig.shadowSharp
                                    onToggled: HyprConfig.toggleShadowSharp()
                                }
                            }
                        }

                        EffectRow {
                            label: "Borders"
                            sub: "Window border frames"
                            checked: HyprConfig.bordersEnabled
                            onToggled: HyprConfig.toggleBorders()

                            EffectSlider {
                                label: "Border Size"
                                value: HyprConfig.savedBorderSize
                                min: 1
                                max: 5
                                onMoved: v => HyprConfig.setBorderSize(v)
                            }
                        }

                        StyledText {
                            text: "Applied instantly and saved to your Hyprland config — survives reloads and restarts."
                            font.pixelSize: 11
                            color: Colors.faint
                        }
                    }
                }

                // ---- Window: gaps / opacity / rounding ----
                // Same expand-to-reveal-sliders pattern as Effects, just
                // without a switch -- there's no meaningful "off" state
                // for gaps, opacity or rounding.
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: winCol.implicitHeight + 32
                    radius: 20
                    color: Colors.surface
                    border.width: 1
                    border.color: Colors.border

                    Column {
                        id: winCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 16
                        spacing: 4

                        Row {
                            spacing: 8
                            height: 28

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "space_dashboard"
                                font.pixelSize: 18
                                color: Colors.accent
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Window"
                                font.pixelSize: 13
                                font.weight: 700
                                color: Colors.subtext
                            }
                        }

                        EffectRow {
                            label: "Gaps"
                            sub: "Space between and around windows"
                            hasSwitch: false

                            EffectSlider {
                                label: "Gaps In"
                                value: HyprConfig.gapsIn
                                min: 0
                                max: 30
                                onMoved: v => HyprConfig.setGapsIn(v)
                            }
                            EffectSlider {
                                label: "Gaps Out"
                                value: HyprConfig.gapsOut
                                min: 0
                                max: 40
                                onMoved: v => HyprConfig.setGapsOut(v)
                            }
                        }

                        EffectRow {
                            label: "Opacity"
                            sub: "Window transparency"
                            hasSwitch: false

                            EffectSlider {
                                label: "Active Opacity"
                                value: HyprConfig.activeOpacity
                                min: 0.2
                                max: 1
                                integer: false
                                onMoved: v => HyprConfig.setActiveOpacity(v)
                            }
                            EffectSlider {
                                label: "Inactive Opacity"
                                value: HyprConfig.inactiveOpacity
                                min: 0.2
                                max: 1
                                integer: false
                                onMoved: v => HyprConfig.setInactiveOpacity(v)
                            }
                        }

                        EffectRow {
                            label: "Rounding"
                            sub: "Corner radius"
                            hasSwitch: false

                            EffectSlider {
                                label: "Rounding"
                                value: HyprConfig.rounding
                                min: 0
                                max: 25
                                onMoved: v => HyprConfig.setRounding(v)
                            }
                            EffectSlider {
                                label: "Rounding Power"
                                value: HyprConfig.roundingPower
                                min: 2
                                max: 4
                                integer: false
                                onMoved: v => HyprConfig.setRoundingPower(v)
                            }
                        }
                    }
                }
            }
        }

        // ============================================================ //
        //  PERFORMANCE                                                  //
        // ============================================================ //
        Page {
            id: performancePage
            shown: root.tab === 0
            edge: -1
            implicitHeight: perfRow.implicitHeight

            RowLayout {
                id: perfRow
                width: parent.width
                spacing: 10

                GridLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 10

                    // A wide processor tile: model name, temperature
                    // bar, usage squircle on the right.
                    component ProcessorTile: StatCard {
                        id: proc

                        property string model: ""
                        property real usage: 0
                        property int temp: 0
                        // 0 hides the FREQ row entirely -- the GPU tile
                        // reuses this component but leaves it unset.
                        property real freqMHz: 0

                        Layout.fillWidth: true
                        Layout.columnSpan: 2

                        Item {
                            width: parent.width
                            height: Math.max(74, infoCol.implicitHeight)

                            Column {
                                id: infoCol
                                anchors.left: parent.left
                                anchors.right: squircle.left
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 9

                                StyledText {
                                    width: parent.width
                                    text: proc.model || "—"
                                    elide: Text.ElideRight
                                    font.pixelSize: 15
                                    font.weight: 600
                                }

                                // Temperature bar: cool = accent,
                                // warming = amber-ish danger blend.
                                Row {
                                    width: parent.width
                                    spacing: 10

                                    MonoText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "TEMP"
                                        font.pixelSize: 10
                                        font.weight: 700
                                        color: Colors.faint
                                    }

                                    Item {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 46 - 52 - 20
                                        height: 7

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 3.5
                                            color: Colors.surfaceHigh
                                        }
                                        Rectangle {
                                            width: parent.width * Math.max(0, Math.min(1, proc.temp / 100))
                                            height: parent.height
                                            radius: 3.5
                                            color: proc.temp >= 80 ? Colors.danger : Colors.accent

                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: Appearance.anim.durations.expand
                                                    easing.type: Easing.BezierSpline
                                                    easing.bezierCurve: Appearance.anim.curves.emphasized
                                                }
                                            }
                                        }
                                    }

                                    MonoText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: proc.temp + "°C"
                                        font.pixelSize: 13
                                        font.weight: 700
                                    }
                                }

                                // Live clock speed -- CPU only (freqMHz
                                // stays 0 on the GPU tile, so this row
                                // just doesn't take up any space there).
                                Row {
                                    width: parent.width
                                    spacing: 10
                                    visible: proc.freqMHz > 0

                                    MonoText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "FREQ"
                                        font.pixelSize: 10
                                        font.weight: 700
                                        color: Colors.faint
                                    }
                                    MonoText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (proc.freqMHz / 1000).toFixed(2) + " GHz"
                                        font.pixelSize: 13
                                        font.weight: 700
                                        color: Colors.accent
                                    }
                                }
                            }

                            // Usage squircle.
                            StyledRect {
                                id: squircle
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 68
                                height: 68
                                radius: 24
                                color: Colors.surfaceHigh
                                border.width: 1
                                border.color: Qt.alpha(Colors.accent, 0.3)

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 0

                                    MonoText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: Math.round(proc.usage * 100) + "%"
                                        font.pixelSize: 17
                                        font.weight: 800
                                        color: Colors.accent
                                    }
                                    MonoText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "USAGE"
                                        font.pixelSize: 8
                                        font.weight: 700
                                        color: Colors.faint
                                    }
                                }
                            }
                        }
                    }

                    ProcessorTile {
                        icon: "memory"
                        title: "CPU"
                        model: SysMonitor.cpuModel
                        usage: SysMonitor.cpuUsage
                        temp: SysMonitor.cpuTemp
                        freqMHz: SysMonitor.cpuFreqMHz
                    }

                    ProcessorTile {
                        visible: SysMonitor.gpuAvailable
                        icon: "developer_board"
                        title: "GPU"
                        model: SysMonitor.gpuModel
                        usage: SysMonitor.gpuUsage
                        temp: SysMonitor.gpuTemp
                    }

                    // ---- Storage ----
                    // Always the main drive (mounted at "/"), no picker.
                    StatCard {
                        id: storageCard
                        icon: "hard_drive"
                        title: "Storage"
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop

                        readonly property var disk: SysMonitor.disks.find(d => d.target === "/") ?? SysMonitor.disks[0] ?? null

                        Column {
                            width: parent.width
                            spacing: 10

                            CircularProgress {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 92
                                height: 92
                                value: storageCard.disk ? storageCard.disk.used / storageCard.disk.size : 0

                                MonoText {
                                    anchors.centerIn: parent
                                    text: storageCard.disk ? Math.round(storageCard.disk.used / storageCard.disk.size * 100) + "%" : "—"
                                    font.pixelSize: 17
                                    font.weight: 800
                                }
                            }

                            MonoText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: storageCard.disk
                                    ? SysMonitor.fmtBytes(storageCard.disk.used) + " / " + SysMonitor.fmtBytes(storageCard.disk.size)
                                    : "no data"
                                font.pixelSize: 12
                                color: Colors.subtext
                            }
                        }
                    }

                    // ---- Memory ----
                    StatCard {
                        icon: "sd_card"
                        title: "Memory"
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop

                        Column {
                            width: parent.width
                            spacing: 10

                            CircularProgress {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 92
                                height: 92
                                value: SysMonitor.memTotal > 0 ? SysMonitor.memUsed / SysMonitor.memTotal : 0

                                MonoText {
                                    anchors.centerIn: parent
                                    text: SysMonitor.memTotal > 0 ? Math.round(SysMonitor.memUsed / SysMonitor.memTotal * 100) + "%" : "—"
                                    font.pixelSize: 17
                                    font.weight: 800
                                }
                            }

                            MonoText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: SysMonitor.memTotal > 0
                                    ? SysMonitor.fmtBytes(SysMonitor.memUsed) + " / " + SysMonitor.fmtBytes(SysMonitor.memTotal)
                                    : "no data"
                                font.pixelSize: 12
                                color: Colors.subtext
                            }
                        }
                    }

                    // ---- Network ----
                    StatCard {
                        icon: "lan"
                        title: "Network" + (SysMonitor.netInterface ? " · " + SysMonitor.netInterface : "")
                        Layout.fillWidth: true
                        Layout.columnSpan: 2

                        Item {
                            width: parent.width
                            height: 44

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 26

                                Row {
                                    spacing: 7

                                    MaterialIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "arrow_downward"
                                        font.pixelSize: 17
                                        color: Colors.accent
                                    }
                                    MonoText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: SysMonitor.fmtSpeed(SysMonitor.downSpeed)
                                        font.pixelSize: 14
                                        font.weight: 700
                                    }
                                }

                                Row {
                                    spacing: 7

                                    MaterialIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "arrow_upward"
                                        font.pixelSize: 17
                                        color: Colors.subtext
                                    }
                                    MonoText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: SysMonitor.fmtSpeed(SysMonitor.upSpeed)
                                        font.pixelSize: 14
                                        font.weight: 700
                                    }
                                }
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                MaterialIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "swap_vert"
                                    font.pixelSize: 15
                                    color: Colors.faint
                                }
                                MonoText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: SysMonitor.fmtBytes(SysMonitor.totalRx + SysMonitor.totalTx) + " total"
                                    font.pixelSize: 12
                                    color: Colors.subtext
                                }
                            }
                        }
                    }
                }

                // ---- Battery: vertical fluid glass pill ----
                StyledRect {
                    id: battPill

                    // Only a real, physical battery -- no fallback to
                    // other UPower devices (mice, keyboards, ...). Clamped
                    // defensively: everything downstream (fill height,
                    // low-battery threshold) derives from this, so one
                    // clamp here is enough to guarantee the fill can never
                    // compute taller than the card even if Battery.percent
                    // ever glitches above 100.
                    readonly property real pct: Battery.available ? Math.max(0, Math.min(1, Battery.percent / 100)) : 0
                    readonly property bool charging: Battery.available && Battery.charging
                    readonly property bool low: battPill.pct <= 0.2 && !battPill.charging
                    readonly property color tint: battPill.low ? Colors.danger : Colors.accent

                    // Drives both the charging shimmer sweep and the
                    // bolt icon's breathing pulse below from one shared
                    // clock. Both read it through a plain binding rather
                    // than a `Behavior`/`on opacity` animation, so the
                    // instant charging goes false they snap cleanly back
                    // to their static values instead of freezing
                    // mid-pulse wherever the loop happened to be.
                    property real chargeT: 0
                    NumberAnimation on chargeT {
                        running: battPill.charging
                        loops: Animation.Infinite
                        from: 0
                        to: 1
                        duration: 1600
                    }

                    visible: Battery.available
                    Layout.preferredWidth: 84
                    Layout.fillHeight: true
                    Layout.minimumHeight: 300
                    radius: 28
                    color: Colors.surface
                    border.width: 1
                    border.color: Colors.border
                    // Cheap rectangular safety net: whatever the inner
                    // ClippingRectangle's shader-mask does with rounded
                    // corners, nothing can ever escape the card's plain
                    // bounding box (its own top edge included) on top of
                    // that.
                    clip: true

                    // Everything -- the fill AND the
                    // icon/percentage/status text -- lives inside this one
                    // ClippingRectangle (same type the island itself uses
                    // in Bar.qml) so it's ALL clipped to the same properly
                    // rounded shape. Previously the text groups sat
                    // outside it as plain siblings of `clipped`, so with
                    // this card only 84px wide, the bottom status label
                    // (nearly as wide as the card) could reach into the
                    // bottom-corner arcs and read as if it were being cut
                    // by the rounded silhouette rather than sitting inside
                    // it -- putting it in the same clipped container fixes
                    // that at the source instead of just nudging margins.
                    ClippingRectangle {
                        id: clipped
                        anchors.fill: parent
                        anchors.margins: battPill.border.width
                        radius: battPill.radius - battPill.border.width
                        color: "transparent"

                        // The fluid fill: strictly bottom-anchored, height
                        // a straight fraction of the container (clamped so
                        // it can never exceed the container's own height),
                        // with a gradient for depth.
                        Rectangle {
                            id: fill
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            // Explicit zero margins: the fill (and the
                            // highlight lines below, which mirror its
                            // width) must match `clipped`'s inner width
                            // exactly, with nothing wider that could
                            // catch the ClippingRectangle's edge and read
                            // as bleeding past the capsule's sides.
                            anchors.leftMargin: 0
                            anchors.rightMargin: 0
                            height: Math.min(parent.height * battPill.pct, parent.height)

                            // Deliberately square-topped. Rounding the
                            // fill's own top corners meant its curve had
                            // to be reconciled with the capsule's wider
                            // corner arcs as the level rose into them --
                            // any mismatch left thin dark wedges at the
                            // top corners, and even when it didn't, the
                            // surface read as a bulging blob rather than
                            // a liquid line. `clipped` already masks
                            // everything to the capsule silhouette, so a
                            // flat top gives a clean straight surface at
                            // every level and seats itself perfectly into
                            // the top curve at full charge for free.
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0.0; color: Qt.alpha(battPill.tint, 0.6) }
                                GradientStop { position: 1.0; color: Qt.alpha(battPill.tint, 0.14) }
                            }

                            Behavior on height {
                                NumberAnimation {
                                    duration: Appearance.anim.durations.expand
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Appearance.anim.curves.emphasized
                                }
                            }

                            // Surface line of the "fluid", with a soft
                            // glow above it. Both are plain flat strips
                            // spanning the full width, exactly like the
                            // fill's own (now flat) top edge, so the three
                            // stay perfectly in register and `clipped`
                            // trims all of them to the capsule together.
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.topMargin: -4
                                height: 4
                                opacity: 0.35
                                color: battPill.tint
                            }
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 2
                                color: battPill.tint
                            }

                            // Charging shimmer: a soft highlight band
                            // that rises through the fill on a loop,
                            // fading in and out at each end of its own
                            // sweep (via the triangle-shaped opacity
                            // below) so the point where the loop resets
                            // never reads as a cut.
                            Rectangle {
                                visible: battPill.charging
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 34
                                y: (parent.height + height) * (1 - battPill.chargeT) - height
                                opacity: Math.min(battPill.chargeT, 1 - battPill.chargeT) * 0.8
                                gradient: Gradient {
                                    orientation: Gradient.Vertical
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 0.5; color: Qt.lighter(battPill.tint, 1.7) }
                                    GradientStop { position: 1.0; color: "transparent" }
                                }
                            }
                        }

                        // Icon + percentage pinned to the TOP, status
                        // label pinned to the BOTTOM -- keeps both clear
                        // of each other regardless of fill height, instead
                        // of one Column centered on top of a fill that
                        // moves independently of it. Each sits on its own
                        // translucent dark scrim so the text stays
                        // readable whether the fill is behind it or not
                        // (at high charge the top group can end up over
                        // the fill; the bottom label always does, since
                        // the fill's own bottom edge is the card's bottom
                        // edge) -- a fixed dark backing is simpler and
                        // more reliable across themes than recomputing
                        // text color from whatever the current accent hue
                        // is. Matching 20px top/bottom margins keep both
                        // groups' bounds clear of the 28px corner-radius
                        // arcs at this card's 84px width, with genuinely
                        // equal top/bottom breathing room instead of just
                        // "clipped correctly but visually cramped".
                        Rectangle {
                            id: topScrim
                            anchors.top: parent.top
                            anchors.topMargin: 20
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: topCol.implicitWidth + 18
                            height: topCol.implicitHeight + 12
                            radius: height / 2
                            color: Qt.rgba(0, 0, 0, 0.28)

                            Column {
                                id: topCol
                                anchors.centerIn: parent
                                spacing: 2

                                MaterialIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Battery.icon
                                    font.pixelSize: 20
                                    color: battPill.charging ? Colors.accent : battPill.low ? Colors.danger : Colors.text
                                    opacity: battPill.charging ? 0.65 + 0.35 * Math.sin(battPill.chargeT * Math.PI * 2) : 1.0

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Appearance.anim.durations.normal
                                        }
                                    }
                                }
                                MonoText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Battery.percent + "%"
                                    font.pixelSize: 19
                                    font.weight: 800
                                    color: Colors.text
                                }
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 20
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: statusText.implicitWidth + 18
                            height: statusText.implicitHeight + 10
                            radius: height / 2
                            color: Qt.rgba(0, 0, 0, 0.28)

                            StyledText {
                                id: statusText
                                anchors.centerIn: parent
                                text: battPill.charging ? "Charging" : battPill.low ? "Low" : "On Battery"
                                font.pixelSize: 10
                                font.weight: 700
                                color: battPill.charging ? Colors.accent : battPill.low ? Colors.danger : Colors.text
                            }
                        }
                    }
                }
            }
        }
    }
}
