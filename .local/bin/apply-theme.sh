#!/bin/bash
# Color codes
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

CONF="$HOME/.config"
CURRENT_THEME_FILE="$CONF/colorschemes/.current-theme"
WALLPAPER_STATE="$CONF/colorschemes/.wallpaper-state"
CURRENT_WALLPAPER_FILE="$CONF/colorschemes/.current-wallpaper"

# --list flag: show available themes
if [ "${1:-}" = "--list" ]; then
    echo -e "${CYAN}Available themes:${NC}"
    for d in "$CONF/colorschemes"/*/; do
        theme=$(basename "$d")
        current=$(cat "$CURRENT_THEME_FILE" 2>/dev/null)
        if [ "$theme" = "$current" ]; then
            echo -e "  ${GREEN}* $theme (active)${NC}"
        else
            echo "    $theme"
        fi
    done
    exit 0
fi

THEME="${1:-}"
THEME_DIR="$CONF/colorschemes/$THEME"

if [ -z "$THEME" ]; then
    echo -e "${YELLOW}Usage: $0 <theme-name>${NC}"
    echo -e "${YELLOW}       $0 --list${NC}"
    exit 1
fi

if [ ! -d "$THEME_DIR" ]; then
    echo -e "${YELLOW}Theme '$THEME' does not exist at $THEME_DIR${NC}"
    notify-send "Theme Error" "Theme '$THEME' not found" -u critical
    exit 1
fi

# Matugen: restore last-used wallpaper if saved, otherwise open the picker
if [ "$THEME" = "matugen" ]; then
    echo "matugen" > "$CURRENT_THEME_FILE"

    touch "$WALLPAPER_STATE"
    SAVED_MATUGEN=$(grep "^matugen:" "$WALLPAPER_STATE" | cut -d':' -f2-)

    if [ -n "$SAVED_MATUGEN" ] && [ -f "$SAVED_MATUGEN" ]; then
        echo -e "${GREEN}Applying matugen theme with last-used wallpaper...${NC}"
        exec "$HOME/.local/bin/wallpaper-apply-post.sh" --set-live "$SAVED_MATUGEN"
    else
        # No saved wallpaper yet -- nothing to apply colors from, so open
        # the island's own picker instead (there's no standalone picker
        # process to spawn anymore). Picking one there calls
        # wallpaper-apply-post.sh itself, which does the matugen regen.
        echo -e "${CYAN}No saved matugen wallpaper — opening picker...${NC}"
        notify-send "Theme Switching" "Pick a wallpaper for matugen..." -t 3000
        qs -c island ipc call shell toggleWallpaperPicker
        exit 0
    fi
fi

# Track current theme
echo "$THEME" > "$CURRENT_THEME_FILE"

echo -e "${GREEN}Applying theme: $THEME${NC}\n"
#notify-send "Theme Switching" "Applying theme: $THEME" -t 3000

# --- Hyprland config ---
echo -e "${CYAN}-> Updating Hyprland configuration...${NC}"
(
    cp "$THEME_DIR/hypr/colors.conf"                       "$CONF/hypr/colors/colors.conf"
    cp "$CONF/hypr/modules/decoration/colors/custom-themes.lua"  "$CONF/hypr/modules/decoration/colors/hyprland-colors.lua"
    THEME_LUA="$CONF/hypr/colors/custom/$THEME.lua"
    [ -f "$THEME_LUA" ] && echo "return require(\"colors.custom.$THEME\")" > "$CONF/hypr/colors/theme_vars.lua"
) &
echo ""

# --- Wallpaper ---
echo -e "${CYAN}-> Setting wallpaper...${NC}"
WALLPAPER_DIR="$THEME_DIR/wallpapers"
touch "$WALLPAPER_STATE"

SAVED_WALLPAPER=$(grep "^$THEME:" "$WALLPAPER_STATE" | cut -d':' -f2-)

if [ -n "$SAVED_WALLPAPER" ] && [ -f "$SAVED_WALLPAPER" ]; then
    WALLPAPER="$SAVED_WALLPAPER"
    echo -e "${CYAN}   Using saved wallpaper${NC}"
elif [ -d "$WALLPAPER_DIR" ]; then
    # Pick first wallpaper — now supports video formats too
    WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( \
        -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
        -o -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.webm" \
    \) | sort | head -n1)
    if [ -n "$WALLPAPER" ]; then
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
    if [[ "$WALLPAPER" =~ \.(mp4|mkv|mov|webm|MP4|MKV|MOV|WEBM)$ ]]; then
        pkill mpvpaper || true
        mpvpaper -o 'loop --no-audio --hwdec=auto --profile=high-quality --video-sync=display-resample --interpolation --tscale=oversample' \
            '*' "$WALLPAPER" &
    else
        pkill mpvpaper || true
        awww img "$WALLPAPER" --transition-type center --transition-fps 60 --transition-step 255 >/dev/null 2>&1
    fi
    # The lockscreen reads .current-wallpaper directly, so the old
    # hyprlock/wallpaper symlink no longer has a consumer.
    echo "$WALLPAPER" > "$CURRENT_WALLPAPER_FILE"
else
    echo -e "${YELLOW}   Could not set wallpaper${NC}"
fi
echo ""

# --- All remaining config steps in parallel ---
echo -e "${CYAN}-> Applying theme components in parallel...${NC}"

# GTK theme
( if [ -f "$THEME_DIR/gtk-theme" ]; then
      GTK_THEME_NAME=$(cat "$THEME_DIR/gtk-theme")
      echo -e "${CYAN}   GTK: $GTK_THEME_NAME${NC}"
      gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME_NAME" >/dev/null 2>&1
  fi ) &

# GTK4 symlinks
( GTK4_SRC="$THEME_DIR/gtk-4.0"
  GTK4_DST="$CONF/gtk-4.0"
  if [ -d "$GTK4_SRC" ]; then
      mkdir -p "$GTK4_DST"
      ln -sf "$GTK4_SRC/gtk.css"      "$GTK4_DST/gtk.css"
      ln -sf "$GTK4_SRC/gtk-dark.css" "$GTK4_DST/gtk-dark.css"
      ln -sfn "$GTK4_SRC/assets"      "$GTK4_DST/assets"
  fi ) &

# Kvantum
( cp "$THEME_DIR/Kvantum/kvantum.kvconfig" "$CONF/Kvantum/kvantum.kvconfig" >/dev/null 2>&1 ) &

# Terminal (kitty)
( [ -f "$THEME_DIR/kitty/colors.conf" ] && \
      cp "$THEME_DIR/kitty/colors.conf" "$CONF/kitty/colors/colors.conf" >/dev/null 2>&1 ) &

wait
echo ""

reload-ui.sh

#notify-send "Theme Applied" "Successfully switched to: $THEME" -t 5000
