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
    if [ -f "$pkg_dir/pacman.txt" ]; then
        log_info "Installing native packages from official repositories..."
        read -p "Install native packages? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            # Filter out GPU drivers and already installed packages
            local to_install=$(grep -vE "$gpu_pattern" "$pkg_dir/pacman.txt" | comm -23 <(sort) <(pacman -Qqn | sort) | tr '\n' ' ')
            if [ -n "$to_install" ]; then
                sudo pacman -S --needed $to_install
            else
                log_info "All native packages already installed"
            fi
        fi
    fi

    # Restore AUR packages
    if [ -f "$pkg_dir/aur.txt" ]; then
        log_info "Installing AUR packages..."
        read -p "Install AUR packages? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            if [ -z "$aur_helper" ]; then
                log_warn "No AUR helper (yay/paru) found"
                log_info "Install yay or paru first, then run this again"
                log_info "AUR packages to install are listed in: $pkg_dir/aur.txt"
            else
                # Filter out GPU drivers and already installed packages
                local to_install=$(grep -vE "$gpu_pattern" "$pkg_dir/aur.txt" | comm -23 <(sort) <(pacman -Qqm | sort) | tr '\n' ' ')
                if [ -n "$to_install" ]; then
                    $aur_helper -S --needed $to_install
                else
                    log_info "All AUR packages already installed"
                fi
            fi
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

# Generate theme using hyprstyle submodule
generate_theme() {
    log_section "Generating Theme with Hyprstyle"

    local hyprstyle_dir="$BACKUP_DIR/hyprstyle"

    # Ensure submodule is initialized
    cd "$BACKUP_DIR"
    git submodule update --init --recursive

    if [ -f "$hyprstyle_dir/hyprstyle.sh" ]; then
        log_info "Running hyprstyle theme generator..."
        cd "$hyprstyle_dir"
        chmod +x hyprstyle.sh
        ./hyprstyle.sh || log_warn "Theme generation had issues - check hyprstyle output"
        log_info "Theme generated successfully"
    else
        log_error "Hyprstyle not found - submodule may not be initialized"
        log_info "Try: git submodule update --init --recursive"
    fi

    cd "$BACKUP_DIR"
}

# Setup Hyprland window sizes based on current screen resolution
setup_hyprland_sizes() {
    log_section "Setting Up Hyprland Window Sizes"

    local setup_script="$HOME/.config/hypr/scripts/setup-screen-size.sh"

    if [ ! -f "$setup_script" ]; then
        log_warn "Hyprland setup script not found: $setup_script"
        log_info "Make sure to restore home configs first"
        return
    fi

    log_info "Running screen size auto-detection..."
    chmod +x "$setup_script"
    "$setup_script" || log_warn "Screen size setup had issues"
    log_info "Hyprland window sizes configured"
}

# Enable and start systemd services from services.conf
enable_services() {
    log_section "Enabling Systemd Services"

    local services_file="$BACKUP_DIR/services.conf"
    local current_hostname=$(hostname 2>/dev/null || echo "unknown")

    if [ ! -f "$services_file" ]; then
        log_warn "Services configuration file not found: $services_file"
        return
    fi

    # Parse and process each service line
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue

        # Parse service definition: service_name@type[@machine_filter]
        local service_name=$(echo "$line" | awk '{print $1}' | cut -d@ -f1)
        local service_type=$(echo "$line" | awk '{print $1}' | cut -d@ -f2)
        local service_filter=$(echo "$line" | awk '{print $1}' | cut -d@ -f3)

        # Check if service should run on this machine
        if [ -n "$service_filter" ] && [ "$service_filter" != "$current_hostname" ]; then
            log_warn "Skipping $service_name (not for this machine)"
            continue
        fi

        # Check if service exists
        if [ "$service_type" = "system" ]; then
            systemctl list-unit-files "$service_name" &>/dev/null || {
                log_warn "Service not found: $service_name (will be installed with packages)"
                continue
            }
            log_info "Enabling system service: $service_name"
            sudo systemctl enable --now "$service_name" || log_warn "Failed to enable $service_name"
        elif [ "$service_type" = "user" ]; then
            systemctl --user list-unit-files "$service_name" &>/dev/null || {
                log_warn "User service not found: $service_name (will be installed with packages)"
                continue
            }
            log_info "Enabling user service: $service_name"
            systemctl --user enable --now "$service_name" || log_warn "Failed to enable $service_name"
        fi
    done < "$services_file"

    log_info "Service enablement complete"
}

# Interactive menu
show_menu() {
    log_section "Arch Linux Configuration Restore"

    echo "What would you like to restore?"
    echo "1) Full bootstrap (packages -> configs -> services -> theme) [recommended for fresh install]"
    echo "2) Everything (configs -> packages -> services -> theme)"
    echo "3) Home directory configs and scripts only"
    echo "4) System configs only (/etc)"
    echo "5) Packages only"
    echo "6) Systemd services only (enable and start)"
    echo "7) Generate theme only (run hyprstyle)"
    echo "8) Setup Hyprland window sizes only"
    echo "9) Exit"
    echo ""
    read -p "Enter choice [1-9]: " choice

    case $choice in
        1)
            # Bootstrap order: packages first, then configs, then services, then theme
            log_section "Full Bootstrap"
            install_aur_helper
            restore_packages
            restore_home_configs
            restore_local_bin
            setup_hyprland_sizes
            restore_system_configs
            enable_services
            generate_theme
            ;;
        2)
            restore_home_configs
            restore_local_bin
            setup_hyprland_sizes
            restore_system_configs
            restore_packages
            enable_services
            generate_theme
            ;;
        3)
            restore_home_configs
            restore_local_bin
            setup_hyprland_sizes
            ;;
        4)
            restore_system_configs
            ;;
        5)
            restore_packages
            ;;
        6)
            enable_services
            ;;
        7)
            generate_theme
            ;;
        8)
            setup_hyprland_sizes
            ;;
        9)
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
