pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import qs.config
import qs.services
import qs.components

// The Control Center — rendered INSIDE the island, so this root is a
// transparent Item; the island supplies the panel, border and clipping.
//
// Two-level navigation, iOS style:
//   view === "main"                     the toggle grid + sliders + media + notifs
//   view === "wifi"|"audio"|"bluetooth" a detail list for that setting
//
// Right-clicking the Wi-Fi / Audio / Bluetooth tiles pushes the detail
// view; its Back button pops. The transition is a horizontal slide-fade:
// the outgoing page slips 28px toward its own side while fading, the
// incoming one slides to x=0 — and because the pages' implicitHeight
// feeds the island's size bindings, the island itself morphs taller or
// shorter to fit the incoming page as part of the same gesture.
Item {
    id: root

    implicitWidth: 460
    implicitHeight: pages.implicitHeight

    property string view: "main"

    // Which network's inline password prompt is open, if any -- set by
    // the wifi delegate below, empty when none is.
    property string wifiPasswordSsid: ""

    // Refresh device lists the moment their page is pushed.
    onViewChanged: {
        if (view === "wifi") {
            Network.scan();
        } else if (view === "bluetooth") {
            Bluetooth.refreshDevices();
        }
        if (view !== "wifi") {
            root.wifiPasswordSsid = "";
            Network.connectError = "";
        }
    }

    // Always reopen on the main grid.
    Connections {
        target: GlobalState
        function onControlCenterOpenChanged() {
            if (!GlobalState.controlCenterOpen)
                root.view = "main";
        }
    }

    // A sliding page. `edge` is which side it retreats to when hidden:
    // -1 for the main grid (slides left), +1 for detail views (right).
    component Page: Item {
        id: page

        required property bool shown
        property int edge: 1

        width: parent.width
        x: shown ? 0 : 28 * edge
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
        width: parent.width
        // The island's height Behavior animates this jump into a morph.
        implicitHeight: root.view === "main" ? mainPage.implicitHeight
                      : root.view === "wifi" ? wifiPage.implicitHeight
                      : root.view === "audio" ? audioPage.implicitHeight
                      : root.view === "pomodoro" ? pomoPage.implicitHeight
                      : btPage.implicitHeight

        // ============================================================ //
        //  MAIN PAGE                                                    //
        // ============================================================ //
        Page {
            id: mainPage
            shown: root.view === "main"
            edge: -1
            implicitHeight: mainLayout.implicitHeight

            ColumnLayout {
                id: mainLayout
                width: parent.width
                spacing: 12

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 8

                    // Left-click toggles, right-click opens the network list.
                    // The ethernet badge/sub-text reflect a wired connection
                    // independently of Wi-Fi's own on/off state. A captive
                    // portal takes priority over both -- "connected" is
                    // misleading when there's actually no real internet
                    // access yet.
                    CcToggle {
                        Layout.fillWidth: true
                        icon: "wifi"
                        label: "Wi-Fi"
                        sub: Network.portalDetected ? "Sign-in required"
                           : Network.connected ? Network.ssid
                           : Network.ethernetConnected ? "Ethernet connected"
                           : Network.wifiEnabled ? "Not connected" : "Off"
                        active: Network.wifiEnabled
                        hasDetail: true
                        badgeIcon: Network.portalDetected ? "warning" : Network.ethernetConnected ? "settings_ethernet" : ""
                        onToggled: Network.toggleWifi()
                        onRightClicked: root.view = "wifi"
                    }
                    CcToggle {
                        Layout.fillWidth: true
                        icon: Audio.muted ? "volume_off" : "volume_up"
                        label: "Audio"
                        sub: Audio.muted ? "Muted" : Math.round(Audio.volume * 100) + "%"
                        active: !Audio.muted
                        hasDetail: true
                        onToggled: Audio.toggleMute()
                        onRightClicked: root.view = "audio"
                    }
                    CcToggle {
                        Layout.fillWidth: true
                        icon: "bluetooth"
                        label: "Bluetooth"
                        sub: Bluetooth.powered ? "On" : "Off"
                        active: Bluetooth.powered
                        hasDetail: true
                        onToggled: Bluetooth.toggle()
                        onRightClicked: root.view = "bluetooth"
                    }
                    // Runs ~/.local/bin/idle-inhibitor.sh (async, detached).
                    CcToggle {
                        Layout.fillWidth: true
                        icon: "desktop_windows"
                        label: "Display"
                        sub: GlobalState.keepAwake ? "Keeping awake" : "Normal"
                        active: GlobalState.keepAwake
                        onToggled: GlobalState.toggleKeepAwake()
                    }
                    CcToggle {
                        Layout.fillWidth: true
                        icon: "self_improvement"
                        label: "Peace"
                        sub: GlobalState.dnd ? "Notifications muted" : "Off"
                        active: GlobalState.dnd
                        onToggled: GlobalState.dnd = !GlobalState.dnd
                    }
                    // Laptops (Battery.available) get a Power Mode tile
                    // that cycles power-profiles-daemon profiles instead
                    // of Night Light -- Night Light stays put on desktops,
                    // where there's no battery to manage. Runs
                    // ~/.local/bin/night-mode.sh (async, detached) for the
                    // Night Light branch.
                    CcToggle {
                        Layout.fillWidth: true
                        icon: Battery.available ? PowerProfiles.icon : "nightlight"
                        label: Battery.available ? "Power Mode" : "Night Light"
                        sub: Battery.available ? PowerProfiles.label : (GlobalState.nightLight ? "On" : "Off")
                        active: Battery.available ? PowerProfiles.profile === "performance" : GlobalState.nightLight
                        onToggled: Battery.available ? PowerProfiles.cycle() : GlobalState.toggleNightLight()
                    }
                }

                // Clocks. Sized and shaped like the toggle grid above so
                // the two rows read as one block, not as a widget bolted
                // on between the toggles and the sliders.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // One tile, two clocks: right-click switches between
                    // stopwatch and countdown. Stopwatch is the default --
                    // it needs no setup, so it is the one that does
                    // something useful the instant you click it.
                    TimerTile {
                        Layout.fillWidth: true
                        hasSecondary: true

                        icon: Timers.isStopwatch ? "timelapse" : "timer"
                        label: Timers.isStopwatch ? "Stopwatch" : "Timer"
                        readout: Timers.isStopwatch ? Timers.fmt(Timers.swElapsed) : Timers.fmt(Timers.timerActive ? Timers.timerRemaining : Timers.timerDuration)
                        sub: {
                            if (Timers.isStopwatch)
                                return Timers.swRunning ? "" : Timers.swActive ? "Paused" : "Right-click for timer";
                            if (!Timers.timerActive)
                                return "Tap ± to set";
                            return Timers.timerRunning ? "" : "Paused";
                        }
                        running: Timers.isStopwatch ? Timers.swRunning : Timers.timerRunning
                        // Counting up has no end, so there is no fraction
                        // to draw around the stopwatch's button.
                        progress: Timers.isStopwatch ? -1 : (Timers.timerActive && Timers.timerDuration > 0 ? 1 - Timers.timerRemaining / Timers.timerDuration : -1)

                        // In timer mode, before it starts, the buttons set
                        // the duration; once a countdown is in flight there
                        // is nothing to set, so the lower one becomes the
                        // reset. The stopwatch only ever needs the reset.
                        rightIcon: !Timers.isStopwatch && !Timers.timerActive ? "add" : ""
                        leftIcon: Timers.isStopwatch ? (Timers.swActive ? "replay" : "") : (Timers.timerActive ? "replay" : "remove")

                        onPrimaryClicked: Timers.isStopwatch ? Timers.swToggle() : Timers.timerToggle()
                        onRightClicked: if (!Timers.isStopwatch)
                            Timers.timerAdjust(1)
                        onLeftClicked: {
                            if (Timers.isStopwatch)
                                Timers.swReset();
                            else if (Timers.timerActive)
                                Timers.timerReset();
                            else
                                Timers.timerAdjust(-1);
                        }
                        onSecondaryClicked: Timers.toggleClockMode()
                    }

                    TimerTile {
                        Layout.fillWidth: true
                        hasSecondary: true

                        icon: "local_fire_department"
                        label: "Pomodoro"
                        readout: Timers.fmt(Timers.pomoRemaining)
                        sub: `${Timers.pomoLabel} · ${Timers.pomoCompleted} done`
                        running: Timers.pomoRunning
                        progress: 1 - Timers.pomoRemaining / Timers.pomoPhaseLength

                        rightIcon: "skip_next"
                        leftIcon: "replay"

                        onPrimaryClicked: Timers.pomoToggle()
                        onRightClicked: Timers.pomoSkip()
                        onLeftClicked: Timers.pomoReset()
                        onSecondaryClicked: root.view = "pomodoro"
                    }
                }

                CcSlider {
                    Layout.fillWidth: true
                    implicitHeight: 54
                    icon: Audio.muted ? "volume_off" : "volume_up"
                    value: Audio.volume
                    onMoved: v => Audio.setVolume(v)
                }

                // Hidden entirely when no backlight device exists —
                // ColumnLayout skips invisible items, so the panel
                // reflows (and the island morphs) around it.
                CcSlider {
                    Layout.fillWidth: true
                    visible: Brightness.available
                    implicitHeight: 54
                    icon: "brightness_6"
                    value: Brightness.value
                    onMoved: v => Brightness.setBrightness(v)
                }

                WeatherCard {
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2

                    StyledText {
                        text: "Notifications"
                        font.pixelSize: 15
                        font.weight: 600
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledText {
                        visible: notifList.count > 0
                        text: "Clear all"
                        font.pixelSize: 13
                        font.weight: 600
                        color: clearHover.hovered ? Colors.accent : Colors.subtext

                        HoverHandler {
                            id: clearHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: Notifs.clearAll()
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: notifList.count > 0 ? Math.min(260, notifList.contentHeight) : 52

                    Behavior on Layout.preferredHeight {
                        NumberAnimation {
                            duration: Appearance.anim.durations.normal
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.anim.curves.emphasized
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: notifList.count === 0
                        text: "All caught up"
                        font.pixelSize: 14
                        color: Colors.faint
                    }

                    ListView {
                        id: notifList
                        anchors.fill: parent
                        clip: true
                        spacing: 8
                        model: Notifs.list

                        delegate: NotifCard {
                            required property Notification modelData
                            width: notifList.width
                            notif: modelData
                        }

                        add: Transition {
                            NumberAnimation {
                                properties: "opacity"
                                from: 0
                                to: 1
                                duration: Appearance.anim.durations.normal
                            }
                        }
                        displaced: Transition {
                            NumberAnimation {
                                properties: "y"
                                duration: Appearance.anim.durations.normal
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.anim.curves.standard
                            }
                        }
                    }
                }
            }
        }

        // ============================================================ //
        //  DETAIL PAGES                                                 //
        // ============================================================ //
        Page {
            id: wifiPage
            shown: root.view === "wifi"
            implicitHeight: wifiDetail.implicitHeight

            DetailView {
                id: wifiDetail
                width: parent.width
                title: "Wi-Fi Networks"
                busy: Network.scanning
                model: Network.networks
                onBack: root.view = "main"
                onRefresh: Network.scan()

                delegate: StyledRect {
                    id: wifiRow

                    required property var modelData

                    // A secured network only needs a password prompt if
                    // nmcli doesn't already have a saved profile for it
                    // (i.e. it's genuinely new -- previously-joined
                    // networks, and the currently active one, connect
                    // straight away with no prompt).
                    readonly property bool isSaved: Network.savedConnections.includes(wifiRow.modelData.ssid)
                    readonly property bool needsPassword: wifiRow.modelData.secure && !wifiRow.isSaved
                    readonly property bool expanded: root.wifiPasswordSsid === wifiRow.modelData.ssid
                    readonly property bool isConnecting: Network.connectingSsid === wifiRow.modelData.ssid

                    // Brief accent flash the moment this row's connection
                    // attempt actually succeeds -- the "nice switching
                    // animation": a settle-in pulse on the row that just
                    // won, instead of it silently reappearing at the top
                    // of the re-sorted list a beat later.
                    property bool justConnected: false

                    function activate(): void {
                        if (wifiRow.isConnecting)
                            return;
                        if (wifiRow.modelData.inUse) {
                            Network.disconnect(wifiRow.modelData.ssid);
                            root.wifiPasswordSsid = "";
                        } else if (wifiRow.needsPassword) {
                            root.wifiPasswordSsid = wifiRow.expanded ? "" : wifiRow.modelData.ssid;
                        } else {
                            Network.connectTo(wifiRow.modelData.ssid);
                        }
                    }

                    function submitPassword(): void {
                        if (pwField.text.length === 0)
                            return;
                        Network.connectWithPassword(wifiRow.modelData.ssid, pwField.text);
                    }

                    onExpandedChanged: if (wifiRow.expanded)
                        pwField.forceActiveFocus()

                    // Closes this row's prompt and fires the connect flash
                    // the moment nmcli actually confirms the connection --
                    // independent of whichever row is expanded when it fires.
                    Connections {
                        target: Network
                        function onConnectSucceeded(ssid: string) {
                            if (ssid === wifiRow.modelData.ssid) {
                                pwField.text = "";
                                root.wifiPasswordSsid = "";
                                wifiRow.justConnected = true;
                                justConnectedTimer.restart();
                            }
                        }
                    }

                    Timer {
                        id: justConnectedTimer
                        interval: 900
                        onTriggered: wifiRow.justConnected = false
                    }

                    width: ListView.view.width
                    implicitHeight: col.implicitHeight
                    radius: 14
                    clip: true
                    color: wifiRow.justConnected ? Colors.accentDim
                         : rowHover.hovered ? Colors.surfaceHover : Colors.surface

                    Behavior on implicitHeight {
                        NumberAnimation {
                            duration: Appearance.anim.durations.normal
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.anim.curves.emphasized
                        }
                    }

                    Column {
                        id: col
                        width: parent.width

                        Item {
                            id: rowTop
                            width: parent.width
                            height: 54

                            // Hover covers the WHOLE row (including the
                            // forget button's own area) purely to reveal
                            // that button -- if this were scoped to just
                            // the tap-to-connect zone below, moving the
                            // cursor onto the button would immediately
                            // un-hover and hide it out from under the
                            // pointer.
                            HoverHandler {
                                id: rowHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            // Trailing accessory buttons -- sign-in (only
                            // for the active row, only behind a captive
                            // portal) and forget (any saved row, revealed
                            // on hover). Both live in their own tap zone
                            // at the row's right edge, kept physically
                            // separate from the connect/disconnect zone
                            // below rather than overlapping it -- see
                            // Dashboard's EffectRow for why that matters
                            // (sibling TapHandlers don't respect
                            // containment the way MouseArea hit-testing
                            // did, so an overlapping one here would fire
                            // activate() together with whichever button
                            // was actually tapped).
                            Row {
                                id: trailing
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                StyledRect {
                                    id: portalBtn
                                    visible: wifiRow.modelData.inUse && Network.portalDetected
                                    implicitWidth: portalLabel.implicitWidth + 20
                                    implicitHeight: 28
                                    radius: 14
                                    color: portalHover.hovered ? Colors.accentDim : Colors.accent

                                    StyledText {
                                        id: portalLabel
                                        anchors.centerIn: parent
                                        text: "Sign in"
                                        font.pixelSize: 12
                                        font.weight: 600
                                        color: Colors.accentFg
                                    }
                                    HoverHandler {
                                        id: portalHover
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                    TapHandler {
                                        onTapped: Network.openPortal()
                                    }
                                }

                                IconButton {
                                    id: forgetBtn
                                    visible: wifiRow.isSaved && rowHover.hovered && !wifiRow.expanded
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 28
                                    iconSize: 15
                                    icon: "delete"
                                    onClicked: Network.forget(wifiRow.modelData.ssid)
                                }
                            }

                            Item {
                                anchors.left: parent.left
                                anchors.right: (portalBtn.visible || forgetBtn.visible) ? trailing.left : parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Item {
                                        implicitWidth: 22
                                        implicitHeight: 22

                                        // Signal icon, hidden while
                                        // connecting so the spinner below
                                        // reads as its replacement, not a
                                        // second icon next to it.
                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            visible: !wifiRow.isConnecting
                                            text: wifiRow.modelData.signal >= 70 ? "signal_wifi_4_bar"
                                                : wifiRow.modelData.signal >= 45 ? "network_wifi_3_bar"
                                                : wifiRow.modelData.signal >= 20 ? "network_wifi_2_bar"
                                                : "network_wifi_1_bar"
                                            font.pixelSize: 18
                                            color: wifiRow.modelData.inUse ? Colors.accent : Colors.subtext
                                        }

                                        // Breathing "connecting" glyph --
                                        // the switching animation's main
                                        // cue while nmcli is still working.
                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            visible: wifiRow.isConnecting
                                            text: "sync"
                                            font.pixelSize: 18
                                            color: Colors.accent

                                            SequentialAnimation on opacity {
                                                running: wifiRow.isConnecting
                                                loops: Animation.Infinite
                                                NumberAnimation {
                                                    to: 0.3
                                                    duration: 550
                                                    easing.type: Easing.InOutQuad
                                                }
                                                NumberAnimation {
                                                    to: 1
                                                    duration: 550
                                                    easing.type: Easing.InOutQuad
                                                }
                                            }
                                            RotationAnimation on rotation {
                                                running: wifiRow.isConnecting
                                                loops: Animation.Infinite
                                                from: 0
                                                to: 360
                                                duration: 1400
                                            }
                                        }
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        StyledText {
                                            width: parent.width
                                            text: wifiRow.modelData.ssid
                                            elide: Text.ElideRight
                                            font.pixelSize: 14
                                            font.weight: wifiRow.modelData.inUse ? 700 : 400
                                        }

                                        // Only takes up space while
                                        // actually connecting -- collapses
                                        // straight back out once it settles
                                        // one way or the other.
                                        StyledText {
                                            width: parent.width
                                            visible: wifiRow.isConnecting
                                            text: "Connecting…"
                                            font.pixelSize: 11
                                            color: Colors.accent
                                        }
                                    }

                                    MaterialIcon {
                                        visible: wifiRow.modelData.secure
                                        text: "lock"
                                        font.pixelSize: 14
                                        color: Colors.faint
                                    }

                                    // Pops in with a slight overshoot
                                    // rather than just appearing -- the
                                    // "arrived" beat at the end of the
                                    // connecting animation.
                                    MaterialIcon {
                                        id: checkIcon
                                        text: "check"
                                        font.pixelSize: 14
                                        color: Colors.accent
                                        opacity: wifiRow.modelData.inUse ? 1 : 0
                                        scale: wifiRow.modelData.inUse ? 1 : 0.4
                                        visible: opacity > 0.01

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: Appearance.anim.durations.fast
                                            }
                                        }
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: Appearance.anim.durations.normal
                                                easing.type: Easing.BezierSpline
                                                easing.bezierCurve: Appearance.anim.curves.expressive
                                            }
                                        }
                                    }
                                }

                                TapHandler {
                                    onTapped: wifiRow.activate()
                                }
                            }
                        }

                        // Inline password entry -- only while this
                        // specific row's prompt is open. Height-animated
                        // rather than a popup so the list just makes room
                        // for it in place.
                        Item {
                            width: parent.width
                            height: wifiRow.expanded ? pwCol.implicitHeight + 14 : 0
                            clip: true
                            visible: height > 0.5

                            Behavior on height {
                                NumberAnimation {
                                    duration: Appearance.anim.durations.normal
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Appearance.anim.curves.emphasized
                                }
                            }

                            Column {
                                id: pwCol
                                x: 12
                                width: parent.width - 24
                                spacing: 8

                                StyledRect {
                                    width: parent.width
                                    implicitHeight: 42
                                    radius: 12
                                    color: Colors.surfaceHigh
                                    border.width: 1
                                    border.color: pwField.activeFocus ? Colors.accentDim : Colors.border

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 8

                                        MaterialIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "lock"
                                            font.pixelSize: 16
                                            color: Colors.subtext
                                        }

                                        TextInput {
                                            id: pwField
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 24 - 8
                                            color: Colors.text
                                            font.family: Appearance.font.family
                                            font.pixelSize: 14
                                            clip: true
                                            echoMode: TextInput.Password

                                            onAccepted: wifiRow.submitPassword()
                                            Keys.onEscapePressed: root.wifiPasswordSsid = ""

                                            StyledText {
                                                visible: pwField.text === ""
                                                text: "Password"
                                                font.pixelSize: 14
                                                color: Colors.faint
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                    }
                                }

                                StyledText {
                                    visible: Network.connectError !== ""
                                    width: parent.width
                                    text: Network.connectError
                                    wrapMode: Text.Wrap
                                    font.pixelSize: 12
                                    color: Colors.danger
                                }

                                Row {
                                    anchors.right: parent.right
                                    spacing: 8

                                    StyledRect {
                                        implicitWidth: cancelLabel.implicitWidth + 24
                                        implicitHeight: 32
                                        radius: 16
                                        color: cancelHover.hovered ? Colors.surfaceHover : Colors.surfaceHigh

                                        StyledText {
                                            id: cancelLabel
                                            anchors.centerIn: parent
                                            text: "Cancel"
                                            font.pixelSize: 13
                                            font.weight: 600
                                        }
                                        HoverHandler {
                                            id: cancelHover
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                        TapHandler {
                                            onTapped: root.wifiPasswordSsid = ""
                                        }
                                    }

                                    StyledRect {
                                        implicitWidth: connectLabel.implicitWidth + 24
                                        implicitHeight: 32
                                        radius: 16
                                        opacity: pwField.text.length > 0 ? 1 : 0.4
                                        color: connectHover.hovered ? Colors.accentDim : Colors.accent

                                        StyledText {
                                            id: connectLabel
                                            anchors.centerIn: parent
                                            text: Network.connecting ? "Connecting…" : "Connect"
                                            font.pixelSize: 13
                                            font.weight: 600
                                            color: Colors.accentFg
                                        }
                                        HoverHandler {
                                            id: connectHover
                                            enabled: pwField.text.length > 0
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                        TapHandler {
                                            enabled: pwField.text.length > 0
                                            onTapped: wifiRow.submitPassword()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Page {
            id: audioPage
            shown: root.view === "audio"
            implicitHeight: audioContent.implicitHeight

            // Not a DetailView -- Output/Apps/Input read as three
            // distinct, independently-sized sections rather than one
            // scrolling list, and there's no scan/refresh concept here
            // (PwNode's own reactive properties keep everything live).
            Column {
                id: audioContent
                width: parent.width
                spacing: 10

                Item {
                    width: parent.width
                    height: 40

                    IconButton {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "arrow_back"
                        size: 34
                        iconSize: 18
                        onClicked: root.view = "main"
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: "Sound"
                        font.pixelSize: 16
                        font.weight: 700
                    }
                }

                StyledText {
                    text: "Output"
                    font.pixelSize: 13
                    font.weight: 600
                    color: Colors.subtext
                }

                Column {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        // ScriptModel for the same reason as the per-app
                        // stream sliders below.
                        model: ScriptModel {
                            values: Audio.sinks
                        }

                        StyledRect {
                            id: sinkRow

                            required property PwNode modelData
                            readonly property bool isDefault: Audio.sink?.id === modelData?.id

                            width: audioContent.width
                            implicitHeight: 50
                            radius: 14
                            color: sinkHover.hovered ? Colors.surfaceHover : Colors.surface

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                // Radio selector -- Output is single-select,
                                // not an on/off toggle like Wi-Fi/Bluetooth.
                                MaterialIcon {
                                    text: sinkRow.isDefault ? "radio_button_checked" : "radio_button_unchecked"
                                    font.pixelSize: 18
                                    color: sinkRow.isDefault ? Colors.accent : Colors.subtext
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: sinkRow.modelData.description || sinkRow.modelData.name
                                    elide: Text.ElideRight
                                    font.pixelSize: 14
                                    font.weight: sinkRow.isDefault ? 700 : 400
                                }
                            }

                            HoverHandler {
                                id: sinkHover
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: Audio.setSink(sinkRow.modelData)
                            }
                        }
                    }
                }

                // Per-app playback streams -- hidden entirely when
                // nothing's producing sound, same collapse-out pattern
                // Brightness.available uses on the main page's slider.
                StyledText {
                    visible: Audio.streams.length > 0
                    text: "Apps"
                    font.pixelSize: 13
                    font.weight: 600
                    color: Colors.subtext
                }

                Column {
                    width: parent.width
                    spacing: 6
                    visible: Audio.streams.length > 0

                    Repeater {
                        // ScriptModel, not the bare array: Audio.streams is
                        // a fresh filter() result every time PipeWire's node
                        // list changes, so Repeater reset ALL of these
                        // delegates whenever any app started or stopped
                        // playing -- rebuilding every per-app slider (losing
                        // an in-progress drag) and, mid-reset, leaving
                        // delegates with a null modelData just long enough
                        // for the bindings below to throw
                        // "Cannot read property 'audio' of null".
                        model: ScriptModel {
                            values: Audio.streams
                        }

                        CcSlider {
                            required property PwNode modelData

                            width: audioContent.width
                            implicitHeight: 50
                            // modelData itself is guarded, not just .audio --
                            // it is the one that goes null during a reset.
                            icon: modelData?.audio?.muted ? "volume_off" : "graphic_eq"
                            value: modelData?.audio?.volume ?? 0
                            onMoved: v => {
                                if (modelData?.audio) {
                                    modelData.audio.muted = false;
                                    modelData.audio.volume = v;
                                }
                            }
                        }
                    }
                }

                StyledText {
                    text: "Input"
                    font.pixelSize: 13
                    font.weight: 600
                    color: Colors.subtext
                }

                Column {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        // ScriptModel for the same reason as the per-app
                        // stream sliders above.
                        model: ScriptModel {
                            values: Audio.sources
                        }

                        StyledRect {
                            id: sourceRow

                            required property PwNode modelData
                            readonly property bool isDefault: Audio.source?.id === modelData?.id

                            width: audioContent.width
                            implicitHeight: 50
                            radius: 14
                            color: sourceHover.hovered ? Colors.surfaceHover : Colors.surface

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                MaterialIcon {
                                    text: sourceRow.isDefault ? "radio_button_checked" : "radio_button_unchecked"
                                    font.pixelSize: 18
                                    color: sourceRow.isDefault ? Colors.accent : Colors.subtext
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: sourceRow.modelData.description || sourceRow.modelData.name
                                    elide: Text.ElideRight
                                    font.pixelSize: 14
                                    font.weight: sourceRow.isDefault ? 700 : 400
                                }
                            }

                            HoverHandler {
                                id: sourceHover
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: Audio.setSource(sourceRow.modelData)
                            }
                        }
                    }

                    StyledText {
                        visible: Audio.sources.length === 0
                        text: "No input devices"
                        font.pixelSize: 13
                        color: Colors.faint
                    }
                }

                CcSlider {
                    width: parent.width
                    implicitHeight: 54
                    icon: Audio.inputMuted ? "mic_off" : "mic"
                    value: Audio.inputVolume
                    onMoved: v => Audio.setInputVolume(v)
                }
            }
        }

        Page {
            id: btPage
            shown: root.view === "bluetooth"
            implicitHeight: btDetail.implicitHeight

            DetailView {
                id: btDetail
                width: parent.width
                title: "Bluetooth Devices"
                busy: Bluetooth.scanning
                model: Bluetooth.devices
                onBack: root.view = "main"
                onRefresh: Bluetooth.startScan()

                delegate: StyledRect {
                    id: btRow

                    required property var modelData
                    readonly property bool isConnecting: Bluetooth.connectingMac === btRow.modelData.mac

                    // Same "just connected" settle-flash as the Wi-Fi rows.
                    property bool justConnected: false

                    Connections {
                        target: Bluetooth
                        function onConnectSucceeded(mac: string) {
                            if (mac === btRow.modelData.mac) {
                                btRow.justConnected = true;
                                btJustConnectedTimer.restart();
                            }
                        }
                    }

                    Timer {
                        id: btJustConnectedTimer
                        interval: 900
                        onTriggered: btRow.justConnected = false
                    }

                    width: ListView.view.width
                    implicitHeight: 58
                    radius: 14
                    color: btRow.justConnected ? Colors.accentDim
                         : btRowHover.hovered ? Colors.surfaceHover : Colors.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Item {
                            implicitWidth: 22
                            implicitHeight: 22

                            // Device-type glyph (headphones/phone/
                            // controller/...), derived from bluez's own
                            // Icon property -- see Bluetooth.deviceIcon().
                            // Hidden while connecting so the spinner
                            // below reads as its replacement.
                            MaterialIcon {
                                anchors.centerIn: parent
                                visible: !btRow.isConnecting
                                text: btRow.modelData.icon
                                font.pixelSize: 18
                                color: btRow.modelData.connected ? Colors.accent : Colors.subtext
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                visible: btRow.isConnecting
                                text: "sync"
                                font.pixelSize: 18
                                color: Colors.accent

                                SequentialAnimation on opacity {
                                    running: btRow.isConnecting
                                    loops: Animation.Infinite
                                    NumberAnimation {
                                        to: 0.3
                                        duration: 550
                                        easing.type: Easing.InOutQuad
                                    }
                                    NumberAnimation {
                                        to: 1
                                        duration: 550
                                        easing.type: Easing.InOutQuad
                                    }
                                }
                                RotationAnimation on rotation {
                                    running: btRow.isConnecting
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 1400
                                }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                width: parent.width
                                text: btRow.modelData.name
                                elide: Text.ElideRight
                                font.pixelSize: 14
                                font.weight: 600
                            }
                            StyledText {
                                width: parent.width
                                text: btRow.isConnecting ? "Connecting…"
                                    : btRow.modelData.connected ? "Connected"
                                    : btRow.modelData.paired ? "Paired" : "Available"
                                elide: Text.ElideRight
                                font.pixelSize: 11
                                color: (btRow.isConnecting || btRow.modelData.connected) ? Colors.accent : Colors.faint
                            }
                        }

                        // Forget -- only for paired devices, revealed on
                        // hover. No separate tap-zone dance needed here
                        // like the Wi-Fi rows: this row never had a
                        // row-wide TapHandler to begin with (only the
                        // ToggleSwitch and this button are interactive),
                        // so there's nothing for it to overlap.
                        IconButton {
                            visible: btRow.modelData.paired && btRowHover.hovered
                            size: 28
                            iconSize: 15
                            icon: "delete"
                            onClicked: Bluetooth.forget(btRow.modelData.mac)
                        }

                        ToggleSwitch {
                            checked: btRow.modelData.connected
                            onToggled: {
                                if (btRow.isConnecting)
                                    return;
                                btRow.modelData.connected
                                    ? Bluetooth.disconnectFrom(btRow.modelData.mac)
                                    : Bluetooth.connectTo(btRow.modelData.mac);
                            }
                        }
                    }

                    // Hover-only, same reasoning as the Wi-Fi rows above --
                    // a MouseArea would swallow the ToggleSwitch's clicks.
                    HoverHandler {
                        id: btRowHover
                    }
                }
            }
        }

        // ============================================================ //
        //  POMODORO SETTINGS  (right-click the Pomodoro tile)           //
        // ============================================================ //
        Page {
            id: pomoPage
            shown: root.view === "pomodoro"
            implicitHeight: pomoCol.implicitHeight

            // A short settings form, not a device list, so this is built
            // out rather than reusing DetailView (which is a back header
            // wrapped around a ListView).
            Column {
                id: pomoCol
                width: parent.width
                spacing: 10

                Item {
                    width: parent.width
                    height: 40

                    IconButton {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "arrow_back"
                        size: 34
                        iconSize: 18
                        onClicked: root.view = "main"
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: "Pomodoro"
                        font.pixelSize: 16
                        font.weight: 700
                    }
                }

                // One adjustable length. `which` is the key Timers uses.
                component LengthRow: StyledRect {
                    id: lengthRow

                    required property string which
                    required property string rowLabel
                    required property string rowIcon
                    required property int mins

                    width: pomoCol.width
                    implicitHeight: 60
                    radius: 18
                    color: Colors.surface

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: lengthRow.rowIcon
                            font.pixelSize: 20
                            color: Colors.accent
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: lengthRow.rowLabel
                            font.pixelSize: 14
                            font.weight: 600
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "remove"
                            size: 30
                            iconSize: 17
                            onClicked: Timers.pomoSetLength(lengthRow.which, -1)
                        }

                        MonoText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 62
                            horizontalAlignment: Text.AlignHCenter
                            text: Timers.fmtMins(lengthRow.mins)
                            font.pixelSize: 14
                            font.weight: 700
                        }

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "add"
                            size: 30
                            iconSize: 17
                            onClicked: Timers.pomoSetLength(lengthRow.which, 1)
                        }
                    }
                }

                LengthRow {
                    which: "focus"
                    rowLabel: "Focus"
                    rowIcon: "local_fire_department"
                    mins: Math.round(Timers.focusSecs / 60)
                }

                LengthRow {
                    which: "short"
                    rowLabel: "Short break"
                    rowIcon: "coffee"
                    mins: Math.round(Timers.shortSecs / 60)
                }

                LengthRow {
                    which: "long"
                    rowLabel: "Long break"
                    rowIcon: "bedtime"
                    mins: Math.round(Timers.longSecs / 60)
                }

                StyledText {
                    width: parent.width
                    text: `Long break every ${Timers.longEvery} focus blocks. Changes apply to the next phase, never to one already running.`
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11
                    color: Colors.subtext
                }
            }
        }
    }
}
