#!/usr/bin/env bash

# Auto-detect current screen and update Hyprland config window sizes

SCREEN_HEIGHT=$(hyprctl monitors -j | jq -r ".[0].height" 2>/dev/null)
SCREEN_WIDTH=$(hyprctl monitors -j | jq -r ".[0].width" 2>/dev/null)

if [ -z "$SCREEN_HEIGHT" ] || [ -z "$SCREEN_WIDTH" ]; then
    echo "Failed to detect screen resolution"
    exit 1
fi

echo "Detected screen: ${SCREEN_WIDTH}x${SCREEN_HEIGHT}"

# Calculate main window size: 4:3 ratio at 75% of screen height
MAIN_HEIGHT=$((SCREEN_HEIGHT * 75 / 100))
MAIN_WIDTH=$((MAIN_HEIGHT * 4 / 3))
if [ "$MAIN_WIDTH" -gt "$SCREEN_WIDTH" ]; then
    MAIN_WIDTH=$((SCREEN_WIDTH * 75 / 100))
    MAIN_HEIGHT=$((MAIN_WIDTH * 3 / 4))
fi
echo "Main windows (4:3 75%): ${MAIN_WIDTH}x${MAIN_HEIGHT}"

# Calculate TUI size: 10:7 ratio at 50% of screen height
TUI_HEIGHT=$((SCREEN_HEIGHT * 50 / 100))
TUI_WIDTH=$((TUI_HEIGHT * 10 / 7))
if [ "$TUI_WIDTH" -gt "$SCREEN_WIDTH" ]; then
    TUI_WIDTH=$((SCREEN_WIDTH * 50 / 100))
    TUI_HEIGHT=$((TUI_WIDTH * 7 / 10))
fi
echo "TUI applications (10:7 50%): ${TUI_WIDTH}x${TUI_HEIGHT}"

echo ""

# Update window-rules.conf with all sizes
CONFIG_FILE="$HOME/.config/hypr/window-rules.conf"

# Update main auto float/tile windows
sed -i "s/windowrulev2 = size [0-9]* [0-9]*, class:\.\*/windowrulev2 = size $MAIN_WIDTH $MAIN_HEIGHT, class:.*/" "$CONFIG_FILE"

# Update all TUI applications (btop, nmtui, bluetuith, pulsemixer)
sed -i "s/windowrulev2 = size [0-9]* [0-9]*, title:\^\(btop|nmtui|bluetuith|pulsemixer\)\$/windowrulev2 = size $TUI_WIDTH $TUI_HEIGHT, title:^(btop|nmtui|bluetuith|pulsemixer)$/" "$CONFIG_FILE"

echo "✓ Updated window sizes in ~/.config/hypr/window-rules.conf"
echo ""
echo "Summary for ${SCREEN_WIDTH}x${SCREEN_HEIGHT}:"
echo "  Main windows: ${MAIN_WIDTH}x${MAIN_HEIGHT}"
echo "  TUI applications: ${TUI_WIDTH}x${TUI_HEIGHT}"
echo ""
echo "Reload Hyprland with: hyprctl reload"
