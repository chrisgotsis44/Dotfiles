#!/usr/bin/env bash
# island-activity.sh -- run a command with a Live Activity on the island.
#
#   island-activity.sh <icon> <title> -- <command> [args...]
#
# Examples:
#   island-activity.sh package "System update" -- yay -Syu --noconfirm
#   island-activity.sh folder_zip "Compressing" -- tar czf out.tgz bigdir/
#   island-activity.sh sync "Backing up" -- rsync -a ~/Documents /mnt/backup/
#
# The activity is indeterminate: the island shows a sliding sliver, since
# an arbitrary command cannot report a fraction. It is removed when the
# command exits, whether it succeeded or not, and the command's own exit
# status is passed through unchanged so this stays transparent in scripts.
#
# `icon` is a Material Symbols name (https://fonts.google.com/icons).
set -uo pipefail

if [ "$#" -lt 4 ]; then
    echo "usage: $(basename "$0") <icon> <title> -- <command> [args...]" >&2
    exit 2
fi

ICON=$1
TITLE=$2
SEP=$3
shift 3

if [ "$SEP" != "--" ]; then
    echo "usage: $(basename "$0") <icon> <title> -- <command> [args...]" >&2
    exit 2
fi

# Unique per invocation, so two of these running at once do not collide on
# one id and overwrite each other's activity.
ID="run-$$"

act() {
    # The shell may not be running, and a background job must never fail
    # because a cosmetic status chip could not be posted.
    qs -c island ipc call activity "$@" >/dev/null 2>&1 || true
}

# An activity stuck on the pill with no process behind it is worse than
# never having shown one, so this runs on every exit path.
cleanup() { act remove "$ID"; }
trap cleanup EXIT

act push "$ID" "$ICON" "$TITLE" "$(basename "$1")" "" -1

# The command runs in the BACKGROUND, and this waits on it, rather than the
# obvious `"$@"` in the foreground. Bash defers trap handlers until a
# foreground child finishes, so with the simple version a Ctrl-C or a kill
# left the chip on the pill until the command ended on its own -- exactly
# when cleanup matters most. `wait` is interruptible, so signals land
# immediately here.
#
# `< /dev/stdin` is what makes that safe: a non-interactive shell redirects
# an async command's stdin from /dev/null, which would break every
# interactive command (`yay -Syu` asking for a password, say). An explicit
# redirection overrides that and hands the real stdin through.
"$@" < /dev/stdin &
child=$!

trap 'kill -TERM "$child" 2>/dev/null' INT TERM

wait "$child"
status=$?

# A signal interrupts `wait` before the child is reaped; wait again for its
# real status so this stays transparent in scripts.
if [ "$status" -gt 128 ]; then
    wait "$child" 2>/dev/null
    status=$?
fi

exit "$status"
