#!/bin/bash
# Display TLP power profile only if tlp.service is enabled at system level

# Check if tlp.service is enabled at system level (not user)
if ! systemctl is-enabled tlp.service &>/dev/null 2>&1; then
    exit 0
fi

# Get current power profile from tlp-stat
tlp-stat -s 2>/dev/null | grep 'Power profile' | awk -F'= ' '{print $2}' | sed 's|/.*||' | sed 's/^./\U&/'
