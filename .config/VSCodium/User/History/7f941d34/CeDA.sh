#!/bin/bash

# Apply the cursor right at startup
CURSOR_THEME=$(gsettings get org.gnome.desktop.interface cursor-theme | tr -d "'")
CURSOR_SIZE=$(gsettings get org.gnome.desktop.interface cursor-size)
hyprctl setcursor "$CURSOR_THEME" "$CURSOR_SIZE"

# Start watching gsettings for any live changes made by nwg-look
gsettings monitor org.gnome.desktop.interface cursor-theme | while read -r _; do
    CURSOR_THEME=$(gsettings get org.gnome.desktop.interface cursor-theme | tr -d "'")
    CURSOR_SIZE=$(gsettings get org.gnome.desktop.interface cursor-size)
    
    hyprctl setcursor "$CURSOR_THEME" "$CURSOR_SIZE"
done