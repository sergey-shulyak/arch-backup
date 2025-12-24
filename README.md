# Arch Linux Configuration Backup

Backup and restore scripts for Arch Linux system configuration.

## Usage

### Backup

```bash
./backup.sh
```

This will:
1. Initialize git repository if not present (prompts for remote URL)
2. Backup entire `~/.config` directory (with smart exclusions)
3. Backup home directory dotfiles
4. Backup system configs from `/etc`
5. Export package lists (native, AUR, all with versions)
6. Export enabled systemd services (user and system)
7. Commit and push changes to git

### Restore

```bash
./restore.sh
```

Interactive menu to restore:
1. Everything (full restore)
2. Home directory configs only
3. System configs only (/etc)
4. Packages only
5. Systemd services only

### Fresh Install / Bootstrap

On a fresh Arch installation, you have two options:

#### Option 1: One-liner bootstrap (recommended)

After installing base Arch and logging in as your user:

```bash
# Install git first (only thing you need)
sudo pacman -Sy git

# Clone and run bootstrap
git clone <your-repo-url> ~/Documents/arch-backup
~/Documents/arch-backup/bootstrap.sh
```

Or use curl if the repo is public:

```bash
curl -sL https://raw.githubusercontent.com/<user>/<repo>/main/bootstrap.sh | bash -s <repo-url>
```

#### Option 2: Manual restore

```bash
sudo pacman -Sy git
git clone <your-repo-url> ~/Documents/arch-backup
cd ~/Documents/arch-backup
./restore.sh
# Select option 1 "Full bootstrap"
```

The bootstrap process will:
1. Install essential packages (git, base-devel)
2. Install AUR helper (yay)
3. Install all native packages from official repos
4. Install all AUR packages
5. Restore `~/.config` and dotfiles
6. Restore system configs (optional)
7. Enable systemd services
8. Optionally install the automatic backup service

## Automatic Backup on Shutdown

Install the systemd service to automatically backup before shutdown/reboot:

```bash
# First, run backup manually to set up git repository
./backup.sh

# Then install the systemd service
sudo ./install-service.sh
```

### Service Management

```bash
# Check status
systemctl status arch-backup.service

# View logs
journalctl -u arch-backup.service

# Disable automatic backup
sudo systemctl disable arch-backup.service

# Uninstall service
sudo rm /etc/systemd/system/arch-backup.service
sudo systemctl daemon-reload
```

## What Gets Backed Up

### Configuration Files

The entire `~/.config` directory is backed up using rsync, with smart exclusions for:
- Sensitive data (credentials, secrets, tokens)
- Cache directories
- Browser data
- Large application data (Steam, Wine, Flatpak)
- IDE cache and extensions

### Home Directory Dotfiles
- `.bashrc`, `.zshrc`, `.profile`, etc.
- `.gitconfig`, `.gitignore_global`
- `.vimrc`, `.tmux.conf`
- `.xinitrc`, `.Xresources`, `.xprofile`
- `.ssh/config` (not keys)

### System Configs
- `/etc/pacman.conf`
- `/etc/makepkg.conf`
- `/etc/fstab`
- `/etc/hostname`
- `/etc/locale.conf`
- `/etc/vconsole.conf`
- `/etc/X11/xorg.conf.d/`
- `/etc/environment.d/`

### Package Lists
- `pacman-explicit.txt` - Explicitly installed packages
- `pacman-native.txt` - Native packages (official repos)
- `pacman-aur.txt` - AUR packages
- `pacman-all-versions.txt` - All packages with versions

### Systemd Services
- `user-services.txt` - Enabled user services
- `system-services.txt` - Enabled system services

## Excluded from Backup

The following are automatically excluded:
- SSH keys and GPG keys
- Credentials and secrets
- Cache directories
- Browser profiles
- Steam, Wine, Lutris data
- Flatpak and Snap data
- Node modules, Python venvs
- IDE extensions and cache
- Shell history files

## Customization

### Adding Exclusions

Edit `backup.sh` and add patterns to `EXCLUDE_PATTERNS` array:

```bash
EXCLUDE_PATTERNS=(
    # ... existing patterns ...
    ".config/myapp/cache"
)
```

### Adding Dotfiles

Add to the `dotfiles` array in `backup_home_dotfiles()`:

```bash
local dotfiles=(
    # ... existing files ...
    ".myconfig"
)
```
