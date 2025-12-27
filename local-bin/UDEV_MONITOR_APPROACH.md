# Hyprland Monitor Auto-Switching: Udev Approach

## Overview

This document describes an alternative event-driven approach to automatically disable the builtin monitor when an external monitor is connected using udev rules and systemd. This is a more robust solution than the current IPC socket polling approach but requires more system-level configuration.

## Current Approach (IPC Socket Polling)

The current script (`hyprland-single-display`) uses:
- Hyprland IPC socket to detect monitor changes
- A daemon process that continuously listens for events
- Reactive switching when `monitoradded`, `monitorremoved`, or `monitorchanged` events occur

**Pros:** Simple, single script, easy to debug
**Cons:** Requires daemon running, dependent on Hyprland availability

## Udev Approach (Event-Driven)

Uses the OS-level udev subsystem to detect hardware changes:
- **udev rule** (~5 lines): Monitors DRM device changes at hardware level
- **systemd service** (~15 lines): Manages script execution with proper environment
- **Simplified script** (~30 lines): Counts monitors and enables/disables accordingly

**Pros:** Event-driven, no polling, works if Hyprland crashes, responsive
**Cons:** More complex setup, requires sudo, touches system configuration

## Implementation Steps

### 1. Create Udev Rule

File: `/etc/udev/rules.d/99-hyprland-monitor-hotplug.rules`

```bash
ACTION=="change", SUBSYSTEM=="drm", RUN+="/etc/udev/rules.d/hyprland-monitor-hotplug.sh"
```

This rule triggers whenever a DRM device changes (monitor connected/disconnected).

### 2. Create Udev Rule Script

File: `/etc/udev/rules.d/hyprland-monitor-hotplug.sh`

```bash
#!/bin/bash
# Trigger Hyprland monitor switching on hotplug event

# Get the Hyprland socket for the current user
for pid in $(pgrep -u $SUDO_USER hyprland); do
    export HYPRLAND_INSTANCE_SIGNATURE=$(grep -z HYPRLAND_INSTANCE_SIGNATURE /proc/$pid/environ | cut -d= -f2)
    if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
        export DISPLAY=:0
        export WAYLAND_DISPLAY=wayland-0
        /home/$SUDO_USER/.local/bin/hyprland-monitor-switch
        break
    fi
done
```

Make executable: `sudo chmod +x /etc/udev/rules.d/hyprland-monitor-hotplug.sh`

### 3. Create Simplified Monitor Switch Script

File: `/home/sshuliak/.local/bin/hyprland-monitor-switch`

```bash
#!/bin/bash
# Simplified monitor switcher for udev integration

BUILTIN_MONITOR="eDP-1"
EXTERNAL_MONITOR="DP-2"
LOG_FILE="${HOME}/.local/share/hyprland-monitor-switch.log"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Get all connected monitors
MONITORS=$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null)

if [ -z "$MONITORS" ]; then
    log_msg "Error: Could not detect monitors"
    exit 1
fi

# Count monitors
MONITOR_COUNT=$(echo "$MONITORS" | wc -l)

# Check if external monitor is connected
if echo "$MONITORS" | grep -q "$EXTERNAL_MONITOR"; then
    # External monitor connected: disable builtin
    log_msg "External monitor detected - disabling builtin"
    hyprctl keyword monitor "$BUILTIN_MONITOR,disable" 2>/dev/null || true
    hyprctl keyword monitor "$EXTERNAL_MONITOR,highrr,auto,1" 2>/dev/null || true
else
    # Only builtin available: enable it
    log_msg "No external monitor - enabling builtin"
    hyprctl keyword monitor "$BUILTIN_MONITOR,preferred,auto,1" 2>/dev/null || true
fi
```

Make executable: `chmod +x /home/sshuliak/.local/bin/hyprland-monitor-switch`

### 4. Alternative: Use Systemd Service

Instead of calling the script directly from udev, you can use a systemd service for better environment handling:

File: `/etc/systemd/user/hyprland-monitor-hotplug.service`

```ini
[Unit]
Description=Hyprland Monitor Hotplug Handler
After=hyprland-session.target

[Service]
Type=oneshot
ExecStart=/home/sshuliak/.local/bin/hyprland-monitor-switch
Environment="DISPLAY=:0"
Environment="WAYLAND_DISPLAY=wayland-0"
```

Then modify the udev rule to trigger the service:

```bash
ACTION=="change", SUBSYSTEM=="drm", RUN+="/usr/bin/systemctl --user start hyprland-monitor-hotplug.service"
```

## Advantages Over Current Approach

1. **Hardware-level detection**: Responds to physical unplugging/plugging
2. **No daemon needed**: Event-based, not polling
3. **Independent of Hyprland**: Works even if Hyprland crashes/restarts
4. **Immediate response**: Faster reaction to hardware changes
5. **System integration**: Follows standard Linux practices

## Disadvantages

1. **System-level changes**: Requires sudo/system configuration
2. **More complex setup**: Multiple files and components
3. **Harder to debug**: Need to check udev rules and logs
4. **User environment**: Must properly pass Hyprland environment variables to udev script

## Debugging Udev Rules

If the setup doesn't work:

```bash
# Check if rule exists
sudo ls -la /etc/udev/rules.d/99-hyprland-monitor-hotplug.rules

# Monitor udev events in real-time
sudo udevadm monitor --subsystem-match=drm

# Reload udev rules
sudo udevadm control --reload
sudo udevadm trigger

# Check system logs
journalctl -u hyprland-monitor-hotplug.service -f
sudo journalctl -f | grep hyprland

# Test rule syntax
sudo udevadm test /sys/class/drm/card0
```

## When to Switch to Udev Approach

Consider switching to this approach if:
- Monitor doesn't switch when Hyprland restarts
- Delays in detecting physical monitor changes
- You want OS-level event handling
- You prefer not having a daemon process running
- System resources are a concern

## References

- [Hyprland Discussion: Auto-disable on external monitor](https://github.com/hyprwm/Hyprland/discussions/10179)
- [GitHub Gist: Monitor hotplug with udev](https://gist.github.com/aron-hoogeveen/217b6d5d7e25bfda606eee94347ba6b6)
- [udev documentation](https://man7.org/linux/man-pages/man7/udev.7.html)
- [systemd user services](https://wiki.archlinux.org/title/Systemd/User)
