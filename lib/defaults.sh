#!/bin/bash
# Central defaults configuration for NAS Mount Manager
# This file contains all default values that can be overridden by users

# Ensure we don't load twice
[[ -n "${_DEFAULTS_SH_LOADED:-}" ]] && return 0
readonly _DEFAULTS_SH_LOADED=1

# === Network/Connection Defaults ===
# Default NAS host IP address
: ${DEFAULT_NAS_HOST:="${NAS_MOUNT_DEFAULT_HOST:-192.168.54.249}"}

# Default SMB port
: ${DEFAULT_SMB_PORT:="${NAS_MOUNT_SMB_PORT:-445}"}

# === Directory Structure Defaults ===
# Mount directory prefix (prepended to share names)
: ${DEFAULT_MOUNT_DIR_PREFIX:="${NAS_MOUNT_DIR_PREFIX:-nas_}"}

# Config directory name (relative to script directory)
: ${DEFAULT_CONFIG_DIR_NAME:="${NAS_MOUNT_CONFIG_DIR:-config}"}

# Log directory name (relative to script directory)
: ${DEFAULT_LOG_DIR_NAME:="${NAS_MOUNT_LOG_DIR:-logs}"}

# Default mount root location
: ${DEFAULT_MOUNT_ROOT:="${NAS_MOUNT_ROOT:-$HOME/nas_mounts}"}

# === File Name Defaults ===
# Credentials file name (stored in home directory)
: ${DEFAULT_CREDENTIALS_FILENAME:="${NAS_MOUNT_CREDENTIALS_FILE:-.nas_credentials}"}

# Config file name (stored in config directory)
: ${DEFAULT_CONFIG_FILENAME:="${NAS_MOUNT_CONFIG_FILE:-config.sh}"}

# Log file name (stored in log directory)
: ${DEFAULT_LOG_FILENAME:="${NAS_MOUNT_LOG_FILE:-nas_mount.log}"}

# === Service Name Defaults ===
# macOS LaunchAgent name
: ${DEFAULT_LAUNCHAGENT_NAME:="${NAS_MOUNT_LAUNCHAGENT:-com.jpierce.nas-mounts}"}

# Linux systemd service name
: ${DEFAULT_SYSTEMD_SERVICE_NAME:="${NAS_MOUNT_SYSTEMD_SERVICE:-nas-mounts}"}

# === Default Share List ===
# Space-separated list of default shares
: ${DEFAULT_SHARES:="${NAS_MOUNT_DEFAULT_SHARES:-backups documents media notes PacificRim photos}"}

# === GitHub Repository Defaults ===
# GitHub username
: ${DEFAULT_GITHUB_USER:="${NAS_MOUNT_GITHUB_USER:-jdpierce21}"}

# GitHub repository name
: ${DEFAULT_GITHUB_REPO:="${NAS_MOUNT_GITHUB_REPO:-nas_mount}"}

# GitHub branch
: ${DEFAULT_GITHUB_BRANCH:="${NAS_MOUNT_GITHUB_BRANCH:-master}"}

# === Mount Options Defaults ===
# macOS mount options
: ${DEFAULT_MACOS_MOUNT_OPTIONS:="${NAS_MOUNT_MACOS_OPTIONS:--N -o nobrowse}"}

# Linux mount options (template - uid/gid will be added dynamically)
: ${DEFAULT_LINUX_MOUNT_OPTIONS:="${NAS_MOUNT_LINUX_OPTIONS:-iocharset=utf8,file_mode=0777,dir_mode=0777}"}

# === Timeout Defaults ===
# Normal unmount timeout (in deciseconds - 30 = 3 seconds)
: ${DEFAULT_UNMOUNT_TIMEOUT:="${NAS_MOUNT_UNMOUNT_TIMEOUT:-30}"}

# Force unmount timeout (in deciseconds - 20 = 2 seconds)
: ${DEFAULT_FORCE_UNMOUNT_TIMEOUT:="${NAS_MOUNT_FORCE_UNMOUNT_TIMEOUT:-20}"}

# Mount verification wait time (seconds)
: ${DEFAULT_MOUNT_WAIT:="${NAS_MOUNT_WAIT:-1}"}

# Mount retry wait time (seconds)
: ${DEFAULT_MOUNT_RETRY_WAIT:="${NAS_MOUNT_RETRY_WAIT:-2}"}

# === Installation Defaults ===
# Default script directory name based on OS
get_default_script_dir() {
    local os_type="$1"
    if [[ "$os_type" == "macos" ]]; then
        # Check if lowercase scripts directory already exists
        if [[ -d "$HOME/scripts/nas_mounts" ]]; then
            echo "$HOME/scripts/nas_mounts"
        else
            echo "${NAS_MOUNT_SCRIPT_DIR:-$HOME/Scripts/nas_mounts}"}
        fi
    else
        echo "${NAS_MOUNT_SCRIPT_DIR:-$HOME/scripts/nas_mounts}"}
    fi
}

# === Debug/Test Defaults ===
# Debug log retention count
: ${DEFAULT_DEBUG_LOG_RETENTION:="${NAS_MOUNT_DEBUG_LOG_RETENTION:-10}"}

# Test file prefix
: ${DEFAULT_TEST_FILE_PREFIX:="${NAS_MOUNT_TEST_FILE_PREFIX:-.nas_mount_test_}"}

# === Usage Information ===
# To override any default value, export the corresponding environment variable
# before running the scripts. For example:
#
# export NAS_MOUNT_DEFAULT_HOST="192.168.1.100"
# export NAS_MOUNT_DIR_PREFIX="share_"
# export NAS_MOUNT_DEFAULT_SHARES="documents photos music"
#
# You can also create a file ~/.nas_mount_defaults and source it:
# export NAS_MOUNT_DEFAULT_HOST="192.168.1.100"
# export NAS_MOUNT_DIR_PREFIX="share_"

# Source user defaults if they exist
if [[ -f "$HOME/.nas_mount_defaults" ]]; then
    source "$HOME/.nas_mount_defaults"
fi