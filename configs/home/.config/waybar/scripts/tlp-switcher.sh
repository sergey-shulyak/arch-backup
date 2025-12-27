#!/bin/bash

# Show menu using wofi to select TLP power profile
PROFILE=$(echo -e "performance\nbalanced\npower-saver" | wofi -dmenu -p "Select TLP Profile:")

if [ -z "$PROFILE" ]; then
    exit 0
fi

# Set power profile using tlp command
sudo tlp "$PROFILE"

# Check if the command succeeded
if [ $? -eq 0 ]; then
    # Notify that the profile was changed
    notify-send "TLP Profile" "Switched to $(echo $PROFILE | sed 's/^./\U&/')" -u low
else
    notify-send "TLP Profile" "Failed to switch to $PROFILE" -u critical
fi
