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
# gone. This waits for every old process to actually disappear first.
#
# EVERY instance, not just the first one. The earlier version read a single
# PID out of `qs list` and waited only on that, so if a duplicate ever
# existed -- e.g. this script run twice in quick succession, where the
# second run's `qs list` fires before the first relaunch has registered --
# it would kill one, leave the other, and add a third. Duplicated islands
# then fight over the same layer-shell namespace, the polkit agent and the
# IPC socket: keybinds reach whichever instance answers first (often not
# the one you can see), and the shell eventually crashes. Sweeping all of
# them makes the script idempotent no matter how often it is run.

mapfile -t OLD_PIDS < <(pgrep -x -f "qs -c island" 2>/dev/null)

qs -c island kill >/dev/null 2>&1

# SIGTERM anything the IPC kill did not take down (a wedged instance has no
# working socket, so `qs kill` cannot reach it).
for pid in "${OLD_PIDS[@]}"; do
    [ -n "$pid" ] && kill -TERM "$pid" 2>/dev/null
done

for _ in $(seq 1 60); do
    still=0
    for pid in "${OLD_PIDS[@]}"; do
        [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && still=1
    done
    [ "$still" -eq 0 ] && break
    sleep 0.1
done

# Last resort, so a relaunch can never stack on a survivor.
for pid in "${OLD_PIDS[@]}"; do
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null
done

qs -c island >/dev/null 2>&1 &
disown
