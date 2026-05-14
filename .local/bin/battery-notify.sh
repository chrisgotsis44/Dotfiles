#!/bin/bash

# Dynamically find the battery (usually BAT0 or BAT1)
BAT=$(ls /sys/class/power_supply | grep -i bat | head -n 1)

if [ -z "$BAT" ]; then
    echo "No battery found."
    exit 1
fi

# State variables to prevent notification spam
NOTIFIED_10=false
NOTIFIED_5=false

while true; do
    # Get current battery capacity and status
    CAPACITY=$(cat /sys/class/power_supply/$BAT/capacity)
    STATUS=$(cat /sys/class/power_supply/$BAT/status)

    if [ "$STATUS" = "Charging" ] || [ "$STATUS" = "Full" ]; then
        # Reset notification states when plugged in
        NOTIFIED_10=false
        NOTIFIED_5=false
    elif [ "$STATUS" = "Discharging" ]; then
        if [ "$CAPACITY" -le 5 ] && [ "$NOTIFIED_5" = false ]; then
            # Send critical notification
            notify-send -u critical "Battery Critical" "Battery level is at ${CAPACITY}%! Plug in immediately."
            NOTIFIED_5=true
            NOTIFIED_10=true # Prevents the 10% notification from firing if capacity drops rapidly
            
        elif [ "$CAPACITY" -le 10 ] && [ "$NOTIFIED_10" = false ]; then
            # Send warning notification
            notify-send -u normal "Battery Low" "Battery level is at ${CAPACITY}%."
            NOTIFIED_10=true
        fi
    fi

    # Check every 60 seconds (adjust as needed)
    sleep 60
done