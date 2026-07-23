#!/bin/bash
# Hard-restarts the island quickshell config (bound to SUPER SHIFT, B).
#
# Quickshell hot-reloads on file changes on its own and has no "reload"
# IPC call -- a running instance can't safely relaunch itself, so this
# does a plain kill + relaunch instead. The naive version of that
# (`qs -c island kill; qs -c island`) can race: `qs list` clears almost
# immediately after kill, but the actual process (and its D-Bus
# connections) can take a little longer to finish exiting, so relaunching
# right away can have the new instance start before the old one is fully
# gone. This waits for the old PID to actually disappear first.

OLD_PID=$(qs list --all 2>/dev/null | awk '
    /^Instance/ { pid = "" }
    /Config path:.*\/island\/shell\.qml$/ { want = 1 }
    want && /Process ID:/ { print $3; exit }
')

qs -c island kill >/dev/null 2>&1

if [ -n "$OLD_PID" ]; then
    for _ in $(seq 1 50); do
        kill -0 "$OLD_PID" 2>/dev/null || break
        sleep 0.1
    done
fi

qs -c island >/dev/null 2>&1 &
disown
