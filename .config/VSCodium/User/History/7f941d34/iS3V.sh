#!/bin/bash

# Fetch initial settings
CURSOR_THEME=$(gsettings get org.gnome.desktop.interface cursor-theme | tr -d "'")
CURSOR_SIZE=$(gsettings get org.gnome.desktop.interface cursor-size)

# Write them directly to the sourced config file
echo "env = XCURSOR_THEME,$CURSOR_THEME" > ~/.config/hypr/modules/cursor.conf
echo "env = XCURSOR_SIZE,$CURSOR_SIZE" >> ~/.config/hypr/modules/cursor.conf

# Watch for live changes made by nwg-look
gsettings monitor org.gnome.desktop.interface cursor-theme | while read -r _; do
    CURSOR_THEME=$(gsettings get org.gnome.desktop.interface cursor-theme | tr -d "'")
    CURSOR_SIZE=$(gsettings get org.gnome.desktop.interface cursor-size)
    
    # Update the config file with the new theme
    echo "env = XCURSOR_THEME,$CURSOR_THEME" > ~/.config/hypr/modules/cursor.conf
    echo "env = XCURSOR_SIZE,$CURSOR_SIZE" >> ~/.config/hypr/modules/cursor.conf
    
    # Force Hyprland to reload the config and catch the new variables
    hyprctl reload
done