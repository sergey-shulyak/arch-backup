#!/bin/bash

# Show menu using wofi to select TLP mode
MODE=$(echo -e "AC\nBattery" | wofi -dmenu -p "TLP Mode:")

if [ -z "$MODE" ]; then
    exit 0
fi

# Execute selected mode with sudo
case "$MODE" in
    "AC")
        sudo tlp ac
        ;;
    "Battery")
        sudo tlp bat
        ;;
esac
