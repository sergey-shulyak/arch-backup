#!/bin/bash
#
# Arch Linux Configuration Backup Script
# Backs up system configuration files and commits to git repository
#

set -e

# Support running as different user (for systemd service)
if [ -n "$BACKUP_USER" ]; then
    USER_HOME=$(getent passwd "$BACKUP_USER" | cut -d: -f6)
else
    USER_HOME="$HOME"
fi

BACKUP_DIR="$USER_HOME/Documents/arch-backup"
CONFIG_DIR="$BACKUP_DIR/configs"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Non-interactive mode (for systemd service)
NON_INTERACTIVE="${NON_INTERACTIVE:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Initialize git repository if not present
init_git_repo() {
    cd "$BACKUP_DIR"

    if [ ! -d ".git" ]; then
        if [ "$NON_INTERACTIVE" = "true" ]; then
            log_warn "No git repository found and running in non-interactive mode"
            log_warn "Please run backup.sh manually first to set up the repository"
            exit 1
        fi

        log_warn "No git repository found in $BACKUP_DIR"
        read -p "Enter git repository URL to clone (or press Enter to initialize new repo): " repo_url

        if [ -n "$repo_url" ]; then
            # Save current files temporarily
            temp_dir=$(mktemp -d)
            cp -r "$BACKUP_DIR"/* "$temp_dir/" 2>/dev/null || true

            # Clone the repository
            cd "$USER_HOME/Documents"
            rm -rf "$BACKUP_DIR"
            git clone "$repo_url" arch-backup
            cd "$BACKUP_DIR"

            # Restore scripts if they don't exist in cloned repo
            if [ ! -f "backup.sh" ] && [ -f "$temp_dir/backup.sh" ]; then
                cp "$temp_dir/backup.sh" .
            fi
            if [ ! -f "restore.sh" ] && [ -f "$temp_dir/restore.sh" ]; then
                cp "$temp_dir/restore.sh" .
            fi

            rm -rf "$temp_dir"
            log_info "Repository cloned successfully"
        else
            git init
            log_info "Initialized new git repository"
            read -p "Enter remote repository URL (optional, press Enter to skip): " remote_url
            if [ -n "$remote_url" ]; then
                git remote add origin "$remote_url"
                log_info "Added remote origin: $remote_url"
            fi
        fi
    fi
}

# Create directory structure
create_dirs() {
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$BACKUP_DIR/packages"
    mkdir -p "$BACKUP_DIR/systemd"
    mkdir -p "$BACKUP_DIR/scripts"
    mkdir -p "$BACKUP_DIR/local-bin"
}

# Backup function - copies file/directory if it exists
backup_item() {
    local src="$1"
    local dest="$2"

    if [ -e "$src" ]; then
        mkdir -p "$(dirname "$dest")"
        cp -r "$src" "$dest"
        log_info "Backed up: $src"
    else
        log_warn "Not found, skipping: $src"
    fi
}

# Directories and patterns to exclude from backup (sensitive/large/cache data)
EXCLUDE_PATTERNS=(
    # Sensitive data
    ".gnupg"
    ".ssh/id_*"
    ".ssh/*.pem"
    ".ssh/known_hosts"
    ".ssh/authorized_keys"
    ".pki"
    ".cert"
    ".password-store"

    # Credentials and secrets
    "**/credentials*"
    "**/secrets*"
    "**/.env"
    "**/token*"
    "**/auth*"
    "**/*key*.json"
    "**/*secret*"

    # Cache and temporary files
    ".cache"
    ".local/share/Trash"
    "**/Cache"
    "**/cache"
    "**/CacheStorage"
    "**/*.log"
    "**/logs"
    "**/.npm"
    "**/.cargo/registry"
    "**/.rustup"
    "**/node_modules"
    "**/__pycache__"
    "**/*.pyc"
    "**/venv"
    "**/.venv"

    # Browser data (large and contains sensitive info)
    ".mozilla"
    "google-chrome"
    "google-chrome-beta"
    "google-chrome-unstable"
    "chromium"
    "BraveSoftware"
    "firefox"
    "vivaldi"
    "Microsoft/Edge"

    # Password managers and sensitive apps
    "1Password"
    "Bitwarden"
    "KeePassXC"

    # Application data (large/regenerable)
    ".local/share/Steam"
    ".steam"
    ".wine"
    ".local/share/lutris"
    ".var"
    ".local/share/flatpak"
    "snap"

    # IDE/Editor data and extensions
    ".vscode/extensions"
    ".config/Code/CachedData"
    ".config/Code/CachedExtensions"
    ".config/Code/User/workspaceStorage"
    ".config/Code/logs"
    ".local/share/JetBrains"

    # History files (can contain sensitive commands)
    ".bash_history"
    ".zsh_history"
    ".histfile"
    ".python_history"
    ".lesshst"
    ".wget-hsts"
)

# Build rsync exclude arguments
build_exclude_args() {
    local args=""
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        args="$args --exclude=$pattern"
    done
    echo "$args"
}

# Backup entire .config directory
backup_config_dir() {
    log_info "Backing up ~/.config directory..."

    local exclude_args=$(build_exclude_args)

    mkdir -p "$CONFIG_DIR/home/.config"

    # Use rsync with exclusions
    eval rsync -a --delete $exclude_args "$USER_HOME/.config/" "$CONFIG_DIR/home/.config/"

    log_info "Backed up ~/.config"
}

# Backup home directory dotfiles
backup_home_dotfiles() {
    log_info "Backing up home directory dotfiles..."

    # List of dotfiles to backup (files only, not directories)
    local dotfiles=(
        ".bashrc"
        ".bash_profile"
        ".zshrc"
        ".zprofile"
        ".profile"
        ".gitconfig"
        ".gitignore_global"
        ".vimrc"
        ".tmux.conf"
        ".xinitrc"
        ".Xresources"
        ".xprofile"
        ".gtkrc-2.0"
        ".inputrc"
        ".editorconfig"
    )

    for file in "${dotfiles[@]}"; do
        if [ -f "$USER_HOME/$file" ]; then
            backup_item "$USER_HOME/$file" "$CONFIG_DIR/home/$file"
        fi
    done

    # SSH config only (not keys)
    if [ -f "$USER_HOME/.ssh/config" ]; then
        mkdir -p "$CONFIG_DIR/home/.ssh"
        cp "$USER_HOME/.ssh/config" "$CONFIG_DIR/home/.ssh/config"
        log_info "Backed up: $USER_HOME/.ssh/config"
    fi

    # Fish shell data (functions, completions - but not history)
    if [ -d "$USER_HOME/.local/share/fish" ]; then
        mkdir -p "$CONFIG_DIR/home/.local/share"
        rsync -a --exclude='fish_history' "$USER_HOME/.local/share/fish/" "$CONFIG_DIR/home/.local/share/fish/"
        log_info "Backed up: $USER_HOME/.local/share/fish"
    fi
}

# Backup user scripts in ~/.local/bin
backup_local_bin() {
    log_info "Backing up ~/.local/bin directory..."

    if [ -d "$USER_HOME/.local/bin" ]; then
        mkdir -p "$BACKUP_DIR/local-bin"
        cp -r "$USER_HOME/.local/bin"/* "$BACKUP_DIR/local-bin/" 2>/dev/null || true
        log_info "Backed up: $USER_HOME/.local/bin"
    else
        log_warn "Not found, skipping: $USER_HOME/.local/bin"
    fi
}

# Backup configuration files
backup_configs() {
    log_info "Backing up configuration files..."

    backup_config_dir
    backup_home_dotfiles

    # System configs (device-agnostic only)
    log_info "Backing up system configs..."
    if [ -r "/etc/pacman.conf" ]; then
        backup_item "/etc/pacman.conf" "$CONFIG_DIR/etc/pacman.conf"
    fi
    if [ -r "/etc/makepkg.conf" ]; then
        backup_item "/etc/makepkg.conf" "$CONFIG_DIR/etc/makepkg.conf"
    fi
    # Skipped device-specific configs:
    # - /etc/fstab (disk/partition specific)
    # - /etc/hostname (machine specific)
    # - /etc/X11/xorg.conf.d (hardware specific)
    if [ -r "/etc/locale.conf" ]; then
        backup_item "/etc/locale.conf" "$CONFIG_DIR/etc/locale.conf"
    fi
    if [ -r "/etc/vconsole.conf" ]; then
        backup_item "/etc/vconsole.conf" "$CONFIG_DIR/etc/vconsole.conf"
    fi
    if [ -d "/etc/environment.d" ]; then
        backup_item "/etc/environment.d" "$CONFIG_DIR/etc/environment.d"
    fi
    if [ -r "/etc/tlp.conf" ]; then
        backup_item "/etc/tlp.conf" "$CONFIG_DIR/etc/tlp.conf"
    fi
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

# Backup package lists
backup_packages() {
    log_info "Backing up package lists..."

    local gpu_pattern=$(build_gpu_driver_pattern)

    # Explicitly installed packages (excluding GPU drivers)
    pacman -Qqe | grep -vE "$gpu_pattern" > "$BACKUP_DIR/packages/pacman-explicit.txt"
    log_info "Saved explicit packages list (GPU drivers excluded)"

    # Explicitly installed native packages (from official repos, excluding GPU drivers)
    pacman -Qqen | grep -vE "$gpu_pattern" > "$BACKUP_DIR/packages/pacman-native.txt"
    log_info "Saved native packages list (GPU drivers excluded)"

    # AUR packages (foreign, excluding GPU drivers)
    pacman -Qqem | grep -vE "$gpu_pattern" > "$BACKUP_DIR/packages/pacman-aur.txt"
    log_info "Saved AUR packages list (GPU drivers excluded)"

    # All packages with versions (excluding GPU drivers)
    pacman -Q | grep -vE "$gpu_pattern" > "$BACKUP_DIR/packages/pacman-all-versions.txt"
    log_info "Saved all packages with versions (GPU drivers excluded)"
}

# Backup systemd services with detailed state information
backup_systemd() {
    log_info "Backing up systemd service state..."

    local systemd_dir="$BACKUP_DIR/systemd"
    local hardware_map="$systemd_dir/HARDWARE_MAPPING.conf"

    # Load hardware mapping into associative array
    declare -A hardware_map_data
    if [ -f "$hardware_map" ]; then
        while IFS='|' read -r service machines desc; do
            # Skip comments and empty lines
            [[ "$service" =~ ^#.*$ ]] && continue
            [[ -z "$service" ]] && continue
            hardware_map_data["$service"]="$machines"
        done < "$hardware_map"
    fi

    # Helper function to get applicability for a service
    get_applicability() {
        local service=$1
        local machines="${hardware_map_data[$service]:-all}"
        echo "$machines"
    }

    # Backup user services with state
    log_info "Collecting user service states..."
    {
        echo "# Format: service_name|state|type|fragment_path|applicable_machines"
        echo "# state: enabled, disabled, masked, indirect"
        echo "# type: custom (in ~/.config/systemd/user) or package (in /usr/lib/systemd/user)"
        echo "# applicable_machines: all, rig, thinkpad, or comma-separated machine names"
        echo ""

        # Get all services and sockets (excluding transient, generated, static, alias)
        systemctl --user list-unit-files --type=service,socket --no-legend | \
        while read -r unit state preset; do
            # Skip unwanted states
            case "$state" in
                static|generated|transient|alias)
                    continue
                    ;;
            esac

            # Get fragment path to determine if custom or package
            # Suppress errors for template units that can't be queried directly
            local fragment_path=$(systemctl --user show -p FragmentPath "$unit" 2>/dev/null | cut -d= -f2)

            # Determine type based on path
            local type="package"
            if [[ "$fragment_path" == "$USER_HOME/.config/systemd/user/"* ]]; then
                type="custom"
            fi

            # Get applicability
            local applicability=$(get_applicability "$unit")

            # Output: service|state|type|path|applicability
            echo "$unit|$state|$type|$fragment_path|$applicability"
        done
    } > "$systemd_dir/user-services-state.txt"

    log_info "Saved user systemd service states"

    # Keep old format for backward compatibility (enabled services only)
    systemctl --user list-unit-files --state=enabled --no-legend | \
        awk '{print $1}' > "$systemd_dir/user-services.txt"

    # Backup system services with state
    log_info "Collecting system service states..."
    {
        echo "# Format: service_name|state|type|fragment_path|applicable_machines"
        echo "# state: enabled, disabled, masked, indirect"
        echo "# type: always 'package' for system services"
        echo "# applicable_machines: all, rig, thinkpad, or comma-separated machine names"
        echo ""

        systemctl list-unit-files --type=service,socket --no-legend | \
        while read -r unit state preset; do
            case "$state" in
                static|generated|transient|alias)
                    continue
                    ;;
            esac

            # Suppress errors for template units that can't be queried directly
            local fragment_path=$(systemctl show -p FragmentPath "$unit" 2>/dev/null | cut -d= -f2)

            # Get applicability
            local applicability=$(get_applicability "$unit")

            echo "$unit|$state|package|$fragment_path|$applicability"
        done
    } > "$systemd_dir/system-services-state.txt"

    log_info "Saved system systemd service states"

    # Keep old format for backward compatibility
    systemctl list-unit-files --state=enabled --no-legend | \
        awk '{print $1}' > "$systemd_dir/system-services.txt"
}

# Show summary of changed files
show_changed_files() {
    cd "$BACKUP_DIR"

    local changed_files=$(git diff --cached --name-only)
    local deleted_files=$(git diff --cached --diff-filter=D --name-only)
    local added_files=$(git diff --cached --diff-filter=A --name-only)
    local modified_files=$(git diff --cached --diff-filter=M --name-only)

    if [ -z "$changed_files" ]; then
        return
    fi

    echo ""
    log_info "Changed files summary:"

    if [ -n "$added_files" ]; then
        echo -e "${GREEN}Added:${NC}"
        echo "$added_files" | sed 's/^/  /'
    fi

    if [ -n "$modified_files" ]; then
        echo -e "${YELLOW}Modified:${NC}"
        echo "$modified_files" | sed 's/^/  /'
    fi

    if [ -n "$deleted_files" ]; then
        echo -e "${RED}Deleted:${NC}"
        echo "$deleted_files" | sed 's/^/  /'
    fi
    echo ""
}

# Show git diff preview
show_diff_preview() {
    cd "$BACKUP_DIR"

    local num_changes=$(git diff --cached --stat | tail -1)
    log_info "Changes: $num_changes"

    # Show brief diff for each file (max 5 lines per file for readability)
    log_info "Preview of changes:"
    git diff --cached --no-color | head -100
    if [ $(git diff --cached --no-color | wc -l) -gt 100 ]; then
        echo "... (additional changes omitted for brevity)"
    fi
    echo ""
}

# Commit and push changes
commit_and_push() {
    cd "$BACKUP_DIR"

    # Add all changes
    git add -A

    # Check if there are changes to commit
    if git diff --cached --quiet; then
        log_info "No changes to commit"
        return
    fi

    # Show changed files and diff in interactive mode
    if [ "$NON_INTERACTIVE" = "false" ]; then
        show_changed_files
        show_diff_preview

        read -p "Commit these changes? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warn "Commit cancelled by user"
            return
        fi
    else
        log_info "Non-interactive mode: committing without confirmation"
    fi

    # Commit with timestamp
    local commit_msg="Backup $(date '+%Y-%m-%d %H:%M:%S')"
    git commit -m "$commit_msg"
    log_info "Committed changes: $commit_msg"

    # Push if remote exists
    if git remote | grep -q "origin"; then
        log_info "Pushing to remote..."
        if git push origin "$(git branch --show-current)" 2>/dev/null; then
            log_info "Pushed successfully"
        else
            log_warn "Push failed - you may need to set up the remote branch"
            log_warn "Try: git push -u origin $(git branch --show-current)"
        fi
    else
        log_warn "No remote configured. Changes committed locally only."
        log_warn "Add a remote with: git remote add origin <url>"
    fi
}

# Main execution
main() {
    log_info "Starting Arch Linux configuration backup..."
    log_info "Backup directory: $BACKUP_DIR"

    create_dirs
    init_git_repo
    backup_configs
    backup_local_bin
    backup_packages
    backup_systemd
    commit_and_push

    log_info "Backup completed!"
}

main "$@"
