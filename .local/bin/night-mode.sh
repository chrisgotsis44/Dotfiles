#!/bin/bash

# ┏━ ┛┏━┛┃ ┃━┏┛  ┏┏ ┏━┃┏━ ┏━┛
# ┃ ┃┃┃ ┃┏━┃ ┃   ┃┃┃┃ ┃┃ ┃┏━┛
# ┛ ┛┛━━┛┛ ┛ ┛   ┛┛┛━━┛━━ ━━┛

NOTIFY_ID="string:x-canonical-private-synchronous:nightlight"

if pgrep -x "wlsunset" > /dev/null; then
    killall wlsunset
    notify-send -h "$NOTIFY_ID" "Night Light" "Off" -u "low"
else
    # High temp (4501) is strictly higher than low temp (4500), bypassing the error!
    wlsunset -T 5001 -t 5000 &
    notify-send -h "$NOTIFY_ID" "Night Light" "On" -u "low"
fi