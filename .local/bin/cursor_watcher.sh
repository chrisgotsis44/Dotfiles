#!/bin/bash

# hyprctl keyword env used to also run here after every setcursor call, to
# keep XCURSOR_THEME/XCURSOR_SIZE in sync for apps that read them from their
# own environment at startup rather than querying the compositor live.
# `hyprctl keyword` doesn't work at all anymore on this system's Lua-parsed
# config ("keyword can't work with non-legacy parsers. Use eval." --
# confirmed by testing it directly), so those calls were silently failing
# every single time. There's no direct replacement: hl.env() is
# startup-only, and Hyprland forks apps launched via `exec`/binds as its
# own direct children, which only ever inherit Hyprland's env from when
# IT started -- there's no live "set my own env for future children" path.
#
# hyprctl setcursor below is unaffected and remains the actual live
# mechanism -- it's a dedicated dispatcher, not a keyword, and it's what
# makes the cursor change instantly for Hyprland's own rendering and for
# already-running clients that support live cursor-theme updates.
#
# The systemctl/dbus-update-activation-environment calls are the closest
# real fix for the env-var gap: they update the systemd user session and
# D-Bus activation environments, which covers apps launched via systemd
# user services or D-Bus/portal activation (though NOT ones launched
# directly via Hyprland binds, which inherit Hyprland's own unchanged
# env regardless -- there's no way around that short of restarting
# Hyprland itself).

# 1. Read the saved theme directly from the text file nwg-look writes to.
#    This completely bypasses the gsettings "default" bug on boot!
CURSOR_THEME=$(grep 'Inherits=' ~/.icons/default/index.theme 2>/dev/null | cut -d'=' -f2)
CURSOR_SIZE=24  # Hardcoding the size is safest for the initial boot

apply_cursor() {
    local theme="$1" size="$2"
    hyprctl setcursor "$theme" "$size"
    systemctl --user set-environment XCURSOR_THEME="$theme" XCURSOR_SIZE="$size"
    dbus-update-activation-environment --systemd XCURSOR_THEME XCURSOR_SIZE 2>/dev/null
}

# Guard: if no theme found, skip initial apply and go straight to watching
if [ -z "$CURSOR_THEME" ]; then
    echo "cursor_watcher: no cursor theme found in ~/.icons/default/index.theme, skipping initial apply"
else
    apply_cursor "$CURSOR_THEME" "$CURSOR_SIZE"
fi

# 2. Watch for live changes from nwg-look
gsettings monitor org.gnome.desktop.interface cursor-theme | while read -r _; do
    LIVE_THEME=$(gsettings get org.gnome.desktop.interface cursor-theme | tr -d "'")
    LIVE_SIZE=$(gsettings get org.gnome.desktop.interface cursor-size)

    # CRITICAL: If something tries to reset it to "default", ignore it!
    if [ "$LIVE_THEME" != "default" ] && [ -n "$LIVE_THEME" ]; then
        apply_cursor "$LIVE_THEME" "$LIVE_SIZE"
    fi
done