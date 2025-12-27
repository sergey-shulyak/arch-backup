#!/bin/bash

# TLP Profile Switcher for Waybar
# Select power profile and show current status

# Get current TLP profile
CURRENT=$(tlp-stat -s 2>/dev/null | grep "Power profile" | awk -F'= ' '{print $2}' | sed 's|/.*||' || echo "Unknown")

# Show menu using wofi to select TLP profile
MODE=$(echo -e "Performance (AC)\nBalanced (Battery)\nPower-saver (Max saving)" | wofi -dmenu -p "TLP Profile (Current: $CURRENT):")

if [ -z "$MODE" ]; then
    exit 0
fi

# Execute selected profile with sudo
case "$MODE" in
    "Performance (AC)")
        notify-send -t 2000 "TLP" "Switching to Performance mode..." -i "settings"
        sudo tlp performance
        notify-send -t 2000 "TLP" "Performance mode activated" -i "settings"
        ;;
    "Balanced (Battery)")
        notify-send -t 2000 "TLP" "Switching to Balanced mode..." -i "settings"
        sudo tlp balanced
        notify-send -t 2000 "TLP" "Balanced mode activated" -i "settings"
        ;;
    "Power-saver (Max saving)")
        notify-send -t 2000 "TLP" "Switching to Power-saver mode..." -i "settings"
        sudo tlp powersaver
        notify-send -t 2000 "TLP" "Power-saver mode activated" -i "settings"
        ;;
esac
