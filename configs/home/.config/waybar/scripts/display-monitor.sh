#!/bin/bash
# Display Monitor for Waybar
# Shows display switcher button only when multiple monitors are connected

# Get count of connected monitors
monitor_count=$(hyprctl monitors -j 2>/dev/null | jq 'length' 2>/dev/null || echo 0)

# Only output if more than 1 monitor is connected
if [ "$monitor_count" -gt 1 ]; then
    echo "🖥️"
fi
