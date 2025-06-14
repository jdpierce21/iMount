# NAS Mount Manager - Configuration Defaults

This document describes how to customize the default values used by the NAS Mount Manager.

## Overview

The NAS Mount Manager uses a simple configuration hierarchy:

1. **System Defaults** (`lib/defaults.sh`) - Built-in defaults, not user-editable
2. **User Defaults** (`config/defaults.sh`) - Optional user overrides
3. **Installation Config** (`config/config.sh`) - Actual configuration created by setup

## Configuration Files

### System Defaults (`lib/defaults.sh`)
- Contains all default values
- Part of the codebase, should not be edited
- Automatically loaded by all scripts

### User Defaults (`config/defaults.sh`)
- Optional file for customizing defaults
- Copy `config/defaults.sh.example` to get started
- Overrides system defaults
- Persists across updates

### Installation Config (`config/config.sh`)
- Created by `setup.sh`
- Contains actual configuration for your installation
- Can be edited after setup to change settings

## How to Override Defaults

There are three ways to override default values:

1. **User Defaults File**: Create `config/defaults.sh` with your overrides (recommended)
2. **Environment Variables**: Export variables before running the scripts
3. **One-time Override**: Set variables inline when running commands

### Method 1: User Defaults File (Recommended)

Create `config/defaults.sh`:

```bash
# Copy the example file
cp config/defaults.sh.example config/defaults.sh

# Edit with your settings
# Example content:
export NAS_MOUNT_DEFAULT_HOST="192.168.1.100"
export NAS_MOUNT_DIR_PREFIX="share_"
export NAS_MOUNT_DEFAULT_SHARES="documents photos music"
```

This file is automatically loaded by all scripts and persists across updates.

### Method 2: Environment Variables

```bash
export NAS_MOUNT_DEFAULT_HOST="192.168.1.100"
export NAS_MOUNT_DIR_PREFIX="share_"
./install.sh
```

### Method 3: One-time Override

```bash
NAS_MOUNT_DEFAULT_HOST="192.168.1.100" ./setup.sh
```

## Available Defaults

### Network Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `NAS_MOUNT_DEFAULT_HOST` | `192.168.54.249` | Default NAS IP address |
| `NAS_MOUNT_SMB_PORT` | `445` | SMB port number |

### Directory Structure

| Variable | Default | Description |
|----------|---------|-------------|
| `NAS_MOUNT_DIR_PREFIX` | `nas_` | Prefix for mount directories |
| `NAS_MOUNT_CONFIG_DIR` | `config` | Config directory name |
| `NAS_MOUNT_LOG_DIR` | `logs` | Log directory name |
| `NAS_MOUNT_ROOT` | `$HOME/nas_mounts` | Where shares are mounted |
| `NAS_MOUNT_SCRIPT_DIR` | `$HOME/Scripts/nas_mounts` (macOS)<br>`$HOME/scripts/nas_mounts` (Linux) | Installation directory |

### File Names

| Variable | Default | Description |
|----------|---------|-------------|
| `NAS_MOUNT_CREDENTIALS_FILE` | `.nas_credentials` | Credentials file name |
| `NAS_MOUNT_CONFIG_FILE` | `config.sh` | Config file name |
| `NAS_MOUNT_LOG_FILE` | `nas_mount.log` | Log file name |

### Service Names

| Variable | Default | Description |
|----------|---------|-------------|
| `NAS_MOUNT_LAUNCHAGENT` | `com.jpierce.nas-mounts` | macOS LaunchAgent name |
| `NAS_MOUNT_SYSTEMD_SERVICE` | `nas-mounts` | Linux systemd service name |

### Default Shares

| Variable | Default | Description |
|----------|---------|-------------|
| `NAS_MOUNT_DEFAULT_SHARES` | `backups documents media notes PacificRim photos timemachine_mbp14` | Space-separated list of shares |

### Mount Options

| Variable | Default | Description |
|----------|---------|-------------|
| `NAS_MOUNT_MACOS_OPTIONS` | `-N -o nobrowse` | macOS mount options |
| `NAS_MOUNT_LINUX_OPTIONS` | `iocharset=utf8,file_mode=0777,dir_mode=0777` | Linux mount options (uid/gid added automatically) |

### Timeouts

| Variable | Default | Description |
|----------|---------|-------------|
| `NAS_MOUNT_UNMOUNT_TIMEOUT` | `30` | Normal unmount timeout (deciseconds) |
| `NAS_MOUNT_FORCE_UNMOUNT_TIMEOUT` | `20` | Force unmount timeout (deciseconds) |
| `NAS_MOUNT_WAIT` | `1` | Mount verification wait (seconds) |
| `NAS_MOUNT_RETRY_WAIT` | `2` | Mount retry wait (seconds) |

### GitHub Repository

| Variable | Default | Description |
|----------|---------|-------------|
| `NAS_MOUNT_GITHUB_USER` | `jdpierce21` | GitHub username |
| `NAS_MOUNT_GITHUB_REPO` | `nas_mount` | Repository name |
| `NAS_MOUNT_GITHUB_BRANCH` | `master` | Branch name |

### Miscellaneous

| Variable | Default | Description |
|----------|---------|-------------|
| `NAS_MOUNT_DEBUG_LOG_RETENTION` | `10` | Number of debug logs to keep |
| `NAS_MOUNT_TEST_FILE_PREFIX` | `.nas_mount_test_` | Test file prefix |

## Examples

### Example 1: Different NAS and Shares

```bash
# config/defaults.sh
export NAS_MOUNT_DEFAULT_HOST="192.168.1.100"
export NAS_MOUNT_DEFAULT_SHARES="shared backup media"
export NAS_MOUNT_DIR_PREFIX="mount_"
```

### Example 2: Custom Installation Path

```bash
# config/defaults.sh
export NAS_MOUNT_SCRIPT_DIR="$HOME/bin/nas_mounts"
export NAS_MOUNT_ROOT="/mnt/nas"
```

### Example 3: Using Your Own Fork

```bash
# config/defaults.sh
export NAS_MOUNT_GITHUB_USER="myusername"
export NAS_MOUNT_GITHUB_REPO="nas_mount_fork"
export NAS_MOUNT_GITHUB_BRANCH="main"
```

### Example 4: Enhanced Security Options

```bash
# config/defaults.sh
export NAS_MOUNT_LINUX_OPTIONS="iocharset=utf8,file_mode=0755,dir_mode=0755,vers=3.0,seal"
export NAS_MOUNT_MACOS_OPTIONS="-N -o nobrowse,soft,noperm"
```

## Installation with Custom Defaults

To install with custom defaults:

1. First install normally:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/jdpierce21/nas_mount/master/install.sh | bash
   ```

2. Create your defaults file:
   ```bash
   cd ~/scripts/nas_mounts  # or wherever you installed
   cp config/defaults.sh.example config/defaults.sh
   # Edit config/defaults.sh with your settings
   ```

3. Run setup again to use your new defaults:
   ```bash
   ./setup.sh
   ```

The setup will use your custom defaults automatically.

## Migrating from Legacy Location

If you have an existing `~/.nas_mount_defaults` file:

```bash
# Run the migration script
./utils/migrate_defaults.sh
```

This will copy your settings to the new location and optionally remove the old file.

## Checking Current Defaults

To see what defaults are currently in use:

```bash
# Run the show defaults script
./utils/show_defaults.sh
```

This will display:
- All system defaults
- User overrides (if any)
- Active environment variables
- Configuration file locations