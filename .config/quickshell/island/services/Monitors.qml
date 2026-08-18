pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Monitor configuration, read from `hyprctl monitors -j` and applied
// with `hyprctl eval`.
//
// NOT `hyprctl keyword monitor ...`, which is the obvious thing and does
// not work here: this Hyprland config is Lua, and keyword refuses with
// "keyword can't work with non-legacy parsers. Use eval." The Lua
// equivalent is `hl.monitor{...}`, exactly as HyprConfig uses
// `hl.config{...}` for decoration settings.
//
// Changes are LIVE ONLY. Nothing is written back to
// ~/.config/hypr/modules/monitors.lua -- that file is hand-written Lua
// with a workspace-rule loop in it, and rewriting Lua source from a
// slider is the kind of thing that eats a config. The panel says so, and
// a Hyprland reload restores whatever monitors.lua declares.
Singleton {
    id: root

    property var list: []
    readonly property bool ready: list.length > 0

    function refresh(): void {
        proc.running = false;
        proc.running = true;
    }

    // "1920x1080@60.01Hz" -> { w, h, rate, label }
    function parseMode(mode: string): var {
        const m = /^(\d+)x(\d+)@([\d.]+)/.exec(mode);
        if (!m)
            return null;
        return {
            w: parseInt(m[1]),
            h: parseInt(m[2]),
            rate: parseFloat(m[3]),
            label: m[1] + "×" + m[2] + " @ " + Math.round(parseFloat(m[3])) + "Hz"
        };
    }

    // Distinct resolutions across a monitor's available modes, each
    // carrying every refresh rate it supports.
    function resolutionsFor(mon: var): var {
        const seen = {};
        for (const raw of (mon.availableModes || [])) {
            const p = parseMode(raw);
            if (!p)
                continue;
            const key = p.w + "x" + p.h;
            if (!seen[key])
                seen[key] = { w: p.w, h: p.h, key: key, label: p.w + "×" + p.h, rates: [] };
            if (!seen[key].rates.includes(p.rate))
                seen[key].rates.push(p.rate);
        }
        const out = Object.values(seen);
        for (const r of out)
            r.rates.sort((a, b) => b - a);
        // Largest first -- the native mode is nearly always the one
        // being looked for.
        out.sort((a, b) => (b.w * b.h) - (a.w * a.h));
        return out;
    }

    function apply(mon: var, opts: var): void {
        const o = opts || {};
        const w = o.width !== undefined ? o.width : mon.width;
        const h = o.height !== undefined ? o.height : mon.height;
        const rate = o.rate !== undefined ? o.rate : mon.refreshRate;
        const x = o.x !== undefined ? o.x : mon.x;
        const y = o.y !== undefined ? o.y : mon.y;
        const scale = o.scale !== undefined ? o.scale : mon.scale;
        const transform = o.transform !== undefined ? o.transform : mon.transform;
        const vrr = o.vrr !== undefined ? o.vrr : mon.vrr;

        // Rate needs the same precision Hyprland reports, or it snaps to
        // a neighbouring mode.
        const mode = `${w}x${h}@${rate.toFixed(2)}`;
        const lua = `{output="${mon.name}", mode="${mode}", position="${x}x${y}", `
            + `scale=${Number(scale).toFixed(6)}, transform=${transform}, vrr=${vrr ? 1 : 0}}`;

        Quickshell.execDetached(["hyprctl", "eval", "hl.monitor(" + lua + ")"]);
        settleTimer.restart();
    }

    function setDisabled(mon: var, off: bool): void {
        // Disabling is its own form -- `mode="disable"` rather than a
        // resolution. Guarded in the UI so the last active monitor
        // cannot be switched off, which would leave no way back.
        const lua = off
            ? `{output="${mon.name}", mode="disable"}`
            : `{output="${mon.name}", mode="preferred", position="auto", scale=1.0}`;
        Quickshell.execDetached(["hyprctl", "eval", "hl.monitor(" + lua + ")"]);
        settleTimer.restart();
    }

    readonly property int activeCount: list.filter(m => !m.disabled).length

    // Hyprland applies asynchronously; re-read once it has settled so the
    // UI shows what actually happened rather than what was asked for.
    Timer {
        id: settleTimer
        interval: 600
        onTriggered: root.refresh()
    }

    Process {
        id: proc
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.list = JSON.parse(text);
                } catch (e) {
                    root.list = [];
                }
            }
        }
    }

    Component.onCompleted: root.refresh()
}
