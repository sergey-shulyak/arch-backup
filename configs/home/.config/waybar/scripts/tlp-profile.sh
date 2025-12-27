#!/bin/bash
# Display TLP power profile only if tlp.service is enabled at system level

# Check if tlp.service is enabled at system level (not user)
if ! systemctl is-enabled tlp.service &>/dev/null 2>&1; then
    exit 0
fi

# Format profile name for display
format_profile() {
    local profile=$1
    case "$profile" in
        performance)
            echo "🚀 Performance"
            ;;
        balanced)
            echo "⚖️ Balanced"
            ;;
        power-saver|low-power)
            echo "🔋 Power Saver"
            ;;
        *)
            # Capitalize first letter
            echo "${profile^}"
            ;;
    esac
}

# Get current power profile from ACPI platform profile
if [ -f /sys/firmware/acpi/platform_profile ]; then
    profile=$(cat /sys/firmware/acpi/platform_profile)

    if [ "$1" = "--tooltip" ]; then
        # Return just the readable name for tooltip
        format_profile "$profile"
    else
        # Return just the first letter uppercase for the button
        echo "${profile:0:1}" | tr '[:lower:]' '[:upper:]'
    fi
fi
