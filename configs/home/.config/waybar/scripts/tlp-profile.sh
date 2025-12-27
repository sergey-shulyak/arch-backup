#!/bin/bash
# Display TLP power profile only if tlp.service is enabled at system level

# Check if tlp.service is enabled at system level (not user)
if ! systemctl is-enabled tlp.service &>/dev/null 2>&1; then
    exit 0
fi

# Get current power profile from ACPI platform profile
if [ -f /sys/firmware/acpi/platform_profile ]; then
    cat /sys/firmware/acpi/platform_profile | sed 's/^./\U&/'
fi
