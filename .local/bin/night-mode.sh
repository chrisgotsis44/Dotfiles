#!/bin/sh
# Toggle wlsunset night light. Replace with your own logic freely.
if pgrep -x wlsunset > /dev/null; then
    pkill -x wlsunset
else
    setsid wlsunset -t 4000 -T 6500 > /dev/null 2>&1 &
fi
