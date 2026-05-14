#!/bin/bash

# Color codes
CYAN='\033[1;36m'
NC='\033[0m' # No Color

# Variables
CONF="$HOME/.config"
wallpaper_dir="$HOME/Pictures/Wallpapers"
CURRENT_WALLPAPER_FILE="$CONF/colorschemes/.current-wallpaper"

# Handle spaces in filenames safely
IFS=$'\n'

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Grab the user-selected wallpaper using Rofi
# (We run the directory change inside the subshell so we don't have to cd back and forth)
selected_wall=$(cd "$wallpaper_dir" && for a in *.jpg *.png; do echo -en "$a\0icon\x1f$a\n" ; done | rofi -dmenu -p "Choose Wallpaper" -theme "$CONF/rofi/launchers/wallpapers.rasi")

# If a wallpaper was selected (the user didn't press escape)
if [ -n "$selected_wall" ]; then
    
    # Construct the absolute path to the image
    IMAGE="$wallpaper_dir/$selected_wall"
    echo "$IMAGE" > "$CURRENT_WALLPAPER_FILE"

    # Send notification
    notify-send "Changing Theme" "Applying new wallpaper and updating colors..."

    # Apply wallpaper with awww
    awww img "$IMAGE" --transition-fps 240 --transition-step 255 --transition-type center

    # Clean up custom GTK4 symlinks so Matugen doesn't overwrite your static themes
    echo -e "${CYAN}-> Preparing GTK4 for Matugen...${NC}"
    if [ -h "$CONF/gtk-4.0/gtk.css" ]; then
        rm -f "$CONF/gtk-4.0/gtk.css"
        rm -f "$CONF/gtk-4.0/gtk-dark.css"
        rm -f "$CONF/gtk-4.0/assets"
    fi

    # Apply colors with matugen
    #matugen image "$IMAGE" --source-color-index 0
    #matugen image "$IMAGE" -m dark -t scheme-tonal-spot --prefer less-saturation
    matugen image "$IMAGE" -m dark -t scheme-content --prefer value
    
    # Hyprland config
    echo -e "${CYAN}-> Updating Hyprland configuration...${NC}"
    cp "$CONF/matugen/includes/colors.conf" "$CONF/hypr/colors/colors.conf" > /dev/null 2>&1
    cp "$CONF/hypr/modules/decorations/matugen.conf" "$CONF/hypr/modules/decoration.conf" > /dev/null 2>&1
    cp "$CONF/hypr/hyprlock/matugen.conf" "$CONF/hypr/hyprlock.conf" > /dev/null 2>&1
    echo ""

    # SwayNC theme
    echo -e "${CYAN}-> Applying SwayNC theme...${NC}"
    cp "$CONF/matugen/includes/colors.css" "$CONF/swaync/colors/colors.css" > /dev/null 2>&1
    cp "$CONF/swaync/themes/matugen/control-center.css" "$CONF/swaync/components/control-center.css" > /dev/null 2>&1
    cp "$CONF/swaync/themes/matugen/notifications.css" "$CONF/swaync/components/notifications.css" > /dev/null 2>&1
    echo ""

    # Waybar style
    echo -e "${CYAN}-> Applying Waybar CSS...${NC}"
    cp "$CONF/matugen/includes/colors.css" "$CONF/waybar/colors/colors.css" > /dev/null 2>&1
    cp "$CONF/waybar/layouts/01-MyConf/matugen/style.css" "$CONF/waybar/layouts/01-MyConf/style.css" > /dev/null 2>&1
    cp "$CONF/waybar/layouts/02-MyConf2/matugen/style.css" "$CONF/waybar/layouts/02-MyConf2/style.css" > /dev/null 2>&1
    echo ""

    # Gtk Theme
    echo -e "${CYAN}-> Updating Gtk theme...${NC}"
    gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3" && gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' > /dev/null 2>&1
    echo ""

    #Kvantum Theme
    echo -e "${CYAN}-> Updating Kvantum theme...${NC}"
    cp "$CONF/matugen/includes/kvantum.kvconfig" "$CONF/Kvantum/kvantum.kvconfig" > /dev/null 2>&1
    echo ""

    # Terminal theme
    echo -e "${CYAN}-> Applying terminal theme...${NC}"
    cp "$CONF/matugen/includes/colors-kitty.conf" "$CONF/kitty/colors/colors.conf" > /dev/null 2>&1
    echo ""

    # wlogout theme
    echo -e "${CYAN}-> Applying wlogout theme...${NC}"
    cp "$CONF/matugen/includes/colors.css" "$CONF/wlogout/colors/colors.css" > /dev/null 2>&1
    cp "$CONF/wlogout/themes/matugen/style.css" "$CONF/wlogout/style.css" > /dev/null 2>&1
    echo ""

    # Rofi theme
    echo -e "${CYAN}-> Applying Rofi theme...${NC}"
    cp "$CONF/matugen/includes/colors.rasi" "$CONF/rofi/colors/colors.rasi" > /dev/null 2>&1
    cp "$CONF/rofi/themes/matugen/grid.rasi" "$CONF/rofi/launchers/grid.rasi" > /dev/null 2>&1
    cp "$CONF/rofi/themes/matugen/minimal.rasi" "$CONF/rofi/launchers/minimal.rasi" > /dev/null 2>&1
    cp "$CONF/rofi/themes/matugen/wallpapers.rasi" "$CONF/rofi/launchers/wallpapers.rasi" > /dev/null 2>&1
    cp "$CONF/rofi/themes/matugen/apps.rasi" "$CONF/rofi/launchers/apps.rasi" > /dev/null 2>&1
    echo ""

    # Call the master UI reloader in the background
    reload-ui.sh

    # Send success notification
    notify-send "Theme Applied" "Wallpaper and theme updated successfully!"
fi