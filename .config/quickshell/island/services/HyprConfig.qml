pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Hyprland look-and-feel control for the Dashboard's Customize tab.
//
// Animation presets mirror ~/.local/bin/animation-switcher.sh exactly
// (minus rofi): each preset is a .lua file under
// ~/.config/hypr/modules/animations/, applied by symlinking it to
// animations.lua, recording it in the same state file the script uses,
// then `hyprctl reload`.
//
// There's no decoration-preset switcher anymore -- that folder used to
// hold whole swappable decoration.lua files, but it's now a fixed,
// hand-edited config split across blur.lua/shadow.lua/decoration.lua.
//
// Effects (blur/shadows/borders), gaps, opacity and rounding are BOTH
// applied live via `hyprctl eval` (instant feedback) AND written back
// into those same .lua files (debounced ~500ms after the last change,
// like AppUsage.qml's cache writes), via a plain in-place `sed`
// substitution on the one line matching that field's name -- these
// files are small and consistently formatted (`key = value,` per line),
// so a per-field regex is enough; there's no need for a real Lua parser.
// This is what makes a value survive a reload, a shell crash, or just
// closing the bar: without the file write, hyprctl eval only ever
// changes the *running* compositor state, and the next `hyprctl reload`
// (or Hyprland restart) would silently revert to whatever was last on
// disk. Reading back (optionsProc, below) still goes through hyprctl
// getoption rather than parsing the files -- that reflects the live
// compositor state, which already matches what's on disk once the
// debounced write lands.
Singleton {
    id: root

    readonly property string modulesDir: Quickshell.env("HOME") + "/.config/hypr/modules"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state")
    readonly property string decorationDir: modulesDir + "/decoration"

    property var animations: [] // preset names, sorted
    property string currentAnimation: ""

    property bool blurEnabled: true
    property int blurSize: 8
    property int blurPasses: 3
    property real blurVibrancy: 0.5
    property real blurVibrancyDarkness: 0.2

    property bool shadowsEnabled: true
    property int shadowRange: 14
    property int shadowRenderPower: 3
    property bool shadowSharp: false

    property bool bordersEnabled: true
    // Border width to restore when toggling borders back on (border
    // "off" is just border_size 0).
    property int savedBorderSize: 2

    property int gapsIn: 9
    property int gapsOut: 18
    property real activeOpacity: 1.0
    property real inactiveOpacity: 0.8

    property int rounding: 12
    property real roundingPower: 2

    function refresh(): void {
        listProc.running = true;
        optionsProc.running = true;
    }

    function setAnimation(name: string): void {
        currentAnimation = name; // optimistic
        const src = `${modulesDir}/animations/${name}.lua`;
        const tgt = `${modulesDir}/animations.lua`;
        const state = `${stateDir}/hypr_animations/last_animation`;
        Quickshell.execDetached(["sh", "-c",
            `mkdir -p "$(dirname '${state}')" && ln -sf '${src}' '${tgt}' && echo '${name}' > '${state}' && hyprctl reload`]);
        // A reload resets the runtime keyword tweaks below -- re-read
        // them once Hyprland has settled.
        reReadTimer.restart();
    }

    // This config uses Hyprland's Lua parser (hl.config({...}), per the
    // hand-edited files under modules/decoration/) -- NOT the legacy
    // keyfile parser. `hyprctl keyword` only works with the legacy
    // parser ("keyword can't work with non-legacy parsers. Use eval.");
    // the equivalent for a Lua config is `hyprctl eval` with a Lua table
    // literal. Since execDetached passes argv directly (no shell in
    // between), the literal needs no quoting/escaping at all.
    function evalConfig(luaTable: string): void {
        Quickshell.execDetached(["hyprctl", "eval", "hl.config(" + luaTable + ")"]);
    }

    // Debounced disk persistence -- see the file-level comment above.
    // Keyed by "file:key" so rapid slider drags collapse into a single
    // write per field once dragging stops, instead of one `sed` process
    // per intermediate value.
    property var pendingWrites: ({})

    function schedulePersist(fileName: string, key: string, value: string): void {
        const next = Object.assign({}, pendingWrites);
        next[fileName + ":" + key] = { fileName, key, value };
        pendingWrites = next;
        persistTimer.restart();
    }

    Timer {
        id: persistTimer
        interval: 500
        onTriggered: {
            for (const k in root.pendingWrites) {
                const w = root.pendingWrites[k];
                const path = `${root.decorationDir}/${w.fileName}`;
                // Matches "  key = <anything up to the next comma>,"
                // and replaces just the value, keeping indentation and
                // the trailing comma untouched.
                Quickshell.execDetached(["sed", "-i", "-E",
                    `s/^([[:space:]]*${w.key}[[:space:]]*=[[:space:]]*)[^,]+,/\\1${w.value},/`,
                    path]);
            }
            root.pendingWrites = {};
        }
    }

    function toggleBlur(): void {
        blurEnabled = !blurEnabled;
        evalConfig(`{decoration={blur={enabled=${blurEnabled}}}}`);
        schedulePersist("blur.lua", "enabled", String(blurEnabled));
    }

    function setBlurSize(v: int): void {
        blurSize = v;
        evalConfig(`{decoration={blur={size=${v}}}}`);
        schedulePersist("blur.lua", "size", String(v));
    }

    function setBlurPasses(v: int): void {
        blurPasses = v;
        evalConfig(`{decoration={blur={passes=${v}}}}`);
        schedulePersist("blur.lua", "passes", String(v));
    }

    function setBlurVibrancy(v: real): void {
        blurVibrancy = v;
        evalConfig(`{decoration={blur={vibrancy=${v.toFixed(2)}}}}`);
        schedulePersist("blur.lua", "vibrancy", v.toFixed(2));
    }

    function setBlurVibrancyDarkness(v: real): void {
        blurVibrancyDarkness = v;
        evalConfig(`{decoration={blur={vibrancy_darkness=${v.toFixed(2)}}}}`);
        schedulePersist("blur.lua", "vibrancy_darkness", v.toFixed(2));
    }

    function toggleShadows(): void {
        shadowsEnabled = !shadowsEnabled;
        evalConfig(`{decoration={shadow={enabled=${shadowsEnabled}}}}`);
        schedulePersist("shadow.lua", "enabled", String(shadowsEnabled));
    }

    function setShadowRange(v: int): void {
        shadowRange = v;
        evalConfig(`{decoration={shadow={range=${v}}}}`);
        schedulePersist("shadow.lua", "range", String(v));
    }

    function setShadowRenderPower(v: int): void {
        shadowRenderPower = v;
        evalConfig(`{decoration={shadow={render_power=${v}}}}`);
        schedulePersist("shadow.lua", "render_power", String(v));
    }

    function toggleShadowSharp(): void {
        shadowSharp = !shadowSharp;
        evalConfig(`{decoration={shadow={sharp=${shadowSharp}}}}`);
        schedulePersist("shadow.lua", "sharp", String(shadowSharp));
    }

    function toggleBorders(): void {
        bordersEnabled = !bordersEnabled;
        const size = bordersEnabled ? savedBorderSize : 0;
        evalConfig(`{general={border_size=${size}}}`);
        schedulePersist("decoration.lua", "border_size", String(size));
    }

    function setBorderSize(v: int): void {
        savedBorderSize = v;
        if (bordersEnabled) {
            evalConfig(`{general={border_size=${v}}}`);
            schedulePersist("decoration.lua", "border_size", String(v));
        }
    }

    function setGapsIn(v: int): void {
        gapsIn = v;
        evalConfig(`{general={gaps_in=${v}}}`);
        schedulePersist("decoration.lua", "gaps_in", String(v));
    }

    function setGapsOut(v: int): void {
        gapsOut = v;
        evalConfig(`{general={gaps_out=${v}}}`);
        schedulePersist("decoration.lua", "gaps_out", String(v));
    }

    function setActiveOpacity(v: real): void {
        activeOpacity = v;
        evalConfig(`{decoration={active_opacity=${v.toFixed(2)}}}`);
        schedulePersist("decoration.lua", "active_opacity", v.toFixed(2));
    }

    function setInactiveOpacity(v: real): void {
        inactiveOpacity = v;
        evalConfig(`{decoration={inactive_opacity=${v.toFixed(2)}}}`);
        schedulePersist("decoration.lua", "inactive_opacity", v.toFixed(2));
    }

    function setRounding(v: int): void {
        rounding = v;
        evalConfig(`{decoration={rounding=${v}}}`);
        schedulePersist("decoration.lua", "rounding", String(v));
    }

    function setRoundingPower(v: real): void {
        roundingPower = v;
        evalConfig(`{decoration={rounding_power=${v.toFixed(2)}}}`);
        schedulePersist("decoration.lua", "rounding_power", v.toFixed(2));
    }

    Timer {
        id: reReadTimer
        interval: 700
        onTriggered: optionsProc.running = true
    }

    Process {
        id: listProc
        running: true
        command: ["sh", "-c", `
            for f in "${Quickshell.env("HOME")}/.config/hypr/modules/animations"/*.lua; do
                [ -f "$f" ] && echo "ANIM $(basename "$f" .lua)"
            done | sort
            echo "CURA $(basename "$(readlink -f "${Quickshell.env("HOME")}/.config/hypr/modules/animations.lua" 2>/dev/null)" .lua)"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const anims = [];
                for (const line of text.trim().split("\n")) {
                    const sp = line.indexOf(" ");
                    if (sp < 0)
                        continue;
                    const tag = line.substring(0, sp);
                    const val = line.substring(sp + 1).trim();
                    if (tag === "ANIM")
                        anims.push(val);
                    else if (tag === "CURA" && val)
                        root.currentAnimation = val;
                }
                root.animations = anims;
            }
        }
    }

    // One "OPT <key> <value>" line per option -- value is whatever
    // hyprctl's json prints after "bool"/"int"/"float"/"css", so bools
    // come out as "true"/"false", numbers as plain text, and gaps (which
    // report as a 4-value CSS-margin-style string, e.g. "9 9 9 9", even
    // when configured with one uniform number) as just their first value.
    Process {
        id: optionsProc
        running: true
        command: ["sh", "-c", `
            for key in decoration:blur:enabled decoration:blur:size decoration:blur:passes \\
                       decoration:blur:vibrancy decoration:blur:vibrancy_darkness \\
                       decoration:shadow:enabled decoration:shadow:range decoration:shadow:render_power \\
                       decoration:shadow:sharp general:border_size \\
                       general:gaps_in general:gaps_out \\
                       decoration:active_opacity decoration:inactive_opacity \\
                       decoration:rounding decoration:rounding_power; do
                val=$(hyprctl getoption -j "$key" 2>/dev/null | grep -oE '"(bool|int|float|css)": [^,}]*' | head -1 | awk -F': ' '{print $2}' | tr -d '"' | awk '{print $1}')
                echo "OPT $key $val"
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.trim().split("\n")) {
                    const p = line.trim().split(/\s+/);
                    if (p[0] !== "OPT" || p.length < 3)
                        continue;
                    const key = p[1];
                    const val = p[2];
                    if (key === "decoration:blur:enabled")
                        root.blurEnabled = val === "true";
                    else if (key === "decoration:blur:size")
                        root.blurSize = parseInt(val) || 0;
                    else if (key === "decoration:blur:passes")
                        root.blurPasses = parseInt(val) || 0;
                    else if (key === "decoration:blur:vibrancy")
                        root.blurVibrancy = parseFloat(val) || 0;
                    else if (key === "decoration:blur:vibrancy_darkness")
                        root.blurVibrancyDarkness = parseFloat(val) || 0;
                    else if (key === "decoration:shadow:enabled")
                        root.shadowsEnabled = val === "true";
                    else if (key === "decoration:shadow:range")
                        root.shadowRange = parseInt(val) || 0;
                    else if (key === "decoration:shadow:render_power")
                        root.shadowRenderPower = parseInt(val) || 0;
                    else if (key === "decoration:shadow:sharp")
                        root.shadowSharp = val === "true";
                    else if (key === "general:border_size") {
                        const size = parseInt(val) || 0;
                        root.bordersEnabled = size > 0;
                        if (size > 0)
                            root.savedBorderSize = size;
                    } else if (key === "general:gaps_in")
                        root.gapsIn = parseInt(val) || 0;
                    else if (key === "general:gaps_out")
                        root.gapsOut = parseInt(val) || 0;
                    else if (key === "decoration:active_opacity")
                        root.activeOpacity = parseFloat(val) || 0;
                    else if (key === "decoration:inactive_opacity")
                        root.inactiveOpacity = parseFloat(val) || 0;
                    else if (key === "decoration:rounding")
                        root.rounding = parseInt(val) || 0;
                    else if (key === "decoration:rounding_power")
                        root.roundingPower = parseFloat(val) || 0;
                }
            }
        }
    }
}
