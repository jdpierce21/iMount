# Utility Scripts

This directory contains utility scripts for maintenance, testing, and migration tasks.

## Scripts

### check_config.sh
Diagnostic script to check configuration paths and verify the installation is set up correctly. Shows:
- Current directory paths
- Configuration file locations
- Alternate location checks

### compare_mount.sh
Testing script that compares the script mount method with manual mounting. Useful for debugging mount issues.

### fix_config_path.sh
Migration utility for macOS to fix config path issues when the installation directory has changed. Helps copy config from alternate locations.

### fix_git_remote.sh
Git helper to switch the repository remote from HTTPS to SSH authentication.

### migrate_defaults.sh
Migration utility to move user defaults from the legacy location (`~/.nas_mount_defaults`) to the new location (`config/defaults.sh`).

### show_defaults.sh
Shows current default values including:
- System defaults
- User overrides
- Active environment variables
- Configuration file locations

## Usage

All scripts can be run from the main directory:

```bash
./utils/script_name.sh
```

Or from within the utils directory:

```bash
cd utils
./script_name.sh
```