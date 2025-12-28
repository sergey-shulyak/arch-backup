#!/usr/bin/env bash

# Float focused window at 75% 4:3 ratio, centered

# Get screen dimensions
SCREEN_HEIGHT=$(hyprctl monitors -j | jq -r ".[0].height" 2>/dev/null)
SCREEN_WIDTH=$(hyprctl monitors -j | jq -r ".[0].width" 2>/dev/null)

if [ -z "$SCREEN_HEIGHT" ] || [ -z "$SCREEN_WIDTH" ] || [ "$SCREEN_HEIGHT" -eq 0 ]; then
    exit 0
fi

# Calculate 4:3 dimensions (75% of screen)
WINDOW_HEIGHT=$((SCREEN_HEIGHT * 75 / 100))
WINDOW_WIDTH=$((WINDOW_HEIGHT * 4 / 3))

# Ensure width doesn't exceed screen width
if [ "$WINDOW_WIDTH" -gt "$SCREEN_WIDTH" ]; then
    WINDOW_WIDTH=$((SCREEN_WIDTH * 75 / 100))
    WINDOW_HEIGHT=$((WINDOW_WIDTH * 3 / 4))
fi

# Center the window
X_OFFSET=$(( (SCREEN_WIDTH - WINDOW_WIDTH) / 2 ))
Y_OFFSET=$(( (SCREEN_HEIGHT - WINDOW_HEIGHT) / 2 ))

# Apply changes
hyprctl --batch "dispatch togglefloating active ; dispatch resizewindowpixel exact $WINDOW_WIDTH $WINDOW_HEIGHT active ; dispatch movewindowpixel exact $X_OFFSET $Y_OFFSET active" > /dev/null 2>&1
