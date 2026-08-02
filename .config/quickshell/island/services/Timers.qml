pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Stopwatch, countdown timer and pomodoro.
//
// All three are pure state here; the Control Center draws them and the
// island shows them via Activities. None of them knows about either UI,
// which is what lets the same clock appear as a tile, as a pill chip and
// as an expanded island card without any of them talking to each other.
Singleton {
    id: root

    // ---- the clock tile's mode ------------------------------------------
    // One Control Center tile carries both; right-clicking it switches.
    // Stopwatch is the default -- it needs no setup, so it is the one that
    // is useful the instant you click it.
    readonly property bool isStopwatch: prefs.clockMode !== "timer"

    function toggleClockMode(): void {
        prefs.clockMode = root.isStopwatch ? "timer" : "stopwatch";
        root.savePrefs();
    }

    // Never call writeAdapter() directly. Two writes in quick succession
    // race: the first write's own change event triggers a reload that can
    // land after the second in-memory edit and clobber it with what was on
    // disk a moment ago. Debouncing also means holding down a +/- button
    // costs one write instead of one per click.
    function savePrefs(): void {
        prefsWrite.restart();
    }

    Timer {
        id: prefsWrite
        interval: 400
        onTriggered: prefsView.writeAdapter()
    }

    // ---- stopwatch -------------------------------------------------------
    property int swElapsed: 0
    property bool swRunning: false

    readonly property bool swActive: root.swRunning || root.swElapsed > 0

    function swToggle(): void {
        root.swRunning = !root.swRunning;
        root.sync();
    }

    function swReset(): void {
        root.swRunning = false;
        root.swElapsed = 0;
        root.sync();
    }

    // ---- countdown timer -------------------------------------------------
    readonly property int timerStep: 60
    readonly property int timerMin: 60
    readonly property int timerMax: 180 * 60

    property int timerDuration: 5 * 60
    property int timerRemaining: 0
    property bool timerRunning: false

    // "Has a countdown in flight", running or paused -- as opposed to sat
    // at its start value waiting to be started.
    readonly property bool timerActive: root.timerRunning || (root.timerRemaining > 0 && root.timerRemaining < root.timerDuration)

    function timerToggle(): void {
        if (root.timerRunning) {
            root.timerRunning = false;
        } else {
            if (root.timerRemaining <= 0)
                root.timerRemaining = root.timerDuration;
            root.timerRunning = true;
        }
        root.sync();
    }

    function timerReset(): void {
        root.timerRunning = false;
        root.timerRemaining = 0;
        root.sync();
    }

    // Adjusting the dial only makes sense before it is counting; while a
    // countdown is in flight the buttons are the reset, not the setter.
    function timerAdjust(deltaSteps: int): void {
        if (root.timerActive)
            return;
        const next = root.timerDuration + deltaSteps * root.timerStep;
        root.timerDuration = Math.max(root.timerMin, Math.min(root.timerMax, next));
        root.sync();
    }

    // ---- pomodoro --------------------------------------------------------
    // Lengths are user-settable (Control Center, right-click the tile) and
    // persisted, so they survive the shell restarts this config invites.
    readonly property int focusSecs: prefs.focusMins * 60
    readonly property int shortSecs: prefs.shortMins * 60
    readonly property int longSecs: prefs.longMins * 60
    // A long break every fourth focus block.
    readonly property int longEvery: 4

    readonly property int phaseMin: 1
    readonly property int phaseMax: 120

    // "focus" | "short" | "long"
    property string pomoPhase: "focus"
    property int pomoRemaining: root.focusSecs
    property bool pomoRunning: false
    property int pomoCompleted: 0

    readonly property int pomoPhaseLength: root.pomoPhase === "focus" ? root.focusSecs : root.pomoPhase === "short" ? root.shortSecs : root.longSecs
    readonly property string pomoLabel: root.pomoPhase === "focus" ? "Focus" : root.pomoPhase === "short" ? "Short break" : "Long break"
    readonly property bool pomoActive: root.pomoRunning || root.pomoRemaining < root.pomoPhaseLength

    function pomoToggle(): void {
        root.pomoRunning = !root.pomoRunning;
        root.sync();
    }

    function pomoReset(): void {
        root.pomoRunning = false;
        root.pomoPhase = "focus";
        root.pomoRemaining = root.focusSecs;
        root.pomoCompleted = 0;
        root.sync();
    }

    function pomoSkip(): void {
        root.pomoAdvance(false);
    }

    // `natural` distinguishes "the phase ran out" from "you pressed skip":
    // only a completed focus block counts toward the long-break cycle.
    function pomoAdvance(natural: bool): void {
        if (root.pomoPhase === "focus") {
            if (natural)
                root.pomoCompleted++;
            const due = root.pomoCompleted > 0 && root.pomoCompleted % root.longEvery === 0;
            root.pomoPhase = due ? "long" : "short";
        } else {
            root.pomoPhase = "focus";
        }
        root.pomoRemaining = root.pomoPhaseLength;
        root.sync();
    }

    // which: "focus" | "short" | "long"
    function pomoSetLength(which: string, deltaMins: int): void {
        const key = which === "focus" ? "focusMins" : which === "short" ? "shortMins" : "longMins";
        const next = Math.max(root.phaseMin, Math.min(root.phaseMax, prefs[key] + deltaMins));
        prefs[key] = next;
        root.savePrefs();

        // An idle phase should adopt its new length immediately -- but a
        // running one must not be yanked, or shortening the focus block
        // mid-session would jump the countdown backwards.
        if (!root.pomoRunning && root.pomoRemaining >= root.pomoPhaseLength - 1)
            root.pomoRemaining = root.pomoPhaseLength;

        root.sync();
    }

    // ---- formatting ------------------------------------------------------
    // Grows an hours field only when there is one, so a stopwatch past the
    // hour doesn't read as "63:12" but a normal timer stays compact.
    function fmt(secs: int): string {
        const s = Math.max(0, Math.round(secs));
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const r = s % 60;
        const pad = n => (n < 10 ? "0" : "") + n;
        return h > 0 ? `${h}:${pad(m)}:${pad(r)}` : `${m}:${pad(r)}`;
    }

    function fmtMins(mins: int): string {
        return `${mins} min`;
    }

    function notify(title: string, body: string): void {
        Quickshell.execDetached(["notify-send", "-a", "Island", "-u", "critical", title, body]);
    }

    // ---- the tick --------------------------------------------------------
    // One timer drives all three. Separate ones would drift apart from each
    // other for no benefit, and this only runs while something needs it.
    Timer {
        running: root.timerRunning || root.pomoRunning || root.swRunning
        interval: 1000
        repeat: true

        onTriggered: {
            if (root.swRunning)
                root.swElapsed++;

            if (root.timerRunning) {
                root.timerRemaining--;
                if (root.timerRemaining <= 0) {
                    root.timerRunning = false;
                    root.timerRemaining = 0;
                    root.notify("Timer finished", `${root.fmt(root.timerDuration)} elapsed`);
                }
            }

            if (root.pomoRunning) {
                root.pomoRemaining--;
                if (root.pomoRemaining <= 0) {
                    const finished = root.pomoLabel;
                    root.pomoAdvance(true);
                    root.notify(`${finished} done`, `Next up: ${root.pomoLabel}`);
                }
            }

            root.sync();
        }
    }

    // ---- Activities bridge -----------------------------------------------
    // Push/remove rather than letting Activities poll: the island should
    // carry a chip exactly while there is something to count, and nothing
    // at all otherwise.
    function sync(): void {
        if (root.swActive) {
            Activities.push({
                id: "stopwatch",
                icon: "timelapse",
                title: "Stopwatch",
                subtitle: root.swRunning ? "" : "Paused",
                value: root.fmt(root.swElapsed),
                // Counting up has no end, so there is no fraction to draw.
                progress: -1,
                controls: "stopwatch"
            });
        } else {
            Activities.remove("stopwatch");
        }

        if (root.timerActive) {
            Activities.push({
                id: "timer",
                icon: "timer",
                title: "Timer",
                subtitle: root.timerRunning ? "" : "Paused",
                value: root.fmt(root.timerRemaining),
                progress: root.timerDuration > 0 ? 1 - root.timerRemaining / root.timerDuration : -1,
                controls: "timer"
            });
        } else {
            Activities.remove("timer");
        }

        if (root.pomoActive) {
            Activities.push({
                id: "pomodoro",
                icon: root.pomoPhase === "focus" ? "local_fire_department" : "coffee",
                title: "Pomodoro",
                subtitle: root.pomoRunning ? root.pomoLabel : `${root.pomoLabel} · paused`,
                value: root.fmt(root.pomoRemaining),
                progress: 1 - root.pomoRemaining / root.pomoPhaseLength,
                controls: "pomodoro"
            });
        } else {
            Activities.remove("pomodoro");
        }
    }

    // ---- persisted preferences -------------------------------------------
    FileView {
        id: prefsView
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/qs-island-timers.json"

        // An untouched phase should pick up a length restored from disk;
        // pomoRemaining's initialiser ran before this file was read.
        onLoaded: if (!root.pomoRunning && root.pomoCompleted === 0)
            root.pomoRemaining = root.pomoPhaseLength

        adapter: JsonAdapter {
            id: prefs
            property string clockMode: "stopwatch"
            property int focusMins: 25
            property int shortMins: 5
            property int longMins: 15
        }
    }
}
