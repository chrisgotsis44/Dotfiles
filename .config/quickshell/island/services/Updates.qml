pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Pending system updates, for the Control Center's update button.
//
// Counting is deliberately split in two, because the two halves fail
// differently:
//
//   repo — `checkupdates`, which syncs a TEMPORARY pacman database
//          rather than /var/lib/pacman/sync. That is the whole reason to
//          use it over `pacman -Sy`: no root, and it cannot leave the
//          real database half-synced, which is what turns a later -Syu
//          into a partial upgrade.
//   aur  — `yay -Qua`, which hits the AUR RPC over the network and so
//          fails whenever that is unreachable. A failure there must not
//          take the repo count with it, so aurOk is tracked separately
//          and the UI says "+ AUR unavailable" rather than lying with a
//          smaller number.
Singleton {
    id: root

    property int repoCount: 0
    property int aurCount: 0
    property bool aurOk: true
    property bool checking: false
    property double checkedAt: 0

    readonly property int total: repoCount + (aurOk ? aurCount : 0)
    readonly property bool hasUpdates: total > 0

    readonly property string summary: {
        if (checking && checkedAt === 0)
            return "Checking…";
        if (total === 0)
            return aurOk ? "Up to date" : "Up to date · AUR unavailable";
        const parts = [];
        if (repoCount > 0)
            parts.push(repoCount + " repo");
        if (aurOk && aurCount > 0)
            parts.push(aurCount + " AUR");
        let s = parts.join(" · ");
        if (!aurOk)
            s += " · AUR unavailable";
        return s;
    }

    function refresh(): void {
        if (checking)
            return;
        checking = true;
        proc.running = false;
        proc.running = true;
    }

    // What the button actually runs: repositories first, AUR second.
    //
    // The order is the whole point. `yay -Syu` does both at once, and it
    // resolves AUR packages BEFORE installing anything -- so one
    // unreachable RPC aborts the lot and the repository packages, which
    // need nothing beyond the mirrors, never install. Splitting the two
    // means the repo half always completes on its own terms and an AUR
    // outage costs you only the AUR half.
    //
    // Phase 1 failing STOPS the run rather than continuing to phase 2.
    // That is deliberate: a cancelled or failed repo upgrade followed by
    // AUR builds would compile packages against libraries that were
    // about to change, which is the partial-upgrade trap.
    //
    // Phase 2 failing does NOT fail the script. The AUR RPC being down
    // is routine and non-fatal once the repos are done, and a non-zero
    // exit here would make island-activity.sh report the whole update as
    // failed when the important half succeeded.
    //
    // Interactive on purpose: both phases ask for confirmation and phase
    // 1 asks for a sudo password, so it needs a terminal you can answer
    // in. Wrapped in island-activity.sh so the pill carries a live chip
    // for the duration; `--hold` keeps the terminal open at the end so
    // the summary stays readable.
    //
    // Plain concatenated strings, NOT a template literal: an octal
    // escape such as \033 is a syntax error inside a QML/JS template
    // literal, and it takes the entire qs.services module down with it.
    readonly property string updateScript:
        "echo '==> [1/2] Repository packages (pacman -Syu)'\n"
        + "echo\n"
        + "if ! sudo pacman -Syu; then\n"
        + "    echo\n"
        + "    echo '==> Repository upgrade did not complete. Stopping before the AUR,'\n"
        + "    echo '    so nothing gets built against libraries that are about to change.'\n"
        + "    exit 1\n"
        + "fi\n"
        + "echo\n"
        + "echo '==> [2/2] AUR packages (yay -Sua)'\n"
        + "echo\n"
        + "if ! yay -Sua; then\n"
        + "    echo\n"
        + "    echo '==> AUR step did not complete (usually just the AUR RPC being'\n"
        + "    echo '    unreachable). Repository packages were upgraded regardless.'\n"
        + "fi\n"
        + "echo\n"
        + "echo '==> Done.'\n"

    function runUpdate(): void {
        Quickshell.execDetached(["kitty", "--hold", "-e",
            Quickshell.env("HOME") + "/.local/bin/island-activity.sh",
            "package", "System update", "--", "bash", "-c", root.updateScript]);
        // The counts are stale the moment the upgrade finishes; re-check
        // a little after the terminal is likely done rather than leaving
        // a number on screen that is no longer true.
        recheckTimer.restart();
    }

    Timer {
        id: recheckTimer
        interval: 120000
        onTriggered: root.refresh()
    }

    // Periodic. Long, because checkupdates does real work and pending
    // updates are not urgent information.
    Timer {
        interval: 3600000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // One process for both halves so there is a single completion point.
    // `|| true` on each so a non-zero exit (checkupdates returns 2 when
    // there is nothing to do) never aborts the script mid-way.
    Process {
        id: proc
        command: ["bash", "-c", `
repo=$(checkupdates 2>/dev/null | wc -l) || repo=0
if aur=$(yay -Qua 2>/dev/null); then
    aurn=$(printf '%s' "$aur" | grep -c . || true)
    echo "aurok=1"
else
    aurn=0
    echo "aurok=0"
fi
echo "repo=$repo"
echo "aur=$aurn"
`]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.trim().split("\n")) {
                    const i = line.indexOf("=");
                    if (i < 0)
                        continue;
                    const k = line.slice(0, i);
                    const v = line.slice(i + 1).trim();
                    if (k === "repo") root.repoCount = parseInt(v) || 0;
                    else if (k === "aur") root.aurCount = parseInt(v) || 0;
                    else if (k === "aurok") root.aurOk = v === "1";
                }
                root.checking = false;
                root.checkedAt = Date.now();
            }
        }
    }
}
