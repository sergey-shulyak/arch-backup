#!/bin/bash
#
# Install the arch-backup systemd service
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="$SCRIPT_DIR/systemd/arch-backup.service"
SYSTEMD_DIR="/etc/systemd/system"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (sudo ./install-service.sh)"
    exit 1
fi

# Get the actual user (not root when using sudo)
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)

log_info "Installing arch-backup service for user: $ACTUAL_USER"

# Update the service file with correct paths and user
BACKUP_SCRIPT="$ACTUAL_HOME/Documents/arch-backup/backup.sh"

if [ ! -f "$BACKUP_SCRIPT" ]; then
    log_error "Backup script not found: $BACKUP_SCRIPT"
    exit 1
fi

# Create service file with correct user paths
cat > "$SYSTEMD_DIR/arch-backup.service" << EOF
[Unit]
Description=Arch Linux Configuration Backup
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
RemainAfterExit=yes
Environment="NON_INTERACTIVE=true"
Environment="HOME=$ACTUAL_HOME"
ExecStop=$BACKUP_SCRIPT
User=$ACTUAL_USER
Group=$ACTUAL_USER

[Install]
WantedBy=multi-user.target
EOF

log_info "Service file installed to $SYSTEMD_DIR/arch-backup.service"

# Reload systemd
systemctl daemon-reload
log_info "Systemd daemon reloaded"

# Enable the service
systemctl enable arch-backup.service
log_info "Service enabled"

# Start the service (so ExecStop will run on shutdown)
systemctl start arch-backup.service
log_info "Service started"

echo ""
log_info "Installation complete!"
log_info "The backup will run automatically before shutdown/reboot"
echo ""
log_warn "IMPORTANT: Make sure to run backup.sh manually first to set up the git repository"
log_warn "The automatic backup requires an existing git repository with remote configured"
echo ""
echo "Useful commands:"
echo "  - Check service status:  systemctl status arch-backup.service"
echo "  - View service logs:     journalctl -u arch-backup.service"
echo "  - Disable service:       sudo systemctl disable arch-backup.service"
echo "  - Uninstall service:     sudo rm /etc/systemd/system/arch-backup.service && sudo systemctl daemon-reload"
