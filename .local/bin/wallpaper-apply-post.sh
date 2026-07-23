#!/bin/bash
# Runs after a wallpaper is chosen, from either of two callers:
#   1. The island's integrated picker (WallpaperPicker.qml's
#      applyWallpaper()), which has already set the image live itself
#      (with a compositor-ready retry loop) before calling this.
#   2. apply-theme.sh, when switching INTO the matugen theme with a
#      previously-saved wallpaper -- pass --set-live so this script sets
#      the image live too, since nothing else has by that point.
# Replaces the bookkeeping that wallpaper-selector.sh /
# wallpapers-set-matugen.sh used to do after the old standalone picker
# process exited and left its pick in /tmp/qs_last_wallpaper -- both are
# gone now (the picker is permanent, no separate process to wait on), so
# this just runs inline instead.
set -u

SET_LIVE=0
if [ "${1:-}" = "--set-live" ]; then
    SET_LIVE=1
    shift
fi

IMAGE="${1:?Usage: wallpaper-apply-post.sh [--set-live] <wallpaper-path>}"
CONF="$HOME/.config"
THEME=$(cat "$CONF/colorschemes/.current-theme" 2>/dev/null || echo "")

CURRENT_WALLPAPER_FILE="$CONF/colorschemes/.current-wallpaper"
WALLPAPER_STATE="$CONF/colorschemes/.wallpaper-state"

if [ "$SET_LIVE" = "1" ]; then
    pkill mpvpaper 2>/dev/null || true
    case "$IMAGE" in
        *.mp4|*.mkv|*.mov|*.webm|*.MP4|*.MKV|*.MOV|*.WEBM)
            mpvpaper -o 'loop --no-audio --hwdec=auto --profile=high-quality --video-sync=display-resample --interpolation --tscale=oversample' '*' "$IMAGE" & ;;
        *)
            awww img "$IMAGE" --transition-type center --transition-fps 60 --transition-step 255 >/dev/null 2>&1 ;;
    esac
fi

echo "$IMAGE" > "$CURRENT_WALLPAPER_FILE"
touch "$WALLPAPER_STATE"
sed -i "/^$THEME:/d" "$WALLPAPER_STATE"
echo "$THEME:$IMAGE" >> "$WALLPAPER_STATE"
ln -sf "$IMAGE" "$CONF/hypr/hyprlock/wallpaper"

if [ "$THEME" != "matugen" ]; then
    notify-send "Wallpaper Changed" "Applied: $(basename "$IMAGE")"
    exit 0
fi

# matugen: full color regeneration
notify-send "Changing Theme" "Applying new wallpaper and updating colors..."

if [ -h "$CONF/gtk-4.0/gtk.css" ]; then
    rm -f "$CONF/gtk-4.0/gtk.css" "$CONF/gtk-4.0/gtk-dark.css" "$CONF/gtk-4.0/assets"
fi

MATUGEN_TARGET="$IMAGE"
case "$IMAGE" in
    *.mp4|*.mkv|*.mov|*.webm|*.MP4|*.MKV|*.MOV|*.WEBM)
        MATUGEN_TARGET="$HOME/.cache/wallpaper_picker/thumbs_matugen/$(basename "$IMAGE")" ;;
esac

matugen image "$MATUGEN_TARGET" -m dark -t scheme-vibrant --prefer saturation

( echo 'return require("colors.custom.matugen")' > "$CONF/hypr/colors/theme_vars.lua"
  cp "$CONF/matugen/includes/colors.conf"       "$CONF/hypr/colors/colors.conf"
  cp "$CONF/hypr/modules/decoration/colors/matugen.lua" "$CONF/hypr/modules/decoration/colors/hyprland-colors.lua"
  cp "$CONF/hypr/hyprlock/matugen.conf"          "$CONF/hypr/hyprlock.conf" ) &
( gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3"
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' ) &
( cp "$CONF/matugen/includes/kvantum.kvconfig"   "$CONF/Kvantum/kvantum.kvconfig" ) &
( cp "$CONF/matugen/includes/colors-kitty.conf"  "$CONF/kitty/colors/colors.conf" ) &
wait

reload-ui.sh
notify-send "Theme Applied" "Wallpaper and theme updated successfully!"
