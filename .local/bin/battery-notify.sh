#!/bin/bash

# Dynamically find the battery (BAT0, BAT1, BATT, etc.)
BAT=$(find /sys/class/power_supply -maxdepth 1 \( -name 'BAT*' -o -name 'BATT*' \) | head -n1 | xargs basename 2>/dev/null)

if [ -z "$BAT" ]; then
    echo "No battery found."
    exit 1
fi

# State variables to prevent notification spam
NOTIFIED_10=false
NOTIFIED_5=false

while true; do
    # Get current battery capacity and status
    CAPACITY=$(cat "/sys/class/power_supply/$BAT/capacity" 2>/dev/null) || { sleep 60; continue; }
    STATUS=$(cat "/sys/class/power_supply/$BAT/status" 2>/dev/null) || { sleep 60; continue; }

    if [ "$STATUS" = "Charging" ] || [ "$STATUS" = "Full" ]; then
        # Reset notification states when plugged in
        NOTIFIED_10=false
        NOTIFIED_5=false
    elif [ "$STATUS" = "Discharging" ]; then
        if [ "$CAPACITY" -le 5 ] && [ "$NOTIFIED_5" = false ]; then
            notify-send -u critical "Battery Critical" "Battery level is at ${CAPACITY}%! Plug in immediately."
            NOTIFIED_5=true
            NOTIFIED_10=true  # Prevent the 10% alert firing on a rapid drop
        elif [ "$CAPACITY" -le 10 ] && [ "$NOTIFIED_10" = false ]; then
            notify-send -u normal "Battery Low" "Battery level is at ${CAPACITY}%."
            NOTIFIED_10=true
        fi
    fi

    sleep 60
done