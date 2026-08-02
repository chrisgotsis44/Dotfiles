pragma Singleton

import Quickshell
import Quickshell.Wayland
import QtQuick

// Open windows, and the state of the island's window switcher.
//
// Backed by wlr-foreign-toplevel-management, which Hyprland implements --
// so this sees every window the compositor knows about, without shelling
// out to hyprctl or parsing anything.
Singleton {
    id: root

    readonly property var all: ToplevelManager.toplevels?.values ?? []
    readonly property Toplevel active: ToplevelManager.activeToplevel

    // Most-recently-used order, and the whole reason alt-tab feels right.
    //
    // ToplevelManager hands windows back in CREATION order, which has
    // nothing to do with what you were last looking at -- so "open on the
    // second entry" landed on an arbitrary window, and whenever that
    // happened to be the one already focused, committing it changed
    // nothing at all. That is what "it doesn't change the window" was.
    property var mru: []

    // MRU first, then anything never focused (freshly opened windows), and
    // always filtered against the live list so closed windows drop out.
    readonly property var list: {
        const known = root.mru.filter(t => root.all.indexOf(t) !== -1);
        const rest = root.all.filter(t => known.indexOf(t) === -1);
        return known.concat(rest);
    }

    readonly property int count: root.list.length

    // Switcher UI state. The island reads `open` to enter its "switcher"
    // state; everything else here just moves the selection.
    property bool open: false
    property int index: 0

    readonly property Toplevel selected: root.index >= 0 && root.index < root.list.length ? root.list[root.index] : null

    // Deliberately NOT while the switcher is open: it takes exclusive
    // keyboard focus, so the compositor's idea of the active window
    // changes underneath us mid-gesture. Recording that would reorder the
    // list you are currently choosing from.
    onActiveChanged: if (!root.open)
        root.noteActive()

    function noteActive(): void {
        const a = root.active;
        if (!a || root.mru[0] === a)
            return;
        const next = root.mru.filter(t => t !== a && root.all.indexOf(t) !== -1);
        next.unshift(a);
        root.mru = next;
    }

    // Opening lands on the NEXT window rather than the current one, which
    // is what makes a bare press-and-release of the keybind an
    // alt-tab-style "flip to the last thing" rather than a no-op.
    function cycle(): void {
        if (root.count === 0)
            return;

        if (!root.open) {
            root.open = true;
            // Index 1 in MRU order is the window you were on before this
            // one -- the thing alt-tab is actually for.
            root.index = root.count > 1 ? 1 : 0;
            // The release already arrived and lost the race; honour it now
            // that there is something to commit.
            if (root.pendingSelect)
                root.select();
            return;
        }
        root.next();
    }

    function next(): void {
        if (root.count === 0)
            return;
        root.index = (root.index + 1) % root.count;
    }

    function prev(): void {
        if (root.count === 0)
            return;
        root.index = (root.index - 1 + root.count) % root.count;
    }

    function close(): void {
        root.open = false;
    }

    // A `select` that lands BEFORE the switcher has opened is remembered
    // rather than dropped.
    //
    // ALT+Tab and the ALT release are two separate keybinds, each spawning
    // its own ~40ms `qs ipc` process, with no ordering guarantee between
    // them -- so on a quick tap the release regularly arrived first, hit a
    // closed switcher, and did nothing, leaving the switcher up having
    // never committed. Arming instead of dropping makes the outcome the
    // same whichever process wins, which is the only way to make this
    // reliable without ordering guarantees the system does not provide.
    property bool pendingSelect: false

    // Short, because a stray ALT release with no switch behind it also
    // arms this. Long enough to cover the IPC skew, short enough that an
    // unrelated release cannot still be armed by the time you deliberately
    // open the switcher later.
    Timer {
        id: pendingWindow
        interval: 250
        onTriggered: root.pendingSelect = false
    }

    // Commit the highlighted window and dismiss. Called by Enter, by a
    // click, by the ALT release bind and by the island's own key handler.
    function select(): void {
        if (!root.open) {
            root.pendingSelect = true;
            pendingWindow.restart();
            return;
        }

        root.pendingSelect = false;
        pendingWindow.stop();
        const target = root.selected;
        root.open = false;

        // Deferred, NOT called inline. While the switcher is up the island
        // holds exclusive keyboard focus; activating a window in the same
        // breath as dropping `open` means the request reaches the
        // compositor while that layer surface is still demanding focus,
        // and the activation is simply ignored -- the switcher closed and
        // nothing moved. One beat later the surface has released focus and
        // the activation takes.
        activateDeferred.target = target;
        activateDeferred.restart();
    }

    Timer {
        id: activateDeferred

        property Toplevel target: null

        interval: 60
        onTriggered: {
            if (activateDeferred.target)
                activateDeferred.target.activate();
            activateDeferred.target = null;
        }
    }

    function activateAt(i: int): void {
        if (i < 0 || i >= root.count)
            return;
        root.index = i;
        root.select();
    }

    // A window closing while the switcher is up would otherwise leave the
    // selection past the end of the list, or pointing at a different
    // window than the one under the highlight.
    onAllChanged: {
        if (root.count === 0) {
            root.open = false;
            root.index = 0;
        } else if (root.index >= root.count) {
            root.index = root.count - 1;
        }
    }
}
