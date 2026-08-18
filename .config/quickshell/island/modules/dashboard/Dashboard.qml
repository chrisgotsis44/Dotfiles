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
// Two tabs behind an animated segmented control:
//   Performance  (left) live system stats from SysMonitor, which only
//                polls while this dashboard is open.
//   Weather      (right) full forecast panel (WeatherTab.qml) fed by
//                services/WeatherData.qml -- hero card with ambient
//                condition animations, hourly curve, 7-day list,
//                sun arc & moon phase.
//
// There used to be a third Customize tab (Hyprland animation presets +
// blur/shadow/border/gap/opacity/rounding sliders); all of it moved to
// the Settings panel (SUPER+S, modules/settings/), which is a centered
// overlay window rather than an island morph.
//
// Tab switches slide+fade the same way Control Center's detail pages
// do; the island morphs its height around whichever tab is active.
Item {
    id: root

    implicitWidth: 724
    implicitHeight: header.height + 14 + pages.implicitHeight

    property int tab: 0 // 0 = Performance, 1 = Weather

    function handleOpen(): void {
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
        width: 380
        height: 44
        radius: 22
        color: Colors.surface
        border.width: 1
        border.color: Colors.border

        // The sliding thumb.
        Rectangle {
            id: thumb
            width: parent.width / 2 - 5
            height: parent.height - 8
            radius: height / 2
            y: 4
            x: root.tab === 0 ? 4
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
                    { label: "Weather", icon: "partly_cloudy_day" }
                ]

                Item {
                    id: segment

                    required property var modelData
                    required property int index

                    width: header.width / 2
                    height: header.height

                    Row {
                        anchors.centerIn: parent
                        spacing: 7

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: segment.modelData.icon
                            font.pixelSize: Appearance.font.px(17)
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
                            font.pixelSize: Appearance.font.px(14)
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
                      : weatherPage.implicitHeight

        // ============================================================ //
        //  WEATHER                                                      //
        // ============================================================ //
        Page {
            id: weatherPage
            shown: root.tab === 1
            edge: 1
            implicitHeight: weatherContent.implicitHeight

            WeatherTab {
                id: weatherContent
                width: parent.width
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
                                    font.pixelSize: Appearance.font.px(15)
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
                                        font.pixelSize: Appearance.font.px(10)
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
                                        font.pixelSize: Appearance.font.px(13)
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
                                        font.pixelSize: Appearance.font.px(10)
                                        font.weight: 700
                                        color: Colors.faint
                                    }
                                    MonoText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (proc.freqMHz / 1000).toFixed(2) + " GHz"
                                        font.pixelSize: Appearance.font.px(13)
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
                                        font.pixelSize: Appearance.font.px(17)
                                        font.weight: 800
                                        color: Colors.accent
                                    }
                                    MonoText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "USAGE"
                                        font.pixelSize: Appearance.font.px(8)
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
                                    font.pixelSize: Appearance.font.px(17)
                                    font.weight: 800
                                }
                            }

                            MonoText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: storageCard.disk
                                    ? SysMonitor.fmtBytes(storageCard.disk.used) + " / " + SysMonitor.fmtBytes(storageCard.disk.size)
                                    : "no data"
                                font.pixelSize: Appearance.font.px(12)
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
                                    font.pixelSize: Appearance.font.px(17)
                                    font.weight: 800
                                }
                            }

                            MonoText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: SysMonitor.memTotal > 0
                                    ? SysMonitor.fmtBytes(SysMonitor.memUsed) + " / " + SysMonitor.fmtBytes(SysMonitor.memTotal)
                                    : "no data"
                                font.pixelSize: Appearance.font.px(12)
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
                                        font.pixelSize: Appearance.font.px(17)
                                        color: Colors.accent
                                    }
                                    MonoText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: SysMonitor.fmtSpeed(SysMonitor.downSpeed)
                                        font.pixelSize: Appearance.font.px(14)
                                        font.weight: 700
                                    }
                                }

                                Row {
                                    spacing: 7

                                    MaterialIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "arrow_upward"
                                        font.pixelSize: Appearance.font.px(17)
                                        color: Colors.subtext
                                    }
                                    MonoText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: SysMonitor.fmtSpeed(SysMonitor.upSpeed)
                                        font.pixelSize: Appearance.font.px(14)
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
                                    font.pixelSize: Appearance.font.px(15)
                                    color: Colors.faint
                                }
                                MonoText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: SysMonitor.fmtBytes(SysMonitor.totalRx + SysMonitor.totalTx) + " total"
                                    font.pixelSize: Appearance.font.px(12)
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
                                    font.pixelSize: Appearance.font.px(20)
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
                                    font.pixelSize: Appearance.font.px(19)
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
                                font.pixelSize: Appearance.font.px(10)
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
