#!/usr/bin/env bash

# Auto-detect current screen and update Hyprland config for 75% 4:3 floating windows

SCREEN_HEIGHT=$(hyprctl monitors -j | jq -r ".[0].height" 2>/dev/null)
SCREEN_WIDTH=$(hyprctl monitors -j | jq -r ".[0].width" 2>/dev/null)

if [ -z "$SCREEN_HEIGHT" ] || [ -z "$SCREEN_WIDTH" ]; then
    echo "Failed to detect screen resolution"
    exit 1
fi

# Calculate 4:3 dimensions (75% of screen)
WINDOW_HEIGHT=$((SCREEN_HEIGHT * 75 / 100))
WINDOW_WIDTH=$((WINDOW_HEIGHT * 4 / 3))

# Ensure width doesn't exceed screen width
if [ "$WINDOW_WIDTH" -gt "$SCREEN_WIDTH" ]; then
    WINDOW_WIDTH=$((SCREEN_WIDTH * 75 / 100))
    WINDOW_HEIGHT=$((WINDOW_WIDTH * 3 / 4))
fi

echo "Detected screen: ${SCREEN_WIDTH}x${SCREEN_HEIGHT}"
echo "Calculated window size: ${WINDOW_WIDTH}x${WINDOW_HEIGHT} (75% 4:3 ratio)"

# Update window-rules.conf
sed -i "s/windowrulev2 = size [0-9]* [0-9]*, class:.*/windowrulev2 = size $WINDOW_WIDTH $WINDOW_HEIGHT, class:.*/" ~/.config/hypr/window-rules.conf

echo "✓ Updated ~/.config/hypr/window-rules.conf"
echo "Config ready for ${SCREEN_WIDTH}x${SCREEN_HEIGHT} display"
