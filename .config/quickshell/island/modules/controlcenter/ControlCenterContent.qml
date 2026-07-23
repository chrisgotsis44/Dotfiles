pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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

    // Refresh device lists the moment their page is pushed.
    onViewChanged: {
        if (view === "wifi")
            Network.scan();
        else if (view === "bluetooth")
            Bluetooth.refreshDevices();
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
                    // independently of Wi-Fi's own on/off state.
                    CcToggle {
                        Layout.fillWidth: true
                        icon: "wifi"
                        label: "Wi-Fi"
                        sub: Network.connected ? Network.ssid
                           : Network.ethernetConnected ? "Ethernet connected"
                           : Network.wifiEnabled ? "Not connected" : "Off"
                        active: Network.wifiEnabled
                        hasDetail: true
                        badgeIcon: Network.ethernetConnected ? "settings_ethernet" : ""
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
                    // Runs ~/.local/bin/night-mode.sh (async, detached).
                    CcToggle {
                        Layout.fillWidth: true
                        icon: "nightlight"
                        label: "Night Light"
                        sub: GlobalState.nightLight ? "On" : "Off"
                        active: GlobalState.nightLight
                        onToggled: GlobalState.toggleNightLight()
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

                MediaCard {
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

                    width: ListView.view.width
                    implicitHeight: 54
                    radius: 14
                    color: wifiRowMouse.containsMouse ? Colors.surfaceHover : Colors.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        MaterialIcon {
                            text: wifiRow.modelData.signal >= 70 ? "signal_wifi_4_bar"
                                : wifiRow.modelData.signal >= 45 ? "network_wifi_3_bar"
                                : wifiRow.modelData.signal >= 20 ? "network_wifi_2_bar"
                                : "network_wifi_1_bar"
                            font.pixelSize: 18
                            color: wifiRow.modelData.inUse ? Colors.accent : Colors.subtext
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: wifiRow.modelData.ssid
                            elide: Text.ElideRight
                            font.pixelSize: 14
                            font.weight: wifiRow.modelData.inUse ? 700 : 400
                        }

                        MaterialIcon {
                            visible: wifiRow.modelData.secure
                            text: "lock"
                            font.pixelSize: 14
                            color: Colors.faint
                        }

                        MaterialIcon {
                            visible: wifiRow.modelData.inUse
                            text: "check"
                            font.pixelSize: 14
                            color: Colors.accent
                        }
                    }

                    MouseArea {
                        id: wifiRowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Network.connectTo(wifiRow.modelData.ssid)
                    }
                }
            }
        }

        Page {
            id: audioPage
            shown: root.view === "audio"
            implicitHeight: audioDetail.implicitHeight

            DetailView {
                id: audioDetail
                width: parent.width
                title: "Output Devices"
                model: Audio.sinks
                onBack: root.view = "main"

                delegate: StyledRect {
                    id: sinkRow

                    required property PwNode modelData

                    readonly property bool isDefault: Audio.sink?.id === modelData.id

                    width: ListView.view.width
                    implicitHeight: 54
                    radius: 14
                    color: sinkRowMouse.containsMouse ? Colors.surfaceHover : Colors.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        MaterialIcon {
                            text: "speaker"
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

                        MaterialIcon {
                            visible: sinkRow.isDefault
                            text: "check"
                            font.pixelSize: 14
                            color: Colors.accent
                        }
                    }

                    MouseArea {
                        id: sinkRowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Audio.setSink(sinkRow.modelData)
                    }
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
                model: Bluetooth.devices
                onBack: root.view = "main"
                onRefresh: Bluetooth.refreshDevices()

                delegate: StyledRect {
                    id: btRow

                    required property var modelData

                    width: ListView.view.width
                    implicitHeight: 54
                    radius: 14
                    color: btRowMouse.containsMouse ? Colors.surfaceHover : Colors.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        MaterialIcon {
                            text: "bluetooth"
                            font.pixelSize: 18
                            color: Colors.subtext
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
                                text: btRow.modelData.mac
                                elide: Text.ElideRight
                                font.pixelSize: 11
                                color: Colors.faint
                            }
                        }
                    }

                    MouseArea {
                        id: btRowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Bluetooth.connectTo(btRow.modelData.mac)
                    }
                }
            }
        }
    }
}
