#!/bin/bash

# Color codes
CYAN='\033[1;36m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color

echo -e "${CYAN}-> Reloading UI Components in parallel...${NC}"

hyprctl reload > /dev/null 2>&1 &

reload-waybar-swaync.sh > /dev/null 2>&1 &

killall -SIGUSR1 kitty > /dev/null 2>&1 &

echo -e "${GREEN}-> UI Reload Complete!${NC}\n"