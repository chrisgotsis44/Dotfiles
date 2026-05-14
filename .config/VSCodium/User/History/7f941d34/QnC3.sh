#!/bin/bash

# Fetch the saved cursor theme and size from gsettings
CURSOR_THEME=$(gsettings get org.gnome.desktop.interface cursor-theme | tr -d "'")
CURSOR_SIZE=$(gsettings get org.gnome.desktop.interface cursor-size)

sleep 1

# Apply the cursor to Hyprland
hyprctl setcursor "$CURSOR_THEME" "$CURSOR_SIZE"

# Export the variables so Wayland/XWayland apps launched later use the right cursor
hyprctl keyword env XCURSOR_THEME,"$CURSOR_THEME"
hyprctl keyword env XCURSOR_SIZE,"$CURSOR_SIZE"

# Start watching for live changes made by nwg-look
gsettings monitor org.gnome.desktop.interface cursor-theme | while read -r _; do
    CURSOR_THEME=$(gsettings get org.gnome.desktop.interface cursor-theme | tr -d "'")
    CURSOR_SIZE=$(gsettings get org.gnome.desktop.interface cursor-size)
    
    hyprctl setcursor "$CURSOR_THEME" "$CURSOR_SIZE"
    hyprctl keyword env XCURSOR_THEME,"$CURSOR_THEME"
    hyprctl keyword env XCURSOR_SIZE,"$CURSOR_SIZE"
done