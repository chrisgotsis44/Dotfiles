pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Persists how many times each app has been launched from the launcher,
// keyed by DesktopEntry.id (stable across sessions/restarts) -- so the
// launcher can float frequently-used apps to the top, like rofi's
// frequency-based sorting.
Singleton {
    id: root

    property var counts: ({}) // desktopEntry.id -> launch count

    function countFor(id: string): int {
        return root.counts[id] || 0;
    }

    function recordLaunch(id: string): void {
        if (!id)
            return;
        const next = Object.assign({}, root.counts);
        next[id] = (next[id] || 0) + 1;
        root.counts = next;
        saveTimer.restart();
    }

    readonly property string path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/qs-island-app-usage.json"

    FileView {
        id: file
        path: root.path
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                if (parsed && typeof parsed === "object")
                    root.counts = parsed;
            } catch (e) {
                // First run / corrupt file -- start from empty counts.
            }
        }
        onLoadFailed: error => {}
    }

    // Debounced so rapid launches don't hammer disk.
    Timer {
        id: saveTimer
        interval: 500
        onTriggered: file.setText(JSON.stringify(root.counts))
    }
}
