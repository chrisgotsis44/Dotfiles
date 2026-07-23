pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Wi-Fi status via nmcli: event-driven through `nmcli monitor`, with a
// slow poll as a safety net.
Singleton {
    id: root

    property bool wifiEnabled: true
    property bool connected: false
    property string ssid: ""
    property int strength: 0
    property bool ethernetConnected: false

    readonly property string icon: {
        if (!wifiEnabled)
            return "signal_wifi_off";
        if (!connected)
            return "signal_wifi_0_bar";
        if (strength >= 80)
            return "signal_wifi_4_bar";
        if (strength >= 60)
            return "network_wifi_3_bar";
        if (strength >= 40)
            return "network_wifi_2_bar";
        if (strength >= 20)
            return "network_wifi_1_bar";
        return "signal_wifi_0_bar";
    }

    function refresh(): void {
        statusProc.running = true;
        radioProc.running = true;
        ethernetProc.running = true;
    }

    function toggleWifi(): void {
        Quickshell.execDetached(["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"]);
        wifiEnabled = !wifiEnabled; // optimistic; monitor confirms shortly
    }

    // ---- available networks (Control Center detail view) ----

    // [{ ssid, signal, secure, inUse }] sorted: connected first, then by
    // signal strength.
    property var networks: []
    readonly property bool scanning: scanProc.running

    function scan(): void {
        scanProc.running = true;
    }

    // Known networks connect directly; new secured networks need a
    // password and should be joined once via nmtui/nmcli first.
    function connectTo(ssid: string): void {
        Quickshell.execDetached(["nmcli", "device", "wifi", "connect", ssid]);
    }

    Process {
        id: scanProc
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "device", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const nets = [];
                const seen = new Set();
                for (const line of text.trim().split("\n")) {
                    if (!line)
                        continue;
                    const p = line.split(":");
                    const ssid = p.slice(3).join(":"); // SSIDs may contain ':'
                    if (!ssid || seen.has(ssid))
                        continue;
                    seen.add(ssid);
                    nets.push({
                        ssid: ssid,
                        signal: parseInt(p[1]) || 0,
                        secure: p[2] !== "" && p[2] !== "--",
                        inUse: p[0] === "*"
                    });
                }
                nets.sort((a, b) => (b.inUse - a.inUse) || (b.signal - a.signal));
                root.networks = nets;
            }
        }
    }

    Process {
        id: radioProc
        running: true
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: root.wifiEnabled = text.trim() === "enabled"
        }
    }

    Process {
        id: statusProc
        running: true
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SIGNAL,SSID device wifi list | grep '^yes' || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim().split("\n")[0] ?? "";
                if (!line) {
                    root.connected = false;
                    root.ssid = "";
                    root.strength = 0;
                    return;
                }
                const parts = line.split(":");
                root.connected = true;
                root.strength = parseInt(parts[1]) || 0;
                root.ssid = parts.slice(2).join(":"); // SSIDs may contain ':'
            }
        }
    }

    // Any device of type "ethernet" in state "connected" (not the
    // "connected (externally)" that loopback/etc report).
    Process {
        id: ethernetProc
        running: true
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE device status | grep '^ethernet:connected$' || true"]
        stdout: StdioCollector {
            onStreamFinished: root.ethernetConnected = text.trim() !== ""
        }
    }

    Process {
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: debounce.restart()
        }
    }

    Timer {
        id: debounce
        interval: 400
        onTriggered: root.refresh()
    }

    Timer {
        interval: 15000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }
}
