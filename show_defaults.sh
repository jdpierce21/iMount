#!/bin/bash
# Show current NAS Mount Manager defaults

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load libraries
source lib/defaults.sh

echo "=== NAS Mount Manager - Current Defaults ==="
echo ""

echo "Network Configuration:"
echo "  Default NAS Host: $DEFAULT_NAS_HOST"
echo "  SMB Port: $DEFAULT_SMB_PORT"
echo ""

echo "Directory Structure:"
echo "  Mount Directory Prefix: $DEFAULT_MOUNT_DIR_PREFIX"
echo "  Config Directory: $DEFAULT_CONFIG_DIR_NAME"
echo "  Log Directory: $DEFAULT_LOG_DIR_NAME"
echo "  Default Mount Root: $DEFAULT_MOUNT_ROOT"
echo "  Default Script Directory (macOS): $(get_default_script_dir "macos")"
echo "  Default Script Directory (Linux): $(get_default_script_dir "linux")"
echo ""

echo "File Names:"
echo "  Credentials File: $DEFAULT_CREDENTIALS_FILENAME"
echo "  Config File: $DEFAULT_CONFIG_FILENAME"
echo "  Log File: $DEFAULT_LOG_FILENAME"
echo ""

echo "Service Names:"
echo "  LaunchAgent Name: $DEFAULT_LAUNCHAGENT_NAME"
echo "  Systemd Service Name: $DEFAULT_SYSTEMD_SERVICE_NAME"
echo ""

echo "Default Shares:"
echo "  $DEFAULT_SHARES"
echo ""

echo "GitHub Repository:"
echo "  User: $DEFAULT_GITHUB_USER"
echo "  Repo: $DEFAULT_GITHUB_REPO"
echo "  Branch: $DEFAULT_GITHUB_BRANCH"
echo ""

echo "Mount Options:"
echo "  macOS: $DEFAULT_MACOS_MOUNT_OPTIONS"
echo "  Linux: $DEFAULT_LINUX_MOUNT_OPTIONS"
echo ""

echo "Timeouts:"
echo "  Unmount Timeout: ${DEFAULT_UNMOUNT_TIMEOUT} deciseconds"
echo "  Force Unmount Timeout: ${DEFAULT_FORCE_UNMOUNT_TIMEOUT} deciseconds"
echo "  Mount Wait: ${DEFAULT_MOUNT_WAIT} seconds"
echo "  Mount Retry Wait: ${DEFAULT_MOUNT_RETRY_WAIT} seconds"
echo ""

echo "Miscellaneous:"
echo "  Debug Log Retention: $DEFAULT_DEBUG_LOG_RETENTION logs"
echo "  Test File Prefix: $DEFAULT_TEST_FILE_PREFIX"
echo ""

# Check for user defaults in both locations
echo "=== User Defaults Files ==="
local_defaults="$SCRIPT_DIR/config/defaults.sh"
legacy_defaults="$HOME/.nas_mount_defaults"
defaults_found=false

if [[ -f "$local_defaults" ]]; then
    echo "Location: $local_defaults (ACTIVE)"
    echo "Overrides:"
    grep "^export NAS_MOUNT_" "$local_defaults" | sed 's/^export /  /' || echo "  (none)"
    echo ""
    defaults_found=true
fi

if [[ -f "$legacy_defaults" ]]; then
    if [[ "$defaults_found" == "true" ]]; then
        echo "Legacy location: $legacy_defaults (IGNORED - config/defaults.sh takes precedence)"
    else
        echo "Legacy location: $legacy_defaults (ACTIVE)"
        echo "Overrides:"
        grep "^export NAS_MOUNT_" "$legacy_defaults" | sed 's/^export /  /' || echo "  (none)"
    fi
    echo "Note: Consider moving this file to $local_defaults"
    echo ""
    defaults_found=true
fi

if [[ "$defaults_found" == "false" ]]; then
    echo "  (none found)"
    echo "  To customize defaults, copy config/defaults.sh.example to config/defaults.sh"
    echo ""
fi

echo "=== Active Environment Overrides ==="
env | grep "^NAS_MOUNT_" | sort | sed 's/^/  /' || echo "  (none)"