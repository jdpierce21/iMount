#!/bin/bash

###############################################################################
# File: setup_nas_mount.sh
# Date: 2025-06-12
# Version: 3.2.0
# Description: User-owned NAS mount setup using mount_smbfs on macOS.
#              Ditches autofs. Mounts to ~/Scripts/nas_mounts/Mounts at login.
###############################################################################

# === Elevation Check ===
if [[ "$EUID" -eq 0 ]]; then
  echo "🚫 Do not run this script as root. Please run it as your normal user."
  exit 1
fi

# === Load Configuration ===
# Determine script directory dynamically
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"
source "$CONFIG_FILE"

# === Load Shared Functions ===
source "$SCRIPT_DIR/shared_functions.sh"

# === Handle optional --force flag ===
if [[ "$1" == "--force" ]]; then
  FORCE_REPLACE=true
  echo "⚠️  Running in FORCE mode. Existing mounts and plist will be replaced."
fi

# === Credential Setup ===
ensure_credentials
if [ -f "$CREDENTIALS_FILE" ]; then
  log "✅ Credentials file ready"
fi

# === Create Mount Directories ===
if [[ $FORCE_REPLACE == true ]]; then
  create_mount_directories --force
else
  create_mount_directories
fi

# === Check for mount script ===
if [[ ! -f "$MOUNT_SCRIPT" ]]; then
  log "❌ Mount script not found at $MOUNT_SCRIPT"
  log "Please ensure mount_nas_shares.sh exists in the script directory"
  exit 1
fi
chmod +x "$MOUNT_SCRIPT"
log "✅ Using existing mount script: $MOUNT_SCRIPT"

# === Platform-specific checks ===
if [[ "$OS_TYPE" == "linux" ]]; then
  # Check for required packages on Linux
  if ! which mount.cifs >/dev/null 2>&1; then
    log "❌ cifs-utils package is not installed"
    echo ""
    echo "Please install cifs-utils:"
    echo "  Ubuntu/Debian: sudo apt-get install cifs-utils"
    echo "  RHEL/CentOS:   sudo yum install cifs-utils"
    echo "  Arch:          sudo pacman -S cifs-utils"
    exit 1
  fi
fi

# === Create auto-start mechanism ===
# Check if AUTO_START preference is set (from install.sh)
if [[ "${AUTO_START:-yes}" == "no" ]]; then
  log "ℹ️  Skipping auto-start setup (per configuration)"
elif [[ "$OS_TYPE" == "macos" ]]; then
  # macOS: Create LaunchAgent
  log "🛠 Generating LaunchAgent to mount shares at login..."
  mkdir -p "$(dirname "$PLIST_PATH")"
  
  cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.jpierce.nas-mounts</string>
  <key>ProgramArguments</key>
  <array>
    <string>$MOUNT_SCRIPT</string>
    <string>mount</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>600</integer>
  <key>StandardOutPath</key>
  <string>$LOG_DIR/nas_mounts.out</string>
  <key>StandardErrorPath</key>
  <string>$LOG_DIR/nas_mounts.err</string>
</dict>
</plist>
EOF

  launchctl unload "$PLIST_PATH" 2>/dev/null
  launchctl load "$PLIST_PATH"
  log "✅ LaunchAgent loaded to auto-mount NAS shares at login."
  
elif [[ "$OS_TYPE" == "linux" ]]; then
  # Linux: Create systemd service
  log "🛠 Generating systemd service to mount shares at login..."
  mkdir -p "$SERVICE_DIR"
  
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Mount NAS shares
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$MOUNT_SCRIPT mount
ExecStop=$MOUNT_SCRIPT unmount
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable nas-mounts.service
  log "✅ Systemd user service created and enabled"
fi

# === Create convenience aliases (optional) ===
# Check if ADD_ALIASES preference is set (from install.sh)
if [[ "${ADD_ALIASES:-yes}" == "yes" ]]; then
  log "Adding shell aliases..."
  add_shell_aliases
fi

# === Show status ===
echo -e "\n📂 NAS shares will mount to: $MOUNT_ROOT"
ls -l "$MOUNT_ROOT" 2>/dev/null || echo "(Mount directory will be created on first mount)"
log "🎉 Setup complete!"

# === Platform-specific notes ===
if [[ "$OS_TYPE" == "linux" ]]; then
  echo ""
  echo "⚠️  Important notes for Linux:"
  echo "1. The mount command requires sudo privileges"
  echo "2. You may be prompted for your sudo password when mounting"
  echo "3. To avoid sudo prompts, you can add this to /etc/sudoers:"
  echo "   $USER ALL=(ALL) NOPASSWD: /usr/bin/mount, /usr/bin/umount"
elif [[ "$OS_TYPE" == "macos" ]]; then
  echo ""
  echo "✅ Your NAS shares will be mounted automatically on login."
fi
echo ""
