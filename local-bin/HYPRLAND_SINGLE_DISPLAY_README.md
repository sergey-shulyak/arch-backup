# Hyprland Single Display Script

Automatically switches to single display mode in Hyprland. The script can run as a background daemon that monitors for display changes, or be called manually.

## Files

- `hyprland-single-display` - Main script (executable)
- `~/.config/systemd/user/hyprland-single-display.service` - Systemd service (auto-start with login)

## Usage

### Manual One-Time Switch

```bash
# Use auto-detected primary monitor (first connected)
~/.local/bin/hyprland-single-display

# Specify a monitor name
~/.local/bin/hyprland-single-display HDMI-1
```

### Automatic Mode (Service)

The systemd service automatically monitors for display changes and switches to single display mode whenever monitors are connected/disconnected.

**Enable auto-start on login:**
```bash
systemctl --user enable hyprland-single-display
systemctl --user start hyprland-single-display
```

**Check service status:**
```bash
systemctl --user status hyprland-single-display

# View logs
journalctl --user -u hyprland-single-display -f
```

**View daemon activity:**
```bash
# Real-time log file
tail -f /run/user/$(id -u)/hyprland-single-display.log
# or on systems without XDG_RUNTIME_DIR:
tail -f /tmp/hyprland-single-display.log
```

### Check Available Monitors

```bash
hyprctl monitors
```

## Integration with Hyprland Config

You can add manual keybindings to `~/.config/hypr/hyprland.conf` to switch displays instantly:

```conf
bind = SUPER, F4, exec, ~/.local/bin/hyprland-single-display
```

## Requirements

- `hyprctl` (included with Hyprland)
- `jq` (for JSON parsing)
- `bash`

Install jq if needed:
```bash
sudo pacman -S jq
```

## How It Works

**Daemon mode** (systemd service):
- Polls monitor configuration every 5 seconds
- When a change is detected, automatically switches to single display (first monitor)
- Logs all activity to `/run/user/$(id -u)/hyprland-single-display.log`
- Restarts automatically if it crashes

**Manual mode**:
- One-time switch to single display
- Auto-detects primary monitor (first connected) or use specified monitor
- Can be bound to keybindings or run from terminal
