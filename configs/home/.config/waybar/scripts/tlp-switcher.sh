#!/bin/bash

# Show menu using wofi to select TLP power profile with emoji and formatting
SELECTED=$(echo -e "🚀 Performance\n⚖️ Balanced\n🔋 Power Saver" | wofi -dmenu -p "Select Power Plan:")

if [ -z "$SELECTED" ]; then
  exit 0
fi

# Extract the profile name from the selected option
PROFILE=$(echo "$SELECTED" | sed 's/^[^ ]* //' | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')

# Handle power-saver case specially
if [ "$PROFILE" = "power-saver" ]; then
  PROFILE="power-saver"
fi

# Set power profile using tlp command
sudo tlp "$PROFILE"

# Check if the command succeeded
if [ $? -eq 0 ]; then
  # Notify that the profile was changed
  notify-send "TLP Profile" "Switched to $SELECTED" -u low
else
  notify-send "TLP Profile" "Failed to switch profile" -u critical
fi
