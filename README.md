# Arch Linux Configuration Backup

Minimal, hardware-independent backup and restore scripts for Arch Linux + Hyprland.

## Philosophy

This repository provides a lightweight bootstrap system that:
- Installs packages for Hyprland desktop environment
- Restores user configs to `~/.config`
- Uses [hyprstyle](https://github.com/sergey-shulyak/hyprstyle) submodule for theming

**Theming is handled entirely by hyprstyle** - no theme configs are stored in this repo to avoid conflicts between machines with different themes.

## Repository Structure

```
arch-backup/
├── backup.sh           # Backup configs and package lists
├── restore.sh          # Interactive restore menu
├── bootstrap.sh        # Fresh install bootstrap
├── configs/
│   ├── home/.config/   # User configuration files
│   └── etc/            # System configuration files
├── packages/
│   ├── pacman.txt      # Explicitly installed native packages
│   └── aur.txt         # Explicitly installed AUR packages
├── local-bin/          # User scripts (~/.local/bin)
└── hyprstyle/          # Git submodule for theming
```

## Usage

### Fresh Install (Bootstrap)

On a fresh Arch installation (after archinstall):

```bash
# Install git
sudo pacman -Sy git

# Clone with submodules
git clone --recursive <your-repo-url> ~/Documents/arch-backup

# Run bootstrap
~/Documents/arch-backup/bootstrap.sh
```

The bootstrap will:
1. Create XDG home directory structure
2. Install yay (AUR helper)
3. Install all packages from `packages/pacman.txt` and `packages/aur.txt`
4. Restore `~/.config` and `~/.local/bin`
5. Set fish as default shell
6. Configure UFW firewall
7. Initialize hyprstyle and generate default theme

### Backup

```bash
./backup.sh
```

Backs up:
- `~/.config/` (excluding theme files and sensitive data)
- Home dotfiles (`.bashrc`, `.gitconfig`, etc.)
- User scripts (`~/.local/bin`)
- System configs (`/etc/pacman.conf`, `/etc/locale.conf`, etc.)
- Package lists (explicitly installed only)

### Restore

```bash
./restore.sh
```

Interactive menu:
1. Full bootstrap (packages → configs → theme)
2. Everything (configs → packages → theme)
3. Home directory configs and scripts only
4. System configs only (/etc)
5. Packages only
6. Generate theme only (run hyprstyle)

## Theming with Hyprstyle

Theme generation is handled by the [hyprstyle](https://github.com/sergey-shulyak/hyprstyle) submodule.

### Generate theme from wallpaper:
```bash
~/Documents/arch-backup/hyprstyle/hyprstyle.sh ~/Pictures/wallpaper.png
```

### Use default theme:
```bash
~/Documents/arch-backup/hyprstyle/hyprstyle.sh
```

Hyprstyle generates:
- `~/.config/hypr/colors.conf` - Hyprland colors
- `~/.config/hypr/hyprlock.conf` - Lock screen
- `~/.config/hypr/hyprpaper.conf` - Wallpaper
- `~/.config/kitty/kitty.conf` - Terminal colors
- `~/.config/mako/config` - Notification styling
- `~/.config/waybar/style.css` - Status bar CSS
- `~/.config/wofi/style.css` - Launcher CSS
- `~/.config/nvim/lua/nvim-colors.lua` - Editor colors

## What Gets Backed Up

### Configs (theme files excluded)
- Hyprland: `settings.conf`, `keybinds.conf`, `programs.conf`, `window-rules.conf`, `monitors*.conf`, `hypridle.conf`
- Waybar: `config.jsonc` (structure only, not CSS)
- Wofi: `config` (not style.css)
- Fish shell, Neovim, Starship, Yazi, and other applications

### Packages
- `pacman.txt` - Native packages from official repos
- `aur.txt` - AUR packages

GPU drivers are automatically excluded (hardware-specific).

### System Configs
- `/etc/pacman.conf`
- `/etc/makepkg.conf`
- `/etc/locale.conf`
- `/etc/vconsole.conf`
- `/etc/tlp.conf` (laptop power management)

## Excluded from Backup

- **Hyprstyle-generated files** (theme configs)
- SSH keys and GPG keys
- Credentials and secrets
- Browser profiles
- Cache directories
- Steam, Wine, Flatpak data
- IDE extensions and cache
- Shell history

## Multi-Machine Support

Monitor configurations are machine-specific:
- `monitors-rig.conf` - Desktop monitor layout
- `monitors-thinkpad.conf` - Laptop monitor layout
- `monitors.conf` - Active config (auto-selected by hostname)

## Updating Hyprstyle

```bash
cd ~/Documents/arch-backup
git submodule update --remote hyprstyle
```
