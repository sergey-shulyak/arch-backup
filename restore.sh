#!/bin/bash
#
# Arch Linux Configuration Restore Script
# Restores system configuration files from backup repository
#

set -e

BACKUP_DIR="$HOME/Documents/arch-backup"
CONFIG_DIR="$BACKUP_DIR/configs"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Check if backup directory exists
check_backup() {
    if [ ! -d "$BACKUP_DIR" ]; then
        log_error "Backup directory not found: $BACKUP_DIR"
        read -p "Enter git repository URL to clone: " repo_url

        if [ -z "$repo_url" ]; then
            log_error "Repository URL required"
            exit 1
        fi

        mkdir -p "$HOME/Documents"
        cd "$HOME/Documents"
        git clone "$repo_url" arch-backup
        log_info "Repository cloned successfully"
    fi

    cd "$BACKUP_DIR"

    # Pull latest changes if it's a git repo
    if [ -d ".git" ]; then
        log_info "Pulling latest changes from remote..."
        git pull origin "$(git branch --show-current)" 2>/dev/null || log_warn "Could not pull from remote"
    fi
}

# Restore function - copies file/directory with backup of existing
restore_item() {
    local src="$1"
    local dest="$2"
    local sudo_required="${3:-false}"

    if [ ! -e "$src" ]; then
        log_warn "Source not found in backup: $src"
        return
    fi

    # Ensure parent directory exists
    local parent_dir=$(dirname "$dest")
    if [ "$sudo_required" = "true" ]; then
        sudo mkdir -p "$parent_dir"
        sudo cp -r "$src" "$dest"
    else
        mkdir -p "$parent_dir"
        cp -r "$src" "$dest"
    fi
    log_info "Restored: $dest"
}

# Restore home configuration files
restore_home_configs() {
    log_section "Restoring Home Directory Configs"

    local home_config="$CONFIG_DIR/home"

    if [ ! -d "$home_config" ]; then
        log_warn "No home configs found in backup"
        return
    fi

    # Find all files in backup and restore them
    cd "$home_config"
    find . -type f | while read -r file; do
        # Remove leading ./
        local rel_path="${file#./}"
        local src="$home_config/$rel_path"
        local dest="$HOME/$rel_path"
        restore_item "$src" "$dest" "false"
    done
}

# Setup Hyprland monitors config for current machine
setup_hyprland_monitors() {
    local current_hostname=$(cat /etc/hostname 2>/dev/null || echo "unknown")
    local hypr_config="$HOME/.config/hypr"
    local monitors_specific="$hypr_config/monitors-$current_hostname.conf"
    local monitors_main="$hypr_config/monitors.conf"

    # Only run if hyprland config exists
    if [ ! -d "$hypr_config" ]; then
        return
    fi

    log_info "Setting up Hyprland monitors for hostname: $current_hostname"

    if [ -f "$monitors_specific" ]; then
        # Copy machine-specific config to monitors.conf
        cp "$monitors_specific" "$monitors_main"
        log_info "Created $monitors_main from $monitors_specific"
    elif [ -f "$hypr_config/monitors-default.conf" ]; then
        # Fallback to default
        cp "$hypr_config/monitors-default.conf" "$monitors_main"
        log_warn "Using default monitors config (machine-specific not found)"
    else
        # Create a basic fallback
        echo "# Default monitor setup - please customize with: hyprctl monitors all" > "$monitors_main"
        echo "monitor=,preferred,auto,1" >> "$monitors_main"
        log_warn "Created basic monitors.conf - please customize for your system"
    fi
}

# Restore system configuration files
restore_system_configs() {
    log_section "Restoring System Configs"

    local etc_config="$CONFIG_DIR/etc"

    if [ ! -d "$etc_config" ]; then
        log_warn "No system configs found in backup"
        return
    fi

    log_warn "System config restoration requires sudo"
    read -p "Do you want to restore system configs? (y/N): " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Skipping system configs"
        return
    fi

    cd "$etc_config"
    find . -type f | while read -r file; do
        local rel_path="${file#./}"
        local src="$etc_config/$rel_path"
        local dest="/etc/$rel_path"
        restore_item "$src" "$dest" "true"
    done
}

# GPU driver packages to exclude from backup/restore
GPU_DRIVERS=(
    "nvidia-open-dkms"
    "nvidia-dkms"
    "nvidia"
    "nvidia-utils"
    "nvidia-settings"
    "libva-nvidia-driver"
    "libxnvctrl"
    "libnvidia-container"
    "libnvidia-container-tools"
    "amd-ucode"
    "intel-ucode"
    "intel-media-driver"
    "libva-intel-driver"
    "libva-mesa-driver"
    "vulkan-intel"
    "vulkan-radeon"
    "vulkan-amd"
    "lib32-vulkan-intel"
    "lib32-vulkan-radeon"
    "lib32-vulkan-amd"
    "mesa"
    "lib32-mesa"
)

# Build grep pattern for GPU drivers
build_gpu_driver_pattern() {
    local pattern="^("
    for driver in "${GPU_DRIVERS[@]}"; do
        pattern="${pattern}${driver}|"
    done
    pattern="${pattern%|})\$"
    echo "$pattern"
}

# Install packages from backup lists
restore_packages() {
    log_section "Restoring Packages"

    local pkg_dir="$BACKUP_DIR/packages"
    local gpu_pattern=$(build_gpu_driver_pattern)

    if [ ! -d "$pkg_dir" ]; then
        log_warn "No package lists found in backup"
        return
    fi

    # Check for AUR helper
    local aur_helper=""
    if command -v paru &>/dev/null; then
        aur_helper="paru"
    elif command -v yay &>/dev/null; then
        aur_helper="yay"
    fi

    # Restore native packages (official repos)
    if [ -f "$pkg_dir/pacman-native.txt" ]; then
        log_info "Installing native packages from official repositories..."
        read -p "Install native packages? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            # Filter out GPU drivers and already installed packages
            local to_install=$(grep -vE "$gpu_pattern" "$pkg_dir/pacman-native.txt" | comm -23 <(sort) <(pacman -Qqn | sort) | tr '\n' ' ')
            if [ -n "$to_install" ]; then
                sudo pacman -S --needed $to_install
            else
                log_info "All native packages already installed"
            fi
        fi
    fi

    # Restore AUR packages
    if [ -f "$pkg_dir/pacman-aur.txt" ]; then
        log_info "Installing AUR packages..."
        read -p "Install AUR packages? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            if [ -z "$aur_helper" ]; then
                log_warn "No AUR helper (yay/paru) found"
                log_info "Install yay or paru first, then run this again"
                log_info "AUR packages to install are listed in: $pkg_dir/pacman-aur.txt"
            else
                # Filter out GPU drivers and already installed packages
                local to_install=$(grep -vE "$gpu_pattern" "$pkg_dir/pacman-aur.txt" | comm -23 <(sort) <(pacman -Qqm | sort) | tr '\n' ' ')
                if [ -n "$to_install" ]; then
                    $aur_helper -S --needed $to_install
                else
                    log_info "All AUR packages already installed"
                fi
            fi
        fi
    fi
}

# Restore systemd services automatically based on hardware/hostname
restore_systemd() {
    log_section "Restoring Systemd Services"

    local systemd_dir="$BACKUP_DIR/systemd"

    if [ ! -d "$systemd_dir" ]; then
        log_warn "No systemd service lists found in backup"
        return
    fi

    # Detect current hostname for hardware-specific decisions
    local current_hostname=$(cat /etc/hostname 2>/dev/null || echo "unknown")
    log_info "Current hostname: $current_hostname"

    # Load hardware mapping
    declare -A hardware_map
    local hardware_map_file="$systemd_dir/HARDWARE_MAPPING.conf"
    if [ -f "$hardware_map_file" ]; then
        while IFS='|' read -r service machines desc; do
            # Skip comments and empty lines
            [[ "$service" =~ ^#.*$ ]] && continue
            [[ -z "$service" ]] && continue
            hardware_map["$service"]="$machines"
        done < "$hardware_map_file"
    fi

    # Helper to check if service applies to current machine
    service_applies_to_machine() {
        local service=$1
        local applicable="${hardware_map[$service]:-all}"

        # If "all", always applies
        [[ "$applicable" == "all" ]] && return 0

        # Check if current hostname is in the comma-separated list
        [[ ",$applicable," == *",$current_hostname,"* ]] && return 0

        # Doesn't apply
        return 1
    }

    # Apply user service state
    apply_user_service() {
        local service=$1
        local action=$2

        case "$action" in
            enable)
                systemctl --user enable "$service" 2>/dev/null && \
                    log_info "  Enabled: $service" || \
                    log_warn "  Failed to enable: $service"
                ;;
            disable)
                systemctl --user disable "$service" 2>/dev/null && \
                    log_info "  Disabled: $service" || \
                    log_warn "  Failed to disable: $service"
                ;;
        esac
    }

    # Apply system service state
    apply_system_service() {
        local service=$1
        local action=$2

        case "$action" in
            enable)
                sudo systemctl enable "$service" 2>/dev/null && \
                    log_info "  Enabled: $service" || \
                    log_warn "  Failed to enable: $service"
                ;;
            disable)
                sudo systemctl disable "$service" 2>/dev/null && \
                    log_info "  Disabled: $service" || \
                    log_warn "  Failed to disable: $service"
                ;;
        esac
    }

    # Restore user services from detailed state file
    if [ -f "$systemd_dir/user-services-state.txt" ]; then
        log_info "Analyzing user services for $current_hostname..."
        echo ""

        # Collect services that will be applied/skipped
        declare -a services_to_apply
        declare -a services_to_skip
        declare -a missing_packages

        # Parse state file and categorize services
        while IFS='|' read -r service backup_state service_type fragment_path applicable; do
            # Skip comments and empty lines
            [[ "$service" =~ ^#.*$ ]] && continue
            [[ -z "$service" ]] && continue

            # Check if service is explicitly in HARDWARE_MAPPING
            # Only apply services that have explicit machine mappings
            # This prevents applying random services from the backup that might not be appropriate
            if [ -z "${hardware_map[$service]}" ]; then
                # Service not in HARDWARE_MAPPING - skip by default (safe option)
                services_to_skip+=("$service (not in hardware mapping - skipped for safety)")
                continue
            fi

            # Check if service applies to current machine
            if ! service_applies_to_machine "$service"; then
                services_to_skip+=("$service (for ${hardware_map[$service]})")
                continue
            fi

            # Check if service file exists
            if [ ! -e "$fragment_path" ]; then
                missing_packages+=("$service (package not installed)")
                continue
            fi

            # Determine what action to take
            local action="$backup_state"

            # For hardware-specific services (marked for only one machine):
            # Always enable them on their applicable machine, don't apply backup state
            # This is because the backup state is from a different machine without that hardware
            local applicable_to="${hardware_map[$service]}"
            if [[ "$applicable_to" != "all" ]] && [[ ! "$applicable_to" =~ "," ]]; then
                # This service is hardware-specific (marked for only one machine)
                # On that machine, always enable it
                action="enabled"
            fi

            # Add to apply list with action
            if [ "$action" = "enabled" ]; then
                services_to_apply+=("$service (enable)")
            else
                services_to_apply+=("$service (disable)")
            fi

        done < <(grep -v "^#" "$systemd_dir/user-services-state.txt" | grep -v "^$")

        # Check for non-applicable services that are currently enabled (cleanup)
        # Use applicable field from state file, default to "all" if not specified
        declare -a services_to_disable
        while IFS='|' read -r service backup_state service_type fragment_path applicable; do
            [[ "$service" =~ ^#.*$ ]] && continue
            [[ -z "$service" ]] && continue

            # Default to "all" if applicable field is empty
            applicable="${applicable:-all}"

            # Check if service is applicable to current machine using backed-up applicability
            if [ "$applicable" = "all" ]; then
                # Applies to all machines
                continue
            elif [[ ",$applicable," == *",$current_hostname,"* ]]; then
                # Applies to current machine
                continue
            fi

            # Service is not applicable to this machine

            # Skip if package not installed
            if [ ! -e "$fragment_path" ]; then
                continue
            fi

            # Check if service is currently enabled on this machine
            local current_state=$(systemctl --user list-unit-files --no-legend "$service" 2>/dev/null | awk '{print $2}')
            if [ "$current_state" = "enabled" ]; then
                services_to_disable+=("$service (not applicable to $current_hostname: applicable to $applicable)")
            fi

        done < <(grep -v "^#" "$systemd_dir/user-services-state.txt" | grep -v "^$")

        # Show summary
        if [ ${#services_to_apply[@]} -gt 0 ] || [ ${#services_to_skip[@]} -gt 0 ] || [ ${#missing_packages[@]} -gt 0 ] || [ ${#services_to_disable[@]} -gt 0 ]; then
            echo "Summary of changes for '$current_hostname':"
            echo ""

            if [ ${#services_to_apply[@]} -gt 0 ]; then
                echo "Will apply:"
                for item in "${services_to_apply[@]}"; do
                    echo "  ✓ $item"
                done
                echo ""
            fi

            if [ ${#services_to_disable[@]} -gt 0 ]; then
                echo "Will disable (cleanup - not applicable to this machine):"
                for item in "${services_to_disable[@]}"; do
                    echo "  ⊘ $item"
                done
                echo ""
            fi

            if [ ${#services_to_skip[@]} -gt 0 ]; then
                echo "Skipping (not in backup):"
                for item in "${services_to_skip[@]}"; do
                    echo "  ○ $item"
                done
                echo ""
            fi

            if [ ${#missing_packages[@]} -gt 0 ]; then
                echo "Skipping (package not installed):"
                for item in "${missing_packages[@]}"; do
                    echo "  ✗ $item"
                done
                echo ""
            fi

            # Single confirmation prompt
            read -p "Apply these user service changes? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                # Apply applicable services
                while IFS='|' read -r service backup_state service_type fragment_path applicable; do
                    [[ "$service" =~ ^#.*$ ]] && continue
                    [[ -z "$service" ]] && continue

                    # Check if service is explicitly in HARDWARE_MAPPING
                    if [ -z "${hardware_map[$service]}" ]; then
                        # Service not in HARDWARE_MAPPING - skip
                        continue
                    fi

                    # Skip if not applicable
                    if ! service_applies_to_machine "$service"; then
                        continue
                    fi

                    # Skip if package not installed
                    if [ ! -e "$fragment_path" ]; then
                        continue
                    fi

                    # Determine what action to take (same logic as display)
                    local action="$backup_state"
                    local applicable_to="${hardware_map[$service]}"
                    if [[ "$applicable_to" != "all" ]] && [[ ! "$applicable_to" =~ "," ]]; then
                        # Hardware-specific service - always enable it
                        action="enabled"
                    fi

                    # Apply the action
                    if [ "$action" = "enabled" ]; then
                        apply_user_service "$service" "enable"
                    else
                        apply_user_service "$service" "disable"
                    fi

                done < <(grep -v "^#" "$systemd_dir/user-services-state.txt" | grep -v "^$")

                # Disable non-applicable services (cleanup)
                while IFS='|' read -r service backup_state service_type fragment_path applicable; do
                    [[ "$service" =~ ^#.*$ ]] && continue
                    [[ -z "$service" ]] && continue

                    # Skip if applicable to this machine
                    if service_applies_to_machine "$service"; then
                        continue
                    fi

                    # Skip if package not installed
                    if [ ! -e "$fragment_path" ]; then
                        continue
                    fi

                    # Check if currently enabled and disable if so
                    local current_state=$(systemctl --user list-unit-files --no-legend "$service" 2>/dev/null | awk '{print $2}')
                    if [ "$current_state" = "enabled" ]; then
                        apply_user_service "$service" "disable"
                    fi

                done < <(grep -v "^#" "$systemd_dir/user-services-state.txt" | grep -v "^$")

                log_info "User services updated"
            else
                log_info "Skipped user service changes"
            fi
        fi

    elif [ -f "$systemd_dir/user-services.txt" ]; then
        # Fallback to old format if new format not available
        log_warn "Using legacy service list format"
        log_info "User services to enable:"
        cat "$systemd_dir/user-services.txt"
        read -p "Enable these user services? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            while read -r service; do
                if [ -n "$service" ]; then
                    systemctl --user enable "$service" 2>/dev/null && \
                        log_info "Enabled user service: $service" || \
                        log_warn "Could not enable user service: $service"

                    systemctl --user start "$service" 2>/dev/null && \
                        log_info "Started user service: $service" || \
                        log_warn "Could not start user service: $service"
                fi
            done < "$systemd_dir/user-services.txt"
        fi
    fi

    echo ""

    # Restore system services from detailed state file
    if [ -f "$systemd_dir/system-services-state.txt" ]; then
        log_info "Analyzing system services for $current_hostname..."
        echo ""

        # Collect services that will be applied/skipped
        declare -a sys_services_to_apply
        declare -a sys_services_to_skip
        declare -a sys_missing_packages

        # Parse state file and categorize services
        while IFS='|' read -r service backup_state service_type fragment_path applicable; do
            # Skip comments and empty lines
            [[ "$service" =~ ^#.*$ ]] && continue
            [[ -z "$service" ]] && continue

            # Check if service is explicitly in HARDWARE_MAPPING
            # Only apply services that have explicit machine mappings
            # This prevents applying random services from the backup that might not be appropriate
            if [ -z "${hardware_map[$service]}" ]; then
                # Service not in HARDWARE_MAPPING - skip by default (safe option)
                sys_services_to_skip+=("$service (not in hardware mapping - skipped for safety)")
                continue
            fi

            # Check if service applies to current machine
            if ! service_applies_to_machine "$service"; then
                sys_services_to_skip+=("$service (for ${hardware_map[$service]})")
                continue
            fi

            # Check if service file exists
            if [ ! -e "$fragment_path" ]; then
                sys_missing_packages+=("$service (package not installed)")
                continue
            fi

            # Determine what action to take
            local action="$backup_state"

            # For hardware-specific services (marked for only one machine):
            # Always enable them on their applicable machine, don't apply backup state
            # This is because the backup state is from a different machine without that hardware
            local applicable_to="${hardware_map[$service]}"
            if [[ "$applicable_to" != "all" ]] && [[ ! "$applicable_to" =~ "," ]]; then
                # This service is hardware-specific (marked for only one machine)
                # On that machine, always enable it
                action="enabled"
            fi

            # Add to apply list with action
            if [ "$action" = "enabled" ]; then
                sys_services_to_apply+=("$service (enable)")
            else
                sys_services_to_apply+=("$service (disable)")
            fi

        done < <(grep -v "^#" "$systemd_dir/system-services-state.txt" | grep -v "^$")

        # Check for non-applicable services that are currently enabled (cleanup)
        # Use applicable field from state file, default to "all" if not specified
        declare -a sys_services_to_disable
        while IFS='|' read -r service backup_state service_type fragment_path applicable; do
            [[ "$service" =~ ^#.*$ ]] && continue
            [[ -z "$service" ]] && continue

            # Default to "all" if applicable field is empty
            applicable="${applicable:-all}"

            # Check if service is applicable to current machine using backed-up applicability
            if [ "$applicable" = "all" ]; then
                # Applies to all machines
                continue
            elif [[ ",$applicable," == *",$current_hostname,"* ]]; then
                # Applies to current machine
                continue
            fi

            # Service is not applicable to this machine

            # Skip if package not installed
            if [ ! -e "$fragment_path" ]; then
                continue
            fi

            # Check if service is currently enabled on this machine
            local current_state=$(systemctl list-unit-files --no-legend "$service" 2>/dev/null | awk '{print $2}')
            if [ "$current_state" = "enabled" ]; then
                sys_services_to_disable+=("$service (not applicable to $current_hostname: applicable to $applicable)")
            fi

        done < <(grep -v "^#" "$systemd_dir/system-services-state.txt" | grep -v "^$")

        # Show summary
        if [ ${#sys_services_to_apply[@]} -gt 0 ] || [ ${#sys_services_to_skip[@]} -gt 0 ] || [ ${#sys_missing_packages[@]} -gt 0 ] || [ ${#sys_services_to_disable[@]} -gt 0 ]; then
            echo "Summary of system service changes for '$current_hostname':"
            echo "(Note: System service operations require sudo)"
            echo ""

            if [ ${#sys_services_to_apply[@]} -gt 0 ]; then
                echo "Will apply:"
                for item in "${sys_services_to_apply[@]}"; do
                    echo "  ✓ $item"
                done
                echo ""
            fi

            if [ ${#sys_services_to_disable[@]} -gt 0 ]; then
                echo "Will disable (cleanup - not applicable to this machine):"
                for item in "${sys_services_to_disable[@]}"; do
                    echo "  ⊘ $item"
                done
                echo ""
            fi

            if [ ${#sys_services_to_skip[@]} -gt 0 ]; then
                echo "Skipping (not in backup):"
                for item in "${sys_services_to_skip[@]}"; do
                    echo "  ○ $item"
                done
                echo ""
            fi

            if [ ${#sys_missing_packages[@]} -gt 0 ]; then
                echo "Skipping (package not installed):"
                for item in "${sys_missing_packages[@]}"; do
                    echo "  ✗ $item"
                done
                echo ""
            fi

            # Single confirmation prompt
            read -p "Apply these system service changes? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                # Apply applicable services
                while IFS='|' read -r service backup_state service_type fragment_path applicable; do
                    [[ "$service" =~ ^#.*$ ]] && continue
                    [[ -z "$service" ]] && continue

                    # Check if service is explicitly in HARDWARE_MAPPING
                    if [ -z "${hardware_map[$service]}" ]; then
                        # Service not in HARDWARE_MAPPING - skip
                        continue
                    fi

                    # Skip if not applicable
                    if ! service_applies_to_machine "$service"; then
                        continue
                    fi

                    # Skip if package not installed
                    if [ ! -e "$fragment_path" ]; then
                        continue
                    fi

                    # Determine what action to take (same logic as display)
                    local action="$backup_state"
                    local applicable_to="${hardware_map[$service]}"
                    if [[ "$applicable_to" != "all" ]] && [[ ! "$applicable_to" =~ "," ]]; then
                        # Hardware-specific service - always enable it
                        action="enabled"
                    fi

                    # Apply the action
                    if [ "$action" = "enabled" ]; then
                        apply_system_service "$service" "enable"
                    else
                        apply_system_service "$service" "disable"
                    fi

                done < <(grep -v "^#" "$systemd_dir/system-services-state.txt" | grep -v "^$")

                # Disable non-applicable services (cleanup)
                while IFS='|' read -r service backup_state service_type fragment_path applicable; do
                    [[ "$service" =~ ^#.*$ ]] && continue
                    [[ -z "$service" ]] && continue

                    # Skip if applicable to this machine
                    if service_applies_to_machine "$service"; then
                        continue
                    fi

                    # Skip if package not installed
                    if [ ! -e "$fragment_path" ]; then
                        continue
                    fi

                    # Check if currently enabled and disable if so
                    local current_state=$(systemctl list-unit-files --no-legend "$service" 2>/dev/null | awk '{print $2}')
                    if [ "$current_state" = "enabled" ]; then
                        apply_system_service "$service" "disable"
                    fi

                done < <(grep -v "^#" "$systemd_dir/system-services-state.txt" | grep -v "^$")

                log_info "System services updated"
            else
                log_info "Skipped system service changes"
            fi
        fi

    elif [ -f "$systemd_dir/system-services.txt" ]; then
        # Fallback to old format
        log_warn "Using legacy system service list format"
        log_info "System services to enable:"
        cat "$systemd_dir/system-services.txt"
        read -p "Enable these system services? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            while read -r service; do
                if [ -n "$service" ]; then
                    sudo systemctl enable "$service" 2>/dev/null && \
                        log_info "Enabled system service: $service" || \
                        log_warn "Could not enable system service: $service"

                    sudo systemctl start "$service" 2>/dev/null && \
                        log_info "Started system service: $service" || \
                        log_warn "Could not start system service: $service"
                fi
            done < "$systemd_dir/system-services.txt"
        fi
    fi
}

# Restore user scripts from ~/.local/bin
restore_local_bin() {
    log_section "Restoring User Scripts from ~/.local/bin"

    local local_bin_backup="$BACKUP_DIR/local-bin"

    if [ ! -d "$local_bin_backup" ]; then
        log_warn "No user scripts found in backup"
        return
    fi

    if [ ! "$(ls -A "$local_bin_backup")" ]; then
        log_warn "local-bin directory is empty in backup"
        return
    fi

    mkdir -p "$HOME/.local/bin"
    cp -r "$local_bin_backup"/* "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin"/* 2>/dev/null || true
    log_info "Restored user scripts to: $HOME/.local/bin"
}

# Install AUR helper if not present
install_aur_helper() {
    local aur_helper="yay"

    if command -v yay &>/dev/null || command -v paru &>/dev/null; then
        log_info "AUR helper already installed"
        return
    fi

    log_info "Installing $aur_helper..."

    # Need base-devel for building
    sudo pacman -S --needed --noconfirm base-devel

    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    git clone "https://aur.archlinux.org/${aur_helper}.git"
    cd "$aur_helper"
    makepkg -si --noconfirm
    cd "$BACKUP_DIR"
    rm -rf "$temp_dir"

    log_info "$aur_helper installed"
}

# Interactive menu
show_menu() {
    log_section "Arch Linux Configuration Restore"

    echo "What would you like to restore?"
    echo "1) Full bootstrap (packages -> configs -> services) [recommended for fresh install]"
    echo "2) Everything (configs -> packages -> services)"
    echo "3) Home directory configs and scripts only"
    echo "4) System configs only (/etc)"
    echo "5) Packages only"
    echo "6) Systemd services only"
    echo "7) Exit"
    echo ""
    read -p "Enter choice [1-7]: " choice

    case $choice in
        1)
            # Bootstrap order: packages first, then configs
            log_section "Full Bootstrap"
            install_aur_helper
            restore_packages
            restore_home_configs
            setup_hyprland_monitors
            restore_local_bin
            restore_system_configs
            restore_systemd
            ;;
        2)
            restore_home_configs
            setup_hyprland_monitors
            restore_local_bin
            restore_system_configs
            restore_packages
            restore_systemd
            ;;
        3)
            restore_home_configs
            setup_hyprland_monitors
            restore_local_bin
            ;;
        4)
            restore_system_configs
            ;;
        5)
            restore_packages
            ;;
        6)
            restore_systemd
            ;;
        7)
            log_info "Exiting"
            exit 0
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
}

# Main execution
main() {
    log_info "Arch Linux Configuration Restore"
    log_info "Backup directory: $BACKUP_DIR"

    check_backup
    show_menu

    log_info "Restore completed!"
    log_warn "You may need to log out and back in for some changes to take effect"
}

main "$@"
