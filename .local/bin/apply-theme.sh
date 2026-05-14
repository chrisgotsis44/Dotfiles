#!/bin/bash
# Color codes
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

THEME="$1"
CONF="$HOME/.config"
THEME_DIR="$CONF/colorschemes/$THEME"
CURRENT_THEME_FILE="$CONF/colorschemes/.current-theme"
WALLPAPER_STATE="$CONF/colorschemes/.wallpaper-state"
CURRENT_WALLPAPER_FILE="$CONF/colorschemes/.current-wallpaper"

if [ -z "$THEME" ]; then
    echo -e "${YELLOW}Usage: $0 <theme-name>${NC}"
    exit 1
fi

if [ ! -d "$THEME_DIR" ]; then
    echo -e "${YELLOW}Theme '$THEME' does not exist at $THEME_DIR${NC}"
    notify-send "Theme Error" "Theme '$THEME' not found" -u critical
    exit 1
fi

# Track current theme
echo "$THEME" > "$CURRENT_THEME_FILE"

echo -e "${GREEN}Applying theme: $THEME${NC}\n"
notify-send "Theme Switching" "Applying theme: $THEME" -t 3000

# Hyprland config
echo -e "${CYAN}-> Updating Hyprland configuration...${NC}"
cp "$THEME_DIR/hypr/colors.conf" "$CONF/hypr/colors/colors.conf" > /dev/null 2>&1
cp "$CONF/hypr/modules/decorations/custom-themes.conf" "$CONF/hypr/modules/decoration.conf" > /dev/null 2>&1
cp "$CONF/hypr/hyprlock/custom-themes.conf" "$CONF/hypr/hyprlock.conf" > /dev/null 2>&1
echo ""

# Wallpaper
echo -e "${CYAN}-> Setting wallpaper...${NC}"
WALLPAPER_DIR="$THEME_DIR/wallpapers"

# Create state file if it doesn't exist
touch "$WALLPAPER_STATE"

# Get saved wallpaper for this theme
SAVED_WALLPAPER=$(grep "^$THEME:" "$WALLPAPER_STATE" | cut -d':' -f2-)

if [ -n "$SAVED_WALLPAPER" ] && [ -f "$SAVED_WALLPAPER" ]; then
    # Use saved wallpaper
    WALLPAPER="$SAVED_WALLPAPER"
    echo -e "${CYAN}   Using saved wallpaper${NC}"
elif [ -d "$WALLPAPER_DIR" ]; then
    # Get first wallpaper from directory (sorted alphabetically)
    WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | sort | head -n1)
    
    if [ -n "$WALLPAPER" ]; then
        # Save this as the default for this theme
        sed -i "/^$THEME:/d" "$WALLPAPER_STATE"
        echo "$THEME:$WALLPAPER" >> "$WALLPAPER_STATE"
        echo -e "${CYAN}   Using first wallpaper (default)${NC}"
    else
        echo -e "${YELLOW}   No wallpapers found in $WALLPAPER_DIR${NC}"
    fi
else
    echo -e "${YELLOW}   Wallpaper directory not found: $WALLPAPER_DIR${NC}"
fi

if [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ]; then
    awww img "$WALLPAPER" --transition-type center --transition-fps 60 --transition-step 255 > /dev/null 2>&1
    # Also update hyprlock symlink
    ln -sf "$WALLPAPER" "$CONF/hypr/hyprlock/wallpaper" > /dev/null 2>&1
else
    echo -e "${YELLOW}   Could not set wallpaper${NC}"
fi
echo ""

#Save Current Wallpaper
echo "$WALLPAPER" > "$CURRENT_WALLPAPER_FILE"

# GTK Theme
if [ -f "$THEME_DIR/gtk-theme" ]; then
    GTK_THEME_NAME=$(cat "$THEME_DIR/gtk-theme")
    echo -e "${CYAN}-> Setting GTK theme to '$GTK_THEME_NAME'...${NC}"
    gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME_NAME" > /dev/null 2>&1
else
    echo -e "${YELLOW}-> GTK theme file not found. Skipping.${NC}"
fi
echo ""

GTK4_SRC="$THEME_DIR/gtk-4.0"
GTK4_DST="$CONF/gtk-4.0"

if [[ -d "$GTK4_SRC" ]]; then
    echo -e "${CYAN}-> Linking GTK4 theme files...${NC}"
    mkdir -p "$GTK4_DST"
    ln -sf "$GTK4_SRC/gtk.css" "$GTK4_DST/gtk.css"
    ln -sf "$GTK4_SRC/gtk-dark.css" "$GTK4_DST/gtk-dark.css"
    ln -sfn "$GTK4_SRC/assets" "$GTK4_DST/assets"
else
    echo -e "${YELLOW}-> No GTK4 theme files found in $GTK4_SRC. Skipping.${NC}"
fi
echo ""

#Kvantum Theme
echo -e "${CYAN}-> Applying Kvantum theme...${NC}"
cp "$THEME_DIR/Kvantum/kvantum.kvconfig" "$CONF/Kvantum/kvantum.kvconfig" > /dev/null 2>&1
echo ""

# Terminal theme
echo -e "${CYAN}-> Applying terminal theme...${NC}"
if [ -f "$THEME_DIR/kitty/colors.conf" ]; then
    cp "$THEME_DIR/kitty/colors.conf" "$CONF/kitty/colors/colors.conf" > /dev/null 2>&1
else
    echo -e "${YELLOW}-> No terminal theme defined for $THEME. Skipping.${NC}"
fi
echo ""

# SwayNC theme
echo -e "${CYAN}-> Applying SwayNC theme...${NC}"
cp "$THEME_DIR/swaync/colors.css" "$CONF/swaync/colors/colors.css" > /dev/null 2>&1
cp "$CONF/swaync/themes/custom-themes/control-center.css" "$CONF/swaync/components/control-center.css" > /dev/null 2>&1
cp "$CONF/swaync/themes/custom-themes/notifications.css" "$CONF/swaync/components/notifications.css" > /dev/null 2>&1
echo ""

# Waybar style
echo -e "${CYAN}-> Applying Waybar CSS...${NC}"
cp "$THEME_DIR/waybar/colors.css" "$CONF/waybar/colors/colors.css" > /dev/null 2>&1
cp "$CONF/waybar/layouts/01-MyConf/custom-themes/style.css" "$CONF/waybar/layouts/01-MyConf/style.css" > /dev/null 2>&1
cp "$CONF/waybar/layouts/02-MyConf2/custom-themes/style.css" "$CONF/waybar/layouts/02-MyConf2/style.css" > /dev/null 2>&1
echo ""

# wlogout theme
echo -e "${CYAN}-> Applying wlogout theme...${NC}"
cp "$THEME_DIR/wlogout/colors.css" "$CONF/wlogout/colors/colors.css" > /dev/null 2>&1
cp "$CONF/wlogout/themes/custom_themes/style.css" "$CONF/wlogout/style.css" > /dev/null 2>&1
echo ""

# Rofi theme
echo -e "${CYAN}-> Applying Rofi theme...${NC}"
cp "$THEME_DIR/rofi/colors.rasi" "$CONF/rofi/colors/colors.rasi" > /dev/null 2>&1
cp "$CONF/rofi/themes/custom-themes/grid.rasi" "$CONF/rofi/launchers/grid.rasi" > /dev/null 2>&1
cp "$CONF/rofi/themes/custom-themes/minimal.rasi" "$CONF/rofi/launchers/minimal.rasi" > /dev/null 2>&1
cp "$CONF/rofi/themes/custom-themes/wallpapers.rasi" "$CONF/rofi/launchers/wallpapers.rasi" > /dev/null 2>&1
cp "$CONF/rofi/themes/custom-themes/apps.rasi" "$CONF/rofi/launchers/apps.rasi" > /dev/null 2>&1
echo ""

# Call the master UI reloader
reload-ui.sh

# Final success notification
notify-send "Theme Applied" "Successfully switched to: $THEME" -t 5000