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

# Restore systemd services with individual prompts
restore_systemd() {
    log_section "Restoring Systemd Services"

    local systemd_dir="$BACKUP_DIR/systemd"

    if [ ! -d "$systemd_dir" ]; then
        log_warn "No systemd service lists found in backup"
        return
    fi

    # Helper function to prompt for each user service
    prompt_user_service() {
        local service=$1
        local backup_state=$2
        local service_type=$3
        local current_state=$4
        local current_exists=$5

        echo ""
        echo "Service: $service"
        echo "  Type: $service_type"
        echo "  Backup state: $backup_state"
        echo "  Current state: $current_state"

        # Check if service file exists
        if [ "$current_exists" = "false" ]; then
            log_warn "  Service file not found"
            read -p "  Skip this service? (Y/n): " skip
            if [[ ! "$skip" =~ ^[Nn]$ ]]; then
                return
            fi
        fi

        echo "  Actions: [e]nable, [d]isable, [s]kip"
        read -p "  Choose action (default: skip): " action

        case "$action" in
            e|E|enable)
                systemctl --user enable "$service" 2>/dev/null && \
                    log_info "  Enabled: $service" || \
                    log_warn "  Failed to enable: $service"

                read -p "  Start service now? (y/N): " start_now
                if [[ "$start_now" =~ ^[Yy]$ ]]; then
                    systemctl --user start "$service" 2>/dev/null && \
                        log_info "  Started: $service" || \
                        log_warn "  Failed to start: $service"
                fi
                ;;
            d|D|disable)
                systemctl --user disable "$service" 2>/dev/null && \
                    log_info "  Disabled: $service" || \
                    log_warn "  Failed to disable: $service"

                read -p "  Stop service now? (y/N): " stop_now
                if [[ "$stop_now" =~ ^[Yy]$ ]]; then
                    systemctl --user stop "$service" 2>/dev/null && \
                        log_info "  Stopped: $service" || \
                        log_warn "  Failed to stop: $service"
                fi
                ;;
            s|S|skip|"")
                log_info "  Skipped: $service"
                ;;
            *)
                log_warn "  Invalid action, skipping: $service"
                ;;
        esac
    }

    # Helper function to prompt for each system service
    prompt_system_service() {
        local service=$1
        local backup_state=$2
        local service_type=$3
        local current_state=$4
        local current_exists=$5

        echo ""
        echo "Service: $service"
        echo "  Type: $service_type"
        echo "  Backup state: $backup_state"
        echo "  Current state: $current_state"

        if [ "$current_exists" = "false" ]; then
            log_warn "  Service file not found"
            read -p "  Skip this service? (Y/n): " skip
            if [[ ! "$skip" =~ ^[Nn]$ ]]; then
                return
            fi
        fi

        echo "  Actions: [e]nable, [d]isable, [s]kip"
        read -p "  Choose action (default: skip): " action

        case "$action" in
            e|E|enable)
                sudo systemctl enable "$service" 2>/dev/null && \
                    log_info "  Enabled: $service" || \
                    log_warn "  Failed to enable: $service"

                read -p "  Start service now? (y/N): " start_now
                if [[ "$start_now" =~ ^[Yy]$ ]]; then
                    sudo systemctl start "$service" 2>/dev/null && \
                        log_info "  Started: $service" || \
                        log_warn "  Failed to start: $service"
                fi
                ;;
            d|D|disable)
                sudo systemctl disable "$service" 2>/dev/null && \
                    log_info "  Disabled: $service" || \
                    log_warn "  Failed to disable: $service"

                read -p "  Stop service now? (y/N): " stop_now
                if [[ "$stop_now" =~ ^[Yy]$ ]]; then
                    sudo systemctl stop "$service" 2>/dev/null && \
                        log_info "  Stopped: $service" || \
                        log_warn "  Failed to stop: $service"
                fi
                ;;
            s|S|skip|"")
                log_info "  Skipped: $service"
                ;;
            *)
                log_warn "  Invalid action, skipping: $service"
                ;;
        esac
    }

    # Restore user services from detailed state file
    if [ -f "$systemd_dir/user-services-state.txt" ]; then
        log_info "Restoring user services..."
        log_info "You will be prompted for each service individually."
        echo ""

        # Count services for progress
        local total_services=$(grep -v "^#" "$systemd_dir/user-services-state.txt" | grep -v "^$" | wc -l)
        local current_service=0

        # Read state file
        while IFS='|' read -r service backup_state service_type fragment_path; do
            # Skip comments and empty lines
            [[ "$service" =~ ^#.*$ ]] && continue
            [[ -z "$service" ]] && continue

            current_service=$((current_service + 1))

            log_info "[$current_service/$total_services]"

            # Get current state of service on this machine
            local current_state=$(systemctl --user list-unit-files --no-legend "$service" 2>/dev/null | awk '{print $2}')
            local current_exists="true"

            if [ -z "$current_state" ]; then
                current_state="not found"
                current_exists="false"
            fi

            # Prompt user for action
            prompt_user_service "$service" "$backup_state" "$service_type" "$current_state" "$current_exists"

        done < <(grep -v "^#" "$systemd_dir/user-services-state.txt" | grep -v "^$")

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
        log_info "Restoring system services..."
        log_info "Note: System service operations require sudo"
        read -p "Do you want to restore system services? (y/N): " proceed

        if [[ ! "$proceed" =~ ^[Yy]$ ]]; then
            log_info "Skipping system services"
            return
        fi

        log_info "You will be prompted for each service individually."
        echo ""

        local total_services=$(grep -v "^#" "$systemd_dir/system-services-state.txt" | grep -v "^$" | wc -l)
        local current_service=0

        while IFS='|' read -r service backup_state service_type fragment_path; do
            [[ "$service" =~ ^#.*$ ]] && continue
            [[ -z "$service" ]] && continue

            current_service=$((current_service + 1))
            log_info "[$current_service/$total_services]"

            local current_state=$(systemctl list-unit-files --no-legend "$service" 2>/dev/null | awk '{print $2}')
            local current_exists="true"

            if [ -z "$current_state" ]; then
                current_state="not found"
                current_exists="false"
            fi

            # Prompt user for action
            prompt_system_service "$service" "$backup_state" "$service_type" "$current_state" "$current_exists"

        done < <(grep -v "^#" "$systemd_dir/system-services-state.txt" | grep -v "^$")

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
            restore_local_bin
            restore_system_configs
            restore_systemd
            ;;
        2)
            restore_home_configs
            restore_local_bin
            restore_system_configs
            restore_packages
            restore_systemd
            ;;
        3)
            restore_home_configs
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
