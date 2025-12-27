#!/bin/bash
# Check if the system has a battery

# Check if any battery device exists in /sys/class/power_supply
if [ -d /sys/class/power_supply ]; then
    # Look for BAT* or battery devices
    if ls /sys/class/power_supply/BAT* &>/dev/null 2>&1 || ls /sys/class/power_supply/battery &>/dev/null 2>&1; then
        # Battery exists, return success
        exit 0
    fi
fi

# No battery found
exit 1
