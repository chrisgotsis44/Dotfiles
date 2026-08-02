pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// power-profiles-daemon integration via powerprofilesctl. Only the
// Control Center's Power Mode tile reads this (laptops only, see
// Battery.available), so a cheap 5s poll is plenty -- no need for a
// persistent `powerprofilesctl monitor` subprocess.
//
// ...but only WHILE that tile is on screen. The poll used to run
// unconditionally, forking a `sh -c powerprofilesctl get` twelve times a
// minute for the entire uptime of the shell to refresh a string nothing
// was reading. One probe at startup (so `available` is known before the
// Control Center is ever opened) plus polling while it's open gives the
// tile identical behaviour at a fraction of the wakeups -- which is the
// whole point on the laptop this tile only exists for.
Singleton {
    id: root

    readonly property bool active: GlobalState.controlCenterOpen

    // Don't wait up to 5s for the first tick to correct a stale reading.
    onActiveChanged: if (active) check.running = true

    readonly property var profiles: ["performance", "balanced", "power-saver"]
    property string profile: "balanced"
    property bool available: false

    readonly property string icon: {
        switch (profile) {
        case "performance": return "bolt";
        case "power-saver": return "eco";
        default: return "balance";
        }
    }

    readonly property string label: {
        switch (profile) {
        case "performance": return "Performance";
        case "power-saver": return "Power Saver";
        default: return "Balanced";
        }
    }

    function cycle(): void {
        const i = root.profiles.indexOf(root.profile);
        setProfile(root.profiles[(i + 1) % root.profiles.length]);
    }

    function setProfile(name: string): void {
        profile = name; // optimistic; poll confirms
        Quickshell.execDetached(["powerprofilesctl", "set", name]);
    }

    Process {
        id: check
        running: true
        command: ["sh", "-c", "powerprofilesctl get 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                root.available = p !== "";
                if (p)
                    root.profile = p;
            }
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.active
        onTriggered: check.running = true
    }
}
