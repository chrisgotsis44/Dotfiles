pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Backlight via brightnessctl. Writes are debounced so dragging the
// slider doesn't spawn a process per pixel.
Singleton {
    id: root

    property real value: 0.5

    // True only when an actual backlight device exists — the Control
    // Center hides its brightness slider entirely on systems (desktop
    // monitors without DDC, VMs, ...) where there is nothing to control.
    property bool available: false

    function setBrightness(v: real): void {
        value = Math.max(0.01, Math.min(1, v));
        writeTimer.restart();
    }

    Process {
        running: true
        command: ["sh", "-c", "ls -A /sys/class/backlight 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: root.available = text.trim() !== ""
        }
    }

    Process {
        running: true
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                // device,class,current,percent%,max
                const parts = text.trim().split(",");
                if (parts.length >= 5) {
                    const cur = parseInt(parts[2]) || 0;
                    const max = parseInt(parts[4]) || 1;
                    root.value = cur / max;
                }
            }
        }
    }

    Timer {
        id: writeTimer
        interval: 80
        onTriggered: Quickshell.execDetached(["brightnessctl", "-q", "s", Math.round(root.value * 100) + "%"])
    }
}
