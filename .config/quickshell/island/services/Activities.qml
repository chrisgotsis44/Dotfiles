pragma Singleton

import Quickshell
import QtQuick

// Live Activities: transient, ongoing things worth a glance -- a running
// timer, a download, a recording, a build.
//
// The island already morphs around notifications, OSD and media; this is
// the same idea generalised, and deliberately owns NO domain logic of its
// own. Anything can be an activity: Timers pushes one, and scripts push
// their own over IPC (see shell.qml, target "activity"). This service only
// stores them and decides which one is showing.
Singleton {
    id: root

    // Activity shape:
    //   id        unique key -- pushing the same id updates in place
    //   icon      Material Symbols name
    //   title     "Pomodoro", "Downloading", "Recording"
    //   subtitle  "Focus", "firefox-141.tar.zst", ""
    //   value     compact string for the pill chip: "12:45", "63%"
    //   progress  0..1, or -1 for indeterminate (sliding sliver)
    //   kind      "task" (default) | "mode"
    //   controls  "" | "timer" | "pomodoro" | "stopwatch" -- which control
    //             set the expanded view offers. Script-pushed activities
    //             get "", meaning dismiss only; the shell has no way to
    //             pause someone else's download.
    //
    // "mode" exists because Keep Awake and Peace are not tasks: they have
    // no progress and no end, they are states you have left switched on.
    // Drawing them with an indeterminate bar would claim work is happening.
    // They get no track at all -- just the icon and what they mean.
    property var list: []

    readonly property bool any: root.list.length > 0
    readonly property int count: root.list.length

    // Newest wins the pill. A timer you just started is what you are
    // looking for; a download from ten minutes ago is not.
    readonly property var primary: root.list.length > 0 ? root.list[root.list.length - 1] : null

    function indexOf(id: string): int {
        for (let i = 0; i < root.list.length; i++)
            if (root.list[i].id === id)
                return i;
        return -1;
    }

    // Push or replace by id. Callers hand over whole objects rather than
    // mutating -- `list` is a var, and mutating an element in place would
    // not fire listChanged, so nothing bound to it would ever update.
    function push(activity: var): void {
        if (!activity || !activity.id)
            return;

        const next = root.list.slice();
        const merged = {
            id: activity.id,
            icon: activity.icon ?? "bolt",
            title: activity.title ?? "",
            subtitle: activity.subtitle ?? "",
            value: activity.value ?? "",
            progress: activity.progress ?? -1,
            kind: activity.kind ?? "task",
            controls: activity.controls ?? ""
        };

        const i = root.indexOf(activity.id);
        if (i >= 0)
            next[i] = merged;
        else
            next.push(merged);

        root.list = next;
    }

    // Partial update: only the fields a running activity actually changes
    // tick to tick, so a caller doesn't have to restate its icon and title
    // every second.
    function update(id: string, fields: var): void {
        const i = root.indexOf(id);
        if (i < 0)
            return;

        const next = root.list.slice();
        next[i] = Object.assign({}, next[i], fields);
        root.list = next;
    }

    function remove(id: string): void {
        const i = root.indexOf(id);
        if (i < 0)
            return;

        const next = root.list.slice();
        next.splice(i, 1);
        root.list = next;
    }

    function clear(): void {
        root.list = [];
    }
}
