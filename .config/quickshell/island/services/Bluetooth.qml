pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // The powered state is only ever shown by the Control Center's
    // Bluetooth tile and its detail view, so `bluetoothctl show` only
    // needs re-running while one of those is on screen -- it used to fork
    // every 10s forever. One probe at startup keeps the tile correct the
    // instant it first appears; after that the poll follows the menu.
    readonly property bool active: GlobalState.controlCenterOpen

    onActiveChanged: if (active) check.running = true

    property bool powered: false
    property bool scanning: false

    function toggle(): void {
        Quickshell.execDetached(["bluetoothctl", "power", powered ? "off" : "on"]);
        powered = !powered; // optimistic; poll confirms
    }

    // ---- known devices (Control Center detail view) ----

    // [{ mac, name, paired, connected, icon }]
    property var devices: []

    function refreshDevices(): void {
        devProc.running = true;
    }

    // A bounded, one-shot scan -- bluetoothctl's own --timeout stops it
    // automatically, then the device list is refreshed to pick up
    // anything newly discovered. This is the Bluetooth page's
    // "Pairing / Scan" trigger.
    function startScan(): void {
        if (scanning)
            return;
        scanning = true;
        scanProc.running = true;
    }

    // ---- connect / disconnect / forget ----
    //
    // Tracked (not execDetached) so the Control Center can show which
    // specific row is mid-connect and animate it, the same way Network's
    // Wi-Fi connect does.
    property string connectingMac: ""
    readonly property bool connecting: connectingMac !== ""
    // Emitted only once bluetoothctl's own output confirms the connect,
    // so a failed attempt doesn't trigger the "just connected" flash.
    signal connectSucceeded(string mac)

    function connectTo(mac: string): void {
        if (root.connecting)
            return;
        root.connectingMac = mac;
        connectProc.targetMac = mac;
        connectProc.command = ["bluetoothctl", "connect", mac];
        connectProc.running = true;
    }

    function disconnectFrom(mac: string): void {
        Quickshell.execDetached(["bluetoothctl", "disconnect", mac]);
    }

    // Unpairs entirely -- bluetoothctl disconnects first if it's the
    // active one.
    function forget(mac: string): void {
        forgetProc.command = ["bluetoothctl", "remove", mac];
        forgetProc.running = true;
    }

    Process {
        id: connectProc
        property string targetMac: ""
        stdout: StdioCollector {
            onStreamFinished: {
                root.connectingMac = "";
                if (text.includes("Connection successful"))
                    root.connectSucceeded(connectProc.targetMac);
                root.refreshDevices();
            }
        }
    }

    Process {
        id: forgetProc
        stdout: StdioCollector {
            onStreamFinished: root.refreshDevices()
        }
    }

    // bluez's Icon property (freedesktop icon-naming-spec name) mapped
    // to a Material Symbols glyph for the detail list.
    function deviceIcon(icon: string): string {
        if (icon.indexOf("headset") !== -1 || icon.indexOf("headphone") !== -1)
            return "headphones";
        if (icon.indexOf("phone") !== -1)
            return "smartphone";
        if (icon.indexOf("gaming") !== -1 || icon.indexOf("joystick") !== -1)
            return "sports_esports";
        if (icon.indexOf("keyboard") !== -1)
            return "keyboard";
        if (icon.indexOf("mouse") !== -1)
            return "mouse";
        if (icon.indexOf("printer") !== -1)
            return "print";
        if (icon.indexOf("watch") !== -1)
            return "watch";
        if (icon.indexOf("computer") !== -1)
            return "computer";
        return "bluetooth";
    }

    // One `bluetoothctl info` block per known device (paired or just
    // discovered), run as a single shell pipeline so the whole list is
    // still one process regardless of device count.
    Process {
        id: devProc
        command: ["sh", "-c", "for d in $(bluetoothctl devices | cut -d' ' -f2); do bluetoothctl info \"$d\"; echo ---END---; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const block of text.split("---END---")) {
                    const dm = block.match(/^Device (\S+)/m);
                    if (!dm)
                        continue;
                    const nm = block.match(/\n\tName: (.*)/);
                    const iconM = block.match(/\n\tIcon: (\S+)/);
                    out.push({
                        mac: dm[1],
                        name: (nm ? nm[1] : dm[1]).trim(),
                        paired: /\n\tPaired: yes/.test(block),
                        connected: /\n\tConnected: yes/.test(block),
                        icon: root.deviceIcon(iconM ? iconM[1] : "")
                    });
                }
                out.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name));
                root.devices = out;
            }
        }
    }

    Process {
        id: scanProc
        command: ["bluetoothctl", "--timeout", "8", "scan", "on"]
        onExited: {
            root.scanning = false;
            root.refreshDevices();
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
        running: root.active
        onTriggered: check.running = true
    }
}
