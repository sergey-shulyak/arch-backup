#!/bin/bash
#
# Arch Linux Bootstrap Script
# Run this on a fresh Arch installation to restore your system
#
# Usage (from fresh Arch install):
#   curl -sL <raw-github-url>/bootstrap.sh | bash -s <repo-url>
#
# Or if you have the repo URL set:
#   curl -sL <raw-github-url>/bootstrap.sh | bash
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }

# Configuration
BACKUP_DIR="$HOME/Documents/arch-backup"
REPO_URL="${1:-}"

# Default AUR helper to install
AUR_HELPER="yay"

log_section "Arch Linux Bootstrap"

# Step 0: Create standard home directory structure using xdg-user-dirs
create_home_dirs() {
    log_section "Creating Home Directory Structure"

    # Install xdg-user-dirs if not present
    if ! command -v xdg-user-dirs-update &>/dev/null; then
        log_info "Installing xdg-user-dirs..."
        sudo pacman -S --needed --noconfirm xdg-user-dirs
    fi

    # Create XDG directories
    xdg-user-dirs-update
    log_info "Created XDG user directories"

    # Create additional custom directories
    mkdir -p "$HOME/Developer"
    log_info "Created: ~/Developer"
}

create_home_dirs

# Step 1: Get repository URL if not provided
if [ -z "$REPO_URL" ]; then
    read -p "Enter your arch-backup git repository URL: " REPO_URL
    if [ -z "$REPO_URL" ]; then
        log_error "Repository URL is required"
        exit 1
    fi
fi

log_info "Repository: $REPO_URL"

# Step 2: Install essential packages
log_section "Installing Essential Packages"

log_info "Updating package database..."
sudo pacman -Sy

log_info "Installing git and base-devel..."
sudo pacman -S --needed --noconfirm git base-devel

# Step 3: Clone the backup repository
log_section "Cloning Backup Repository"

mkdir -p "$HOME/Documents"
if [ -d "$BACKUP_DIR" ]; then
    log_warn "Backup directory already exists, pulling latest..."
    cd "$BACKUP_DIR"
    git pull
else
    git clone "$REPO_URL" "$BACKUP_DIR"
fi

cd "$BACKUP_DIR"
log_info "Repository cloned to $BACKUP_DIR"

# Step 4: Install AUR helper
log_section "Installing AUR Helper ($AUR_HELPER)"

if command -v "$AUR_HELPER" &>/dev/null; then
    log_info "$AUR_HELPER is already installed"
else
    log_info "Building $AUR_HELPER from AUR..."

    temp_dir=$(mktemp -d)
    cd "$temp_dir"

    git clone "https://aur.archlinux.org/${AUR_HELPER}.git"
    cd "$AUR_HELPER"
    makepkg -si --noconfirm

    cd "$BACKUP_DIR"
    rm -rf "$temp_dir"

    log_info "$AUR_HELPER installed successfully"
fi

# Step 5: Install packages from backup
log_section "Installing Packages"

PKG_DIR="$BACKUP_DIR/packages"

if [ -f "$PKG_DIR/pacman-native.txt" ]; then
    log_info "Installing native packages from official repositories..."

    # Read packages, filter comments and empty lines
    packages=$(grep -v '^#' "$PKG_DIR/pacman-native.txt" 2>/dev/null | grep -v '^$' | tr '\n' ' ')

    if [ -n "$packages" ]; then
        # Install in batches to handle any unavailable packages gracefully
        sudo pacman -S --needed --noconfirm $packages || {
            log_warn "Some packages failed, trying one by one..."
            for pkg in $packages; do
                sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null || \
                    log_warn "Could not install: $pkg"
            done
        }
    fi
    log_info "Native packages installed"
else
    log_warn "No native package list found"
fi

if [ -f "$PKG_DIR/pacman-aur.txt" ]; then
    log_info "Installing AUR packages..."

    packages=$(grep -v '^#' "$PKG_DIR/pacman-aur.txt" 2>/dev/null | grep -v '^$' | tr '\n' ' ')

    if [ -n "$packages" ]; then
        $AUR_HELPER -S --needed --noconfirm $packages || {
            log_warn "Some AUR packages failed, trying one by one..."
            for pkg in $packages; do
                $AUR_HELPER -S --needed --noconfirm "$pkg" 2>/dev/null || \
                    log_warn "Could not install AUR package: $pkg"
            done
        }
    fi
    log_info "AUR packages installed"
else
    log_warn "No AUR package list found"
fi

# Step 6: Restore configuration files
log_section "Restoring Configuration Files"

CONFIG_DIR="$BACKUP_DIR/configs"

# Restore home directory configs
if [ -d "$CONFIG_DIR/home" ]; then
    log_info "Restoring home directory configs..."

    # Use rsync for efficient copying
    if command -v rsync &>/dev/null; then
        rsync -av "$CONFIG_DIR/home/" "$HOME/"
    else
        cp -rv "$CONFIG_DIR/home/." "$HOME/"
    fi

    log_info "Home configs restored"
else
    log_warn "No home configs found in backup"
fi

# Restore system configs
if [ -d "$CONFIG_DIR/etc" ]; then
    log_info "Restoring system configs..."
    read -p "Restore system configs from /etc? (y/N): " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        cd "$CONFIG_DIR/etc"
        find . -type f | while read -r file; do
            rel_path="${file#./}"
            src="$CONFIG_DIR/etc/$rel_path"
            dest="/etc/$rel_path"

            sudo mkdir -p "$(dirname "$dest")"
            sudo cp -v "$src" "$dest"
        done
        log_info "System configs restored"
    else
        log_info "Skipping system configs"
    fi
fi

# Step 7: Enable systemd services
log_section "Enabling Systemd Services"

SYSTEMD_DIR="$BACKUP_DIR/systemd"

# User services
if [ -f "$SYSTEMD_DIR/user-services.txt" ]; then
    log_info "Enabling user services..."
    while read -r service; do
        if [ -n "$service" ] && [ "${service:0:1}" != "#" ]; then
            systemctl --user enable "$service" 2>/dev/null && \
                log_info "Enabled: $service" || \
                log_warn "Could not enable: $service"
        fi
    done < "$SYSTEMD_DIR/user-services.txt"
fi

# System services
if [ -f "$SYSTEMD_DIR/system-services.txt" ]; then
    log_info "Enabling system services..."
    read -p "Enable system services? (y/N): " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        while read -r service; do
            if [ -n "$service" ] && [ "${service:0:1}" != "#" ]; then
                sudo systemctl enable "$service" 2>/dev/null && \
                    log_info "Enabled: $service" || \
                    log_warn "Could not enable: $service"
            fi
        done < "$SYSTEMD_DIR/system-services.txt"
    fi
fi

# Step 8: Set up fish shell
log_section "Setting Up Fish Shell"

if ! command -v fish &>/dev/null; then
    log_info "Installing fish shell..."
    sudo pacman -S --needed --noconfirm fish
fi

# Set fish as default shell
FISH_PATH=$(which fish)
if [ -n "$FISH_PATH" ]; then
    # Add fish to /etc/shells if not present
    if ! grep -q "$FISH_PATH" /etc/shells; then
        log_info "Adding fish to /etc/shells..."
        echo "$FISH_PATH" | sudo tee -a /etc/shells > /dev/null
    fi

    # Change default shell
    CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
    if [ "$CURRENT_SHELL" != "$FISH_PATH" ]; then
        log_info "Setting fish as default shell..."
        chsh -s "$FISH_PATH"
        log_info "Default shell changed to fish"
    else
        log_info "Fish is already the default shell"
    fi
else
    log_warn "Could not find fish executable"
fi

# Step 9: Install the backup service
log_section "Installing Backup Service"

read -p "Install automatic backup service (runs before shutdown)? (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    if [ -f "$BACKUP_DIR/install-service.sh" ]; then
        sudo "$BACKUP_DIR/install-service.sh"
    else
        log_warn "install-service.sh not found"
    fi
fi

# Done!
log_section "Bootstrap Complete!"

echo ""
log_info "Your Arch Linux system has been restored!"
echo ""
log_warn "Next steps:"
echo "  1. Review any warnings above for packages that couldn't be installed"
echo "  2. Log out and log back in for fish shell to take effect"
echo "  3. If using a display manager, you may need to reboot"
echo ""
echo "Useful commands:"
echo "  - Run backup manually:  ~/Documents/arch-backup/backup.sh"
echo "  - Restore specific items: ~/Documents/arch-backup/restore.sh"
echo ""
