pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Just enough network state to draw one status glyph.
//
// The island's Network.qml keeps a long-lived `nmcli monitor`, a scan
// list, saved connections and connect/disconnect machinery -- all of which
// exists to drive the Control Center. The lockscreen shows a single icon
// and lives for the length of one unlock, so it polls instead. Nothing
// here writes network state; it is strictly a reader.
Singleton {
    id: root

    property bool wifiEnabled: true
    property bool wifiConnected: false
    property bool ethernetConnected: false
    property int strength: 0

    // The first nmcli reading takes over a second to land (the wifi list
    // call is the slow one). Until it does, every field is still at its
    // default and the icon would confidently show "no signal" on a fine
    // connection -- so the chip stays hidden rather than lying.
    property bool ready: false

    readonly property string icon: {
        if (root.ethernetConnected)
            return "lan";
        if (!root.wifiEnabled)
            return "signal_wifi_off";
        if (!root.wifiConnected)
            return "signal_wifi_bad";
        if (root.strength >= 80)
            return "signal_wifi_4_bar";
        if (root.strength >= 60)
            return "network_wifi_3_bar";
        if (root.strength >= 40)
            return "network_wifi_2_bar";
        if (root.strength >= 20)
            return "network_wifi_1_bar";
        return "signal_wifi_0_bar";
    }

    Process {
        id: proc

        // Three readings in one spawn, one per line, so a single parse
        // covers radio state, link state and signal strength.
        //
        // The bare `echo` is load-bearing: `tr` emits no trailing newline,
        // so without it the signal value lands on the END of the device
        // line and the third line never exists -- strength silently reads
        // 0 and the icon sits at no-signal on a perfectly good link.
        command: ["bash", "-c", `nmcli -t radio wifi 2>/dev/null
nmcli -t -f TYPE,STATE device status 2>/dev/null | tr '\\n' ';'; echo
nmcli -t -f IN-USE,SIGNAL device wifi list --rescan no 2>/dev/null | awk -F: '$1=="*"{print $2; exit}'`]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.wifiEnabled = (lines[0] ?? "").trim() === "enabled";

                const devices = lines[1] ?? "";
                root.wifiConnected = devices.includes("wifi:connected");
                root.ethernetConnected = devices.includes("ethernet:connected");

                const signal = parseInt((lines[2] ?? "").trim(), 10);
                root.strength = isNaN(signal) ? 0 : signal;

                root.ready = true;
            }
        }
    }

    Timer {
        running: true
        interval: 10000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!proc.running)
            proc.running = true
    }
}
