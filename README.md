# NAS Mount Manager

A cross-platform (macOS/Linux) script collection for automatically mounting NAS shares with intelligent error handling, logging, and auto-reconnection.

## Features

- 🖥️ **Cross-platform**: Works on both macOS and Linux
- 🔄 **Auto-mount at login**: Configures systemd (Linux) or LaunchAgent (macOS)
- 📝 **Advanced logging**: System-style logs with automatic rotation
- 🔌 **Auto-reconnection**: Handles network interruptions gracefully
- 🛡️ **Secure**: Credentials stored with 600 permissions
- 🎯 **Simple**: One-line installation
- 📦 **Modular**: Clean, maintainable code structure

## Quick Start

### One-line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/jdpierce21/nas_mount/main/install.sh | bash
```

### Manual Installation

```bash
git clone https://github.com/jdpierce21/nas_mount.git
cd nas_mount
./install.sh
```

## What It Does

1. **Prompts for configuration**:
   - NAS IP/hostname
   - Shares to mount
   - Username/password
   - Mount location preference
   - Auto-start preference

2. **Creates mount points** (keeps them separate from scripts):
   - macOS: `~/NAS_Mounts/`
   - Linux: `~/nas_mounts/`

3. **Sets up auto-mounting**:
   - macOS: LaunchAgent
   - Linux: systemd user service

4. **Adds convenient aliases**:
   - `nas-mount` - Mount all shares
   - `nas-unmount` - Unmount all shares  
   - `nas-status` - Check mount status

## Usage

### After installation:

```bash
# Mount all configured shares
nas-mount

# Check status
nas-status

# Unmount all shares
nas-unmount

# View logs
tail -f ~/scripts/nas_mounts/logs/nas_mount.log
```

### Manual commands:

```bash
cd ~/scripts/nas_mounts  # or ~/Scripts/nas_mounts on macOS

# Mount shares
./mount_nas_shares.sh mount

# Check status
./mount_nas_shares.sh status

# Unmount shares
./mount_nas_shares.sh unmount

# Validate all mounts
./validate_nas_mounts.sh
```

## Configuration

Configuration is stored in `config.sh` after running the installer. To reconfigure:

```bash
# Option 1: Delete config and run installer again
rm ~/scripts/nas_mounts/config.sh
./install.sh

# Option 2: Edit config directly
nano ~/scripts/nas_mounts/config.sh
```

### Example config.sh:

```bash
NAS_HOST="192.168.1.100"
SHARES=("documents" "media" "backups" "photos")
MOUNT_ROOT="$HOME/nas_mounts"
```

## Updating

To update to the latest version:

```bash
cd ~/scripts/nas_mounts
git pull
# Your config and mounts are preserved!
```

## Requirements

- **macOS**: No additional requirements
- **Linux**: `cifs-utils` package
  ```bash
  # Ubuntu/Debian
  sudo apt-get install cifs-utils
  
  # RHEL/CentOS
  sudo yum install cifs-utils
  ```

## Troubleshooting

### Mounts fail on Linux

If you get password prompts, add this to `/etc/sudoers`:
```
yourusername ALL=(ALL) NOPASSWD: /usr/bin/mount, /usr/bin/umount
```

### Can't reach NAS

Check connectivity:
```bash
ping your-nas-ip
```

### View detailed logs

```bash
# Recent logs
tail -n 50 ~/scripts/nas_mounts/logs/nas_mount.log

# Follow logs
tail -f ~/scripts/nas_mounts/logs/nas_mount.log

# Error logs
cat ~/scripts/nas_mounts/logs/nas_mount.err
```

## File Structure

```
nas_mount/
├── install.sh              # Main installer
├── config.sh               # Configuration (created by installer)
├── shared_functions.sh     # Common functions
├── mount_nas_shares.sh     # Main mounting script
├── setup_nas_mount.sh      # Setup automation
├── validate_nas_mounts.sh  # Mount validation
├── logs/                   # Log files (auto-created)
└── README.md              # This file
```

## Security Notes

- Credentials are stored in `~/.nas_credentials` with 600 permissions
- Only readable by your user account
- Consider using a dedicated NAS user with limited permissions

## Contributing

Pull requests welcome! Please test on both macOS and Linux.

## License

MIT License - See LICENSE file for details

## Author

Created by jdpierce21

---

**Note**: Your actual NAS mounts are stored separately from the scripts, so updating or reinstalling won't affect your mounted shares.