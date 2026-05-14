#!/bin/bash

# 1. Read the saved theme directly from the text file nwg-look writes to.
# This completely bypasses the gsettings "default" bug on boot!
CURSOR_THEME=$(grep 'Inherits=' ~/.icons/default/index.theme | cut -d'=' -f2)
CURSOR_SIZE=24 # Hardcoding the size is safest for the initial boot

# 2. Apply it to Hyprland immediately
hyprctl setcursor "$CURSOR_THEME" "$CURSOR_SIZE"
hyprctl keyword env XCURSOR_THEME,"$CURSOR_THEME"
hyprctl keyword env XCURSOR_SIZE,"$CURSOR_SIZE"

# 3. Watch for live changes from nwg-look
gsettings monitor org.gnome.desktop.interface cursor-theme | while read -r _; do
    LIVE_THEME=$(gsettings get org.gnome.desktop.interface cursor-theme | tr -d "'")
    LIVE_SIZE=$(gsettings get org.gnome.desktop.interface cursor-size)
    
    # CRITICAL: If something tries to reset it to "default", ignore it!
    if [ "$LIVE_THEME" != "default" ]; then
        hyprctl setcursor "$LIVE_THEME" "$LIVE_SIZE"
        hyprctl keyword env XCURSOR_THEME,"$LIVE_THEME"
        hyprctl keyword env XCURSOR_SIZE,"$LIVE_SIZE"
    fi
done