#!/bin/bash
THEME=$(gsettings get org.gnome.desktop.interface cursor-theme | tr -d "'")
SIZE=$(gsettings get org.gnome.desktop.interface cursor-size)
hyprctl setcursor "$THEME" "$SIZE"
