pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Local weather via wttr.in (geolocated by IP). Refreshes every 30 min;
// retries sooner after a failure so a flaky connection at startup
// doesn't leave the widget blank for half an hour.
Singleton {
    id: root

    property string emoji: ""
    property string temp: "--°"
    property string condition: ""
    property string humidity: ""
    property string wind: ""
    readonly property bool ready: temp !== "--°"

    function refresh(): void {
        fetchProc.running = true;
    }

    Process {
        id: fetchProc
        command: ["curl", "-sf", "--max-time", "10", "wttr.in/?format=%c|%t|%C|%h|%w"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|");
                if (parts.length < 3 || !parts[1]) {
                    retryTimer.start();
                    return;
                }
                root.emoji = parts[0].trim();
                root.temp = parts[1].trim().replace("+", "");
                root.condition = parts[2].trim();
                root.humidity = (parts[3] ?? "").trim();
                root.wind = (parts[4] ?? "").trim();
            }
        }
    }

    Timer {
        id: retryTimer
        interval: 120000
        onTriggered: root.refresh()
    }

    Timer {
        interval: 1800000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
