# Machine-Specific Configurations

This document describes the setup differences between machines and how to properly restore configurations across multiple systems.

## Overview

The backup system is designed to mirror configurations between multiple machines while handling machine-specific differences:
- **Hardware**: CPU, GPU, displays
- **Power management**: Desktop vs. laptop
- **Services**: Hardware-specific system services
- **Display configuration**: Monitor layouts and refresh rates

---

## Machine: `rig` (Desktop - Primary)

### Hardware
- **CPU**: AMD Ryzen (Raphael architecture)
- **GPU**: NVIDIA GeForce RTX 5060 (discrete)
- **Architecture**: x86_64
- **Display output**: DP-2 (primary, high refresh rate)

### Installed GPU Drivers
```bash
nvidia-dkms or nvidia-open-dkms
lib32-nvidia-utils
libva-nvidia-driver
libva-mesa-driver
vulkan-radeon (for AMD support)
```

### System Services (Enabled)
```bash
systemctl --user list-unit-files --state=enabled | grep -v "^UNIT"
# Key services:
# - openrgb.service (LED controller - profiles: /home/sshuliak/.config/OpenRGB/msi.orp)
# - mako.service (notification daemon)
# - pipewire + wireplumber (audio)
# - 1password-agent.service
# - gnome-keyring.service
# - polkit-gnome.service
# - cliphist-wl-paste.service
```

### Hyprland Config
- **Monitor config file**: `~/.config/hypr/monitors-rig.conf`
- **Key settings**:
  - DP-2 at high refresh rate (auto resolution)
  - eDP-1 as secondary embedded display
  - Fallback for other monitors
- **Special services**: openrgb with custom LED profile

### Display Configuration
```bash
# Check actual monitor names:
hyprctl monitors all

# Current monitors-rig.conf:
monitor=DP-2,highrr,auto,1        # Primary external, high refresh
monitor=eDP-1,preferred,auto,1    # Secondary embedded display
monitor=,preferred,auto,1          # Fallback
```

### Restoring to This Machine
When restoring on `rig`:
1. All package lists (GPU drivers already included)
2. All user services (all rig-specific services will match)
3. All configs including openrgb profile
4. **Skip**: No special handling needed - this is the primary machine

### Notes
- GPU drivers are included in backup (not excluded like they used to be)
- OpenRGB profile path is hardcoded - see "Known Issues" below
- This is the "golden image" machine that other machines mirror from

---

## Machine: `thinkpad` (Laptop - Secondary)

### Expected Hardware
- **CPU**: Intel (likely 11th-13th gen Core)
- **GPU**: Intel Iris Xe (integrated) or NVIDIA discrete
- **Architecture**: x86_64
- **Display output**: eDP-1 (internal panel) + USB-C/Thunderbolt dock

### Required GPU Drivers
For Intel integrated graphics:
```bash
intel-media-driver
libva-intel-driver
vulkan-intel
```

For discrete NVIDIA (if present):
```bash
nvidia-dkms or nvidia-open-dkms
lib32-nvidia-utils
libva-nvidia-driver
```

### Power Management
**Important**: Install TLP (power management for laptops)
```bash
sudo pacman -S tlp tlp-rdw
sudo systemctl enable tlp.service
sudo systemctl enable tlp-sleep.service
```

Then enable in restore:
- `tlp.service`
- `tlp-sleep.service`

### System Services (To Enable on ThinkPad)
Compare against rig and selectively enable:
```bash
# Enable these (same across machines):
1password-agent.service
cliphist-wl-paste.service
gnome-keyring.service
mako.service
mpd.service
pipewire + wireplumber
polkit-gnome.service
xdg-user-dirs.service

# Enable on ThinkPad ONLY:
tlp.service (power management)
tlp-sleep.service (sleep hook)

# Skip on ThinkPad:
openrgb.service (no RGB controller on ThinkPad)
hyprland-single-display.service (if rig-specific)
```

### Hyprland Config
- **Monitor config file**: `~/.config/hypr/monitors-thinkpad.conf`
- **Setup steps**:
  1. Boot Hyprland on ThinkPad
  2. Run: `hyprctl monitors all`
  3. Note the output names (likely `eDP-1`, `HDMI-1`, or `DP-1`)
  4. Copy `monitors-thinkpad.conf.example` to `monitors-thinkpad.conf`
  5. Edit with actual monitor names and positions

- **Example config for typical ThinkPad**:
```bash
# Internal display at 0x0, external at 1920x0 (side-by-side)
monitor=eDP-1,preferred,0x0,1
monitor=HDMI-1,preferred,1920x0,1
```

- **Example for docked setup**:
```bash
# Using USB-C dock with DisplayPort
monitor=eDP-1,preferred,0x0,1
monitor=DP-1,2560x1440@60,1920x0,1
```

### Restoring to ThinkPad
1. **Before restore**: Install required GPU drivers
   ```bash
   # For Intel integrated graphics:
   sudo pacman -S intel-media-driver libva-intel-driver vulkan-intel

   # For power management:
   sudo pacman -S tlp tlp-rdw
   ```

2. **Run restore.sh**:
   - Choose: "1) Full bootstrap (packages → configs → services)"
   - When prompted for configs: **YES** (accept all)
   - When prompted for services: **selectively enable** per the checklist above
   - When prompted for openrgb: **SKIP** (not available on ThinkPad)

3. **After restore**: Configure monitors
   ```bash
   # Check actual monitor names:
   hyprctl monitors all

   # Edit the monitor config:
   nano ~/.config/hypr/monitors-thinkpad.conf
   ```

4. **Restart Hyprland** to apply monitor config

---

## Mirroring Workflow - Automatic Hardware-Aware Restoration

The backup/restore system now automatically handles hardware-specific configuration based on hostname!

### Hardware Mapping
Services are automatically categorized by machine in `systemd/HARDWARE_MAPPING.conf`:
- **Universal services** (all machines): 1password-agent, gnome-keyring, mako, pipewire, etc.
- **Desktop-only** (rig): openrgb.service (LED controller)
- **Laptop-only** (thinkpad): tlp.service, tlp-sleep.service (power management)

When you restore on a new machine, the system automatically:
✓ Enables universal services
✓ Enables hardware-specific services applicable to that machine
✗ Skips hardware-specific services for other machines

### From Desktop (rig) to Laptop (thinkpad)

```
┌─────────────────────────────────────┐
│ On Desktop (rig):                   │
│ 1. Run: ./backup.sh                 │
│    (Creates state files with        │
│     hardware applicability)          │
│ 2. Commit and push to git remote    │
└──────────────┬──────────────────────┘
               │
               ↓ (git pull / clone)
┌──────────────────────────────────────┐
│ On Laptop (thinkpad):                │
│ 1. Clone/pull backup repo            │
│ 2. Install pre-reqs:                 │
│    - GPU drivers (intel-media-driver)│
│    - TLP (tlp, tlp-rdw)              │
│ 3. Run: ./restore.sh                 │
│ 4. Select: "1) Full bootstrap"       │
│ 5. Accept packages & configs         │
│ 6. Review service changes:           │
│    ✓ Enable: waybar, 1password, etc. │
│    ✓ Enable: tlp.service (auto!)     │
│    ✗ Skip: openrgb (auto!)           │
│    → Single "Apply?" prompt          │
│ 7. Configure monitors:               │
│    - Edit monitors-thinkpad.conf     │
│ 8. Restart Hyprland                  │
└──────────────────────────────────────┘
```

### What's Automatic Now

**Before restore:**
- You had to manually decide for each service
- Easy to forget openrgb on thinkpad
- Easy to miss tlp on thinkpad

**After restore (with hardware mapping):**
```
Analyzing user services for 'thinkpad'...

Summary of changes for 'thinkpad':
Will apply:
  ✓ 1password-agent.service (enable)
  ✓ cliphist-wl-paste.service (enable)
  ✓ gnome-keyring.service (enable)
  ✓ mako.service (enable)
  [... other universal services ...]

Skipping (not applicable to this machine):
  ○ openrgb.service (for rig)
  ○ hyprland-single-display.service (if rig-specific)

Apply these user service changes? (y/N): y
```

**Then for system services:**
```
Summary of system service changes for 'thinkpad':
Will apply:
  ✓ tlp.service (enable)
  ✓ tlp-sleep.service (enable)

Skipping (not applicable to this machine):
  ○ openrgb.service (for rig)

Apply these system service changes? (y/N): y
```

Done! Everything applicable to thinkpad is auto-enabled, everything rig-specific is auto-skipped.

### From Laptop (thinkpad) back to Desktop (rig)

When updating the golden image from ThinkPad:

1. **On ThinkPad**: Run `./backup.sh`
2. **On Desktop**: Pull changes
   ```bash
   cd ~/Documents/arch-backup && git pull
   ```
3. **On Desktop**: Check what changed
   ```bash
   git log -1 --stat
   git diff HEAD~1
   ```
4. **Review selectively**: Some changes from ThinkPad should NOT be merged:
   - `monitors-thinkpad.conf` changes (keep in separate file)
   - TLP service enablement (only for ThinkPad)
   - Different GPU driver states

---

## Known Issues & Workarounds

### 1. OpenRGB Profile Path is Hardcoded
**Problem**: `openrgb.service` has hardcoded path to OpenRGB profile:
```bash
ExecStart=/usr/bin/openrgb --server --profile /home/sshuliak/.config/OpenRGB/msi.orp
```

**Solution** (long-term): Change to use home directory variable
```bash
# TODO: Fix in systemd service to use:
ExecStart=/usr/bin/openrgb --server --profile %h/.config/OpenRGB/msi.orp
```

**Workaround** (short-term): When restoring to ThinkPad, simply SKIP openrgb service if LED controller hardware isn't available.

### 2. Monitor Configuration Differs Significantly
**Problem**: Desktop has DP-2 + eDP-1, ThinkPad will have different outputs

**Solution**: Each machine has its own `monitors-$(hostname).conf` file that's loaded via `hyprland.conf`. This is now automated - just customize the monitor config file for each machine.

### 3. TLP Not in Desktop Backup
**Problem**: TLP (power management) won't be backed up from desktop since it's not installed there

**Solution**: When restoring to ThinkPad, manually install TLP before/after restore:
```bash
sudo pacman -S tlp tlp-rdw
sudo systemctl enable tlp.service tlp-sleep.service
```

---

## Per-Service Decision Matrix

When restoring on a new machine, use this table to decide for each service:

| Service | Desktop (rig) | Laptop (thinkpad) | Notes |
|---------|---------------|-------------------|-------|
| 1password-agent | ✓ Enable | ✓ Enable | Cross-platform |
| cliphist-wl-paste | ✓ Enable | ✓ Enable | Cross-platform |
| gnome-keyring | ✓ Enable | ✓ Enable | Cross-platform |
| mako | ✓ Enable | ✓ Enable | Notification daemon |
| mpd | ✓ Enable | ✓ Enable | Music server |
| openrgb | ✓ Enable | ✗ Skip | Desktop LED controller only |
| pipewire | ✓ Enable | ✓ Enable | Audio |
| polkit-gnome | ✓ Enable | ✓ Enable | Permission dialogs |
| tlp | ✗ Skip | ✓ Enable | Laptop power mgmt only |
| tlp-sleep | ✗ Skip | ✓ Enable | Laptop sleep hook |
| wireplumber | ✓ Enable | ✓ Enable | PipeWire session manager |
| xdg-user-dirs | ✓ Enable | ✓ Enable | XDG directories |

---

## Adding a Third Machine

To add a new machine (e.g., "mypc", "laptop2", etc.):

1. **On the new machine**, determine its hostname:
   ```bash
   cat /etc/hostname
   ```

2. **Create a monitor config file**:
   ```bash
   cp ~/.config/hypr/monitors-thinkpad.conf.example ~/.config/hypr/monitors-NEWHOSTNAME.conf
   nano ~/.config/hypr/monitors-NEWHOSTNAME.conf  # Edit with actual monitors
   ```

3. **Restore configuration** using the standard procedure
   - The monitor config will auto-load based on hostname

4. **Test**: Restart Hyprland and verify monitors work

---

## Troubleshooting

### Monitors not loading on new machine
1. Check hostname: `cat /etc/hostname`
2. Check if monitor config exists: `ls ~/.config/hypr/monitors-*.conf`
3. Check monitor names: `hyprctl monitors all`
4. Check Hyprland logs: `journalctl --user -u hyprland -n 20`

### Service enable fails with "Unit not found"
- Package may not be installed
- This is expected! The restore script will warn you
- Either skip the service or install the package first

### GPU drivers missing after restore
- Backup excludes GPU drivers by design (hardware-specific)
- Install appropriate drivers:
  - **AMD**: `linux-firmware-amdgpu`
  - **NVIDIA**: `nvidia-dkms` or `nvidia-open-dkms`
  - **Intel**: `intel-media-driver`

### TLP not working after restore
- You may need to enable it manually: `sudo systemctl enable tlp.service`
- Or reinstall: `sudo pacman -S tlp tlp-rdw`

---

## Backup Structure

```
arch-backup/
├── backup.sh              # Main backup script
├── restore.sh             # Main restore script
├── bootstrap.sh           # Bootstrap new system
├── MACHINES.md            # This file
├── configs/               # Configuration files
│   └── home/.config/hypr/
│       ├── hyprland.conf
│       ├── monitors-rig.conf           # Desktop monitor config
│       ├── monitors-thinkpad.conf      # Laptop monitor config (example)
│       ├── monitors-thinkpad.conf.example
│       ├── keybinds.conf
│       ├── settings.conf
│       └── ...
├── packages/              # Package lists (GPU drivers excluded)
├── systemd/               # Systemd service states
│   ├── user-services-state.txt
│   ├── system-services-state.txt
│   └── ...
└── scripts/               # Utility scripts
```

---

## Tips for Successful Multi-Machine Setup

1. **Use hostnames consistently**: Each machine should have a unique, memorable hostname
   - `rig` (desktop)
   - `thinkpad` or `laptop` (main laptop)
   - `server` or other names for additional machines

2. **Test restore on same machine first**:
   ```bash
   # Disable a service, then restore and verify it gets re-enabled
   systemctl --user disable mako.service
   ./restore.sh
   # Choose mako.service → enable
   ```

3. **Keep a clean golden image**: Regularly backup from your primary machine (rig) to ensure the repo reflects your current setup

4. **Document special configurations**: If you add custom services or configs specific to one machine, update this MACHINES.md file

5. **Version control your monitor configs**: The git history will track which monitor setup you're using across machines
