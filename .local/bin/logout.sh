#!/usr/bin/env bash

# Quietly kill only the specific apps known to hold onto the Wayland socket
killall -q xdg-desktop-portal-hyprland
killall -q xdg-desktop-portal-wlr
killall -q xdg-desktop-portal
killall -q waybar
killall -q hyprpaper

# Wait half a second
sleep 0.5

# Exit Hyprland natively
hyprctl dispatch exit