#!/usr/bin/env bash
# lock.sh -- launch the standalone Quickshell lockscreen.
#
# Replaces hyprlock. The locker is its own Quickshell config
# (~/.config/quickshell/lock), separate from the island shell so a fault in
# the bar cannot take the lockscreen down with it. It locks on startup and
# exits once unlocked.
#
# flock replaces the old `pidof hyprlock ||` guard: hypridle's lock_cmd, the
# SUPER+L bind and `loginctl lock-session` can all fire at once, and a second
# session-lock client stacking on top of the first is not something the
# protocol recovers from cleanly. -n makes the duplicate exit immediately
# instead of queueing behind the running one.
set -euo pipefail

LOCKFILE="${XDG_RUNTIME_DIR:-/tmp}/qs-lock.lock"

exec flock -n "$LOCKFILE" qs -c lock
