pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

// Live audio spectrum for the idle pill's visualizer, straight from
// cava.
//
// cava is spawned with a config generated inline (bash process
// substitution -- no temp file to write, stale, or clean up) in its
// "raw" output mode, which is exactly this: one line per frame,
// semicolon-separated bar heights, forever. Everything else cava
// normally does (drawing, colors, its own TUI) is off.
//
// Source selection is `auto` deliberately, NOT a hardcoded device:
// verified with `pactl list source-outputs` that cava then attaches to
// the default sink's *monitor* -- i.e. what you're actually hearing,
// not the microphone -- so plugging in headphones or switching to HDMI
// follows along by itself.
//
// Cost control: the process only exists while a media player says it's
// playing AND no menu is covering the idle pill. Nothing is playing, or
// you're in the Control Center? There is no cava process at all. This
// is the same "costs nothing while nobody's looking" rule SysMonitor
// follows for the dashboard.
//
// The MPRIS gate does mean audio from something with no MPRIS player (a
// game, a bare `mpv --no-video`) won't light the pill up. That's the
// deliberate trade: the alternative is cava running all day for a rare
// case.
Singleton {
    id: root

    // How many values cava computes. Rendered mirrored, so the pill
    // shows twice this many bars -- bass in the middle, treble at both
    // ends. Kept low on purpose: at pill scale, more bars stop reading
    // as a spectrum and start reading as noise.
    readonly property int bars: Math.max(2, Math.min(12, Config.settings.cavaBars))

    // Latest frame, normalised 0..1, oldest-to-newest left to right.
    // Starts as a zero-filled array of the right length so consumers can
    // lay out their bars before the first frame ever arrives.
    property var levels: new Array(root.bars).fill(0)

    // False until cava has actually produced a frame -- covers cava not
    // being installed at all, in which case the pill just stays a clock.
    property bool available: false

    // Music apps only: Spotify, mpv, a local player -- explicitly NOT a
    // browser (see Media.isBrowser). A YouTube tab or an autoplaying ad
    // shouldn't turn the clock into a music player, and browsers publish
    // MPRIS for both.
    readonly property bool wanted: Media.isPlaying && !Media.activeIsBrowser && !GlobalState.anyMenuOpen

    onWantedChanged: {
        if (!wanted) {
            // Drop straight back to silence rather than leaving the last
            // frame frozen on screen mid-bar.
            root.levels = new Array(root.bars).fill(0);
            root.available = false;
        }
    }

    Process {
        id: proc
        running: root.wanted

        // ascii_max_range picks the resolution of each value (0..100);
        // channels=mono is what makes it one value per bar instead of a
        // stereo pair. autosens keeps quiet tracks from flatlining.
        command: ["bash", "-c", `cava -p <(cat <<'CFG'
[general]
framerate = 60
bars = ${root.bars}
autosens = 1

[input]
method = pipewire
source = auto

[output]
method = raw
data_format = ascii
ascii_max_range = 100
channels = mono

[smoothing]
noise_reduction = 30
CFG
)`]

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: data => {
                // "12;44;90;3;0;7;" -- note the trailing separator, so
                // the split leaves an empty last element.
                const parts = String(data).split(";");
                const out = [];
                for (let i = 0; i < parts.length; i++) {
                    const s = parts[i];
                    if (s === "")
                        continue;
                    const v = parseInt(s, 10);
                    out.push(isNaN(v) ? 0 : Math.max(0, Math.min(1, v / 100)));
                }
                if (out.length === 0)
                    return;

                root.levels = out;
                root.available = true;
            }
        }
    }
}
