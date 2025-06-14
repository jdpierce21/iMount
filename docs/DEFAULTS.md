# NAS Mount Manager - Configuration Defaults

This document describes how to customize the default values used by the NAS Mount Manager.

## Overview

All hardcoded values in the NAS Mount Manager can be overridden using environment variables. This allows you to customize the behavior without modifying the scripts.

## How to Override Defaults

There are three ways to override default values:

1. **Environment Variables**: Export variables before running the scripts
2. **User Defaults File**: Create `~/.nas_mount_defaults` with your overrides
3. **One-time Override**: Set variables inline when running commands

### Method 1: Environment Variables

```bash
export NAS_MOUNT_DEFAULT_HOST="192.168.1.100"
export NAS_MOUNT_DIR_PREFIX="share_"
./install.sh
```

### Method 2: User Defaults File

Create `~/.nas_mount_defaults`:

```bash
# My custom NAS settings
export NAS_MOUNT_DEFAULT_HOST="192.168.1.100"
export NAS_MOUNT_DIR_PREFIX="share_"
export NAS_MOUNT_DEFAULT_SHARES="documents photos music"
```

This file is automatically sourced by all scripts.

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
# ~/.nas_mount_defaults
export NAS_MOUNT_DEFAULT_HOST="192.168.1.100"
export NAS_MOUNT_DEFAULT_SHARES="shared backup media"
export NAS_MOUNT_DIR_PREFIX="mount_"
```

### Example 2: Custom Installation Path

```bash
# ~/.nas_mount_defaults
export NAS_MOUNT_SCRIPT_DIR="$HOME/bin/nas_mounts"
export NAS_MOUNT_ROOT="/mnt/nas"
```

### Example 3: Using Your Own Fork

```bash
# ~/.nas_mount_defaults
export NAS_MOUNT_GITHUB_USER="myusername"
export NAS_MOUNT_GITHUB_REPO="nas_mount_fork"
export NAS_MOUNT_GITHUB_BRANCH="main"
```

### Example 4: Enhanced Security Options

```bash
# ~/.nas_mount_defaults
export NAS_MOUNT_LINUX_OPTIONS="iocharset=utf8,file_mode=0755,dir_mode=0755,vers=3.0,seal"
export NAS_MOUNT_MACOS_OPTIONS="-N -o nobrowse,soft,noperm"
```

## Installation with Custom Defaults

To install with custom defaults:

1. Create your defaults file:
   ```bash
   cp example_defaults ~/.nas_mount_defaults
   # Edit ~/.nas_mount_defaults with your settings
   ```

2. Run the installer:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/jdpierce21/nas_mount/master/install.sh | bash
   ```

The installer will use your custom defaults automatically.

## Checking Current Defaults

To see what defaults are currently in use:

```bash
# Source the defaults
source lib/defaults.sh

# Display all defaults
env | grep NAS_MOUNT_
```