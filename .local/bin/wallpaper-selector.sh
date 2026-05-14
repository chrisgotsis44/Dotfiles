#!/bin/bash

COLORSCHEMES_DIR="$HOME/.config/colorschemes"
WALLPAPER_STATE="$COLORSCHEMES_DIR/.wallpaper-state"
CURRENT_THEME_FILE="$COLORSCHEMES_DIR/.current-theme"
CURRENT_WALLPAPER_FILE="$HOME/.config/colorschemes/.current-wallpaper"

# Get current theme
if [ ! -f "$CURRENT_THEME_FILE" ]; then
    notify-send "Error" "No theme currently active"
    exit 1
fi

CURRENT_THEME=$(cat "$CURRENT_THEME_FILE")
WALLPAPER_DIR="$COLORSCHEMES_DIR/$CURRENT_THEME/wallpapers"

# --- NEW CHECK FOR MATUGEN ---
# Read the true active wallpaper that was last set by either script
if [ -f "$CURRENT_WALLPAPER_FILE" ]; then
    ACTUAL_WALLPAPER=$(cat "$CURRENT_WALLPAPER_FILE")
    
    # If the active wallpaper is NOT located inside your colorschemes directory, 
    # we know your Matugen script set it from the Pictures folder.
    if [[ "$ACTUAL_WALLPAPER" != "$COLORSCHEMES_DIR"* ]]; then
        notify-send "Notice" "Dynamic Matugen theme is active." # Optional notification
        exit 0
    fi
fi


if [ ! -d "$WALLPAPER_DIR" ]; then
    notify-send "Error" "No wallpapers directory found for theme: $CURRENT_THEME"
    exit 1
fi

# Get list of wallpapers
mapfile -t wallpapers < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.svg" \) | sort)

if [ ${#wallpapers[@]} -eq 0 ]; then
    notify-send "Error" "No wallpapers found in $WALLPAPER_DIR"
    exit 1
fi

# Get currently selected wallpaper
CURRENT_WALLPAPER=$(grep "^$CURRENT_THEME:" "$WALLPAPER_STATE" 2>/dev/null | cut -d':' -f2-)

# Build menu with icon paths for rofi
menu_options=""
for wp in "${wallpapers[@]}"; do
    basename_wp=$(basename "$wp")
    if [ "$wp" = "$CURRENT_WALLPAPER" ]; then
        menu_options+="| $basename_wp\0icon\x1f$wp\n"
    else
        menu_options+="$basename_wp\0icon\x1f$wp\n"
    fi
done

# Show rofi with icons
selected=$(echo -en "$menu_options" | rofi -dmenu -i -p "Select Wallpaper" -show-icons -theme ~/.config/rofi/launchers/wallpapers.rasi)

if [ -z "$selected" ]; then
    exit 0
fi

# Remove the bullet point if present
selected=$(echo "$selected" | sed 's/^● //')

# Find the full path
selected_path=""
for wp in "${wallpapers[@]}"; do
    if [ "$(basename "$wp")" = "$selected" ]; then
        selected_path="$wp"
        break
    fi
done

if [ -z "$selected_path" ]; then
    notify-send "Error" "Could not find selected wallpaper"
    exit 1
fi

# Apply wallpaper with wipe transition
awww img "$selected_path" --transition-type wipe --transition-fps 240 --transition-step 255

# Update state file
touch "$WALLPAPER_STATE"
sed -i "/^$CURRENT_THEME:/d" "$WALLPAPER_STATE"
echo "$CURRENT_THEME:$selected_path" >> "$WALLPAPER_STATE"
echo "$selected_path" > "$CURRENT_WALLPAPER_FILE"

# Update hyprlock symlink
ln -sf "$selected_path" ~/.config/hypr/hyprlock/wallpaper

notify-send "Wallpaper Changed" "Applied: $selected"
