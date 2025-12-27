#!/bin/bash
# Display Monitor for Waybar
# Shows display switcher button only on ThinkPad (laptop)
# Hidden on rig (desktop)

hostname=$(cat /etc/hostname 2>/dev/null | tr -d '\n')

# Only show on ThinkPad
if [ "$hostname" = "thinkpad" ]; then
    echo "🖥️"
fi
