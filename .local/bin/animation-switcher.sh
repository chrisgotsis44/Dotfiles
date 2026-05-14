#!/usr/bin/env bash
set -euo pipefail

HYPR_MODULES_DIR="$HOME/.config/hypr/modules"
ANIMATIONS_DIR="$HYPR_MODULES_DIR/animations"
TARGET_CONF="$HYPR_MODULES_DIR/animations.conf"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr_animations"
STATE_FILE="$STATE_DIR/last_animation"
NOTIFY=${NOTIFY:-notify-send}

mkdir -p "$STATE_DIR"

if [[ ! -d "$ANIMATIONS_DIR" ]]; then
  echo "No animations directory at $ANIMATIONS_DIR" >&2
  exit 1
fi

# Find all .conf files in the animations directory, removing the .conf extension for the menu
mapfile -t ANIMATIONS < <(find "$ANIMATIONS_DIR" -mindepth 1 -maxdepth 1 -type f -name "*.conf" -printf "%f\n" | sed 's/\.conf$//' | sort)
((${#ANIMATIONS[@]})) || { echo "No animations found in $ANIMATIONS_DIR"; exit 1; }

# Detect current animation
current="(none)"
if [[ -L "$TARGET_CONF" ]]; then
  tgt=$(readlink -f "$TARGET_CONF" || true)
  if [[ "$tgt" == "$ANIMATIONS_DIR/"*".conf" ]]; then
    current=$(basename "$tgt" .conf)
  fi
fi

# Build menu with a pipe indicating the current animation
menu=$(printf "%s\n" "${ANIMATIONS[@]}" | awk -v c="$current" '{print ($0==c?"| ":"  ")$0}')
chosen=$(echo "$menu" | rofi -dmenu -i -p "Select Animation" -theme ~/.config/rofi/launchers/minimal.rasi | sed 's/^| //; s/^  //')
[[ -z "${chosen:-}" ]] && exit 0

cfg_src="$ANIMATIONS_DIR/${chosen}.conf"

[[ -f "$cfg_src" ]] || { echo "Missing $cfg_src"; exit 1; }

# Create/update the symlink to the chosen animation
ln -sf "$cfg_src" "$TARGET_CONF"

# Save state
echo "$chosen" > "$STATE_FILE"

# Reload Hyprland to apply the new animation settings
hyprctl reload >/dev/null 2>&1 || true

[[ "$NOTIFY" = ":" ]] || $NOTIFY "Hyprland" "Animation: $chosen"