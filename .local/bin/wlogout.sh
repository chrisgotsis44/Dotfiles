#!/usr/bin/env bash

# Define margins for 1080p
top_margin_1080=400
bottom_margin_1080=400

# Check if wlogout is already running
if pgrep -x "wlogout" > /dev/null; then
    pkill -x "wlogout"
    exit 0
fi

# Get the scaled resolution height of the focused monitor
scaled_height=$(hyprctl -j monitors | jq -r '.[] | select(.focused==true) | .height')

# Calculate margins based on 1080p baseline
top_margin=$(awk -v m="$top_margin_1080" -v h="$scaled_height" 'BEGIN {printf "%.0f", m * h / 1080}')
bottom_margin=$(awk -v m="$bottom_margin_1080" -v h="$scaled_height" 'BEGIN {printf "%.0f", m * h / 1080}')

# Run wlogout with computed margins
wlogout -C "$HOME/.config/wlogout/style.css" \
        -l "$HOME/.config/wlogout/layout" \
        --protocol layer-shell \
        -b 5 \
        -T "$top_margin" \
        -B "$bottom_margin" &

