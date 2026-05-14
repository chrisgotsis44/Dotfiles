#!/bin/bash

# Fetch the cursor theme and size from gsettings
# We use tr to remove the single quotes gsettings outputs
CURSOR_THEME=$(gsettings get org.gnome.desktop.interface cursor-theme | tr -d "'")
CURSOR_SIZE=$(gsettings get org.gnome.desktop.interface cursor-size)

# Apply the cursor to Hyprland
hyprctl setcursor "$CURSOR_THEME" "$CURSOR_SIZE"

# Export the variables so new applications use them
hyprctl keyword env XCURSOR_THEME,"$CURSOR_THEME"
hyprctl keyword env XCURSOR_SIZE,"$CURSOR_SIZE"