#!/bin/sh
# Toggle idle/sleep inhibition. Replace with your own logic freely —
# the shell only cares that running this flips the state.
if pgrep -f "systemd-inhibit.*who=idle_inhibitor" > /dev/null; then
    pkill -f "systemd-inhibit.*who=idle_inhibitor"
else
    setsid systemd-inhibit --what=idle:sleep --who=idle_inhibitor \
        --why="Manual keep-awake toggle" sleep infinity > /dev/null 2>&1 &
fi
