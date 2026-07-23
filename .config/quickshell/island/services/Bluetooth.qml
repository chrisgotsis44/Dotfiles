pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool powered: false

    function toggle(): void {
        Quickshell.execDetached(["bluetoothctl", "power", powered ? "off" : "on"]);
        powered = !powered; // optimistic; poll confirms
    }

    // ---- known devices (Control Center detail view) ----

    // [{ mac, name }]
    property var devices: []

    function refreshDevices(): void {
        devProc.running = true;
    }

    function connectTo(mac: string): void {
        Quickshell.execDetached(["bluetoothctl", "connect", mac]);
    }

    Process {
        id: devProc
        command: ["bluetoothctl", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.trim().split("\n")) {
                    const m = line.match(/^Device (\S+) (.*)$/);
                    if (m)
                        out.push({ mac: m[1], name: m[2] });
                }
                root.devices = out;
            }
        }
    }

    Process {
        id: check
        running: true
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector {
            onStreamFinished: root.powered = text.includes("Powered: yes")
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: check.running = true
    }
}
