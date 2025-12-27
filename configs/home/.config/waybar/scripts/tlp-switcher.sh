#!/bin/bash

# Show menu using wofi to select TLP power profile
PROFILE=$(echo -e "performance\nbalanced\npower-saver" | wofi -dmenu -p "TLP Profile:")

if [ -z "$PROFILE" ]; then
    exit 0
fi

# Set power profile
case "$PROFILE" in
    "performance")
        sudo tlp set-powermanagementprofiles performance
        ;;
    "balanced")
        sudo tlp set-powermanagementprofiles balanced
        ;;
    "power-saver")
        sudo tlp set-powermanagementprofiles powersaver
        ;;
esac
