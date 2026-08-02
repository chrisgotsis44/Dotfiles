pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Wi-Fi status via nmcli: event-driven through `nmcli monitor`, with a
// slow poll as a safety net.
Singleton {
    id: root

    // `nmcli monitor` below is the real update mechanism and costs one
    // long-lived process, so the periodic refresh is purely a safety net
    // for the case where that monitor dies or misses an event. refresh()
    // forks FOUR nmcli processes, so running it every 15s regardless of
    // whether anything was displaying the result meant 16 process spawns
    // a minute, forever, to keep an off-screen SSID string warm. It stays
    // at 15s while the Control Center (the only consumer) is open, and
    // backs off to two minutes when nothing is looking.
    readonly property bool active: GlobalState.controlCenterOpen

    // The backed-off poll can leave the reading up to 2 min stale if the
    // monitor did miss something, so re-sync on open rather than showing
    // it stale for up to 15s.
    onActiveChanged: if (active) root.refresh()

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

    // "full" | "limited" | "portal" | "none" | "unknown" -- NetworkManager's
    // own connectivity assessment, not just "is a wifi connection up".
    property string connectivity: "unknown"
    readonly property bool portalDetected: connectivity === "portal"

    // Opens a plain-HTTP page a captive portal is guaranteed to intercept
    // and redirect -- neverssl.com exists specifically for this, so it
    // works regardless of which portal vendor is doing the intercepting.
    function openPortal(): void {
        Quickshell.execDetached(["xdg-open", "http://neverssl.com"]);
    }

    function refresh(): void {
        statusProc.running = true;
        radioProc.running = true;
        ethernetProc.running = true;
        connectivityProc.running = true;
    }

    function toggleWifi(): void {
        Quickshell.execDetached(["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"]);
        wifiEnabled = !wifiEnabled; // optimistic; monitor confirms shortly
    }

    // ---- available networks (Control Center detail view) ----

    // [{ ssid, signal, secure, inUse }] sorted: connected first, then by
    // signal strength.
    property var networks: []

    // Connection profile names nmcli already knows about -- a secured
    // network only needs a password prompt if it's NOT in here yet.
    property var savedConnections: []

    // `nmcli device wifi list` only ever reads NetworkManager's existing
    // scan cache -- a network that just appeared (a hotspot switched on
    // seconds ago) can be genuinely invisible until something asks for a
    // fresh scan. So: list what's cached right away for instant feedback,
    // fire off a real rescan alongside it, then list again once that's
    // had time to land. `rescanning` covers the whole window so the UI's
    // busy/spinner state doesn't drop out in between the two listings.
    property bool rescanning: false
    readonly property bool scanning: scanProc.running || rescanning

    function scan(): void {
        scanProc.running = true;
        savedProc.running = true;
        rescanning = true;
        rescanProc.running = true;
    }

    Process {
        id: rescanProc
        command: ["nmcli", "device", "wifi", "rescan"]
        stdout: StdioCollector {}
        // Fails harmlessly (e.g. "scanning not allowed immediately
        // following previous scan") if one's already in flight -- either
        // way, settle and re-list from whatever's cached by then.
        stderr: StdioCollector {}
        onExited: rescanSettle.restart()
    }

    Timer {
        id: rescanSettle
        interval: 2000
        onTriggered: {
            scanProc.running = true;
            savedProc.running = true;
            root.rescanning = false;
        }
    }

    // Drops the connection profile by name -- ssid doubles as the
    // connection id for every network nmcli itself created via connectTo
    // or connectWithPassword.
    function disconnect(ssid: string): void {
        Quickshell.execDetached(["nmcli", "connection", "down", "id", ssid]);
    }

    // Removes the saved profile entirely -- nmcli disconnects first if
    // it's the active one. Not execDetached: the Control Center wants to
    // know the exact moment it's actually gone so it can re-scan.
    function forget(ssid: string): void {
        forgetProc.command = ["nmcli", "connection", "delete", "id", ssid];
        forgetProc.running = true;
    }

    Process {
        id: forgetProc
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: root.scan()
        }
    }

    // ---- connecting (both plain and password-authenticated) ----
    //
    // Neither path is execDetached like disconnect/forget above -- a
    // wrong password (or any other failure) needs to be reported back to
    // whoever's waiting on it, and the Control Center wants a precise
    // "this row is connecting right now" signal to animate, not just an
    // eventual, silent change in `networks`.
    property string connectingSsid: ""
    readonly property bool connecting: connectingSsid !== ""
    property string connectError: ""
    // Emitted once nmcli actually confirms the connection, so the
    // Control Center's inline password field / row animation can react
    // to the exact moment instead of guessing from `networks` refreshing.
    signal connectSucceeded(string ssid)

    // Already-known networks (open, or secured with a saved profile)
    // connect directly with no prompt.
    function connectTo(ssid: string): void {
        beginConnect(ssid, ["nmcli", "device", "wifi", "connect", ssid]);
    }

    function connectWithPassword(ssid: string, password: string): void {
        beginConnect(ssid, ["nmcli", "device", "wifi", "connect", ssid, "password", password]);
    }

    function beginConnect(ssid: string, command: var): void {
        if (root.connecting)
            return;
        root.connectingSsid = ssid;
        root.connectError = "";
        connectProc.targetSsid = ssid;
        connectProc.command = command;
        connectProc.running = true;
    }

    Process {
        id: connectProc
        property string targetSsid: ""
        stdout: StdioCollector {}
        // nmcli prints nothing to stderr on success and an "Error: ..."
        // line (wrong password, timeout, ...) on failure -- non-empty
        // stderr is as reliable a success/failure signal as its exit code.
        stderr: StdioCollector {
            onStreamFinished: {
                root.connectingSsid = "";
                if (text.trim() !== "") {
                    root.connectError = "Couldn't connect to \"" + connectProc.targetSsid + "\" -- check the password.";
                } else {
                    root.connectError = "";
                    root.connectSucceeded(connectProc.targetSsid);
                    root.scan();
                }
            }
        }
    }

    Process {
        id: savedProc
        command: ["nmcli", "-t", "-f", "NAME", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: root.savedConnections = text.trim().split("\n").filter(s => s !== "")
        }
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

    Process {
        id: connectivityProc
        running: true
        command: ["nmcli", "-t", "-f", "CONNECTIVITY", "general", "status"]
        stdout: StdioCollector {
            onStreamFinished: root.connectivity = text.trim() || "unknown"
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
        interval: root.active ? 15000 : 120000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }
}
