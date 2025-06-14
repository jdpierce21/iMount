#!/bin/bash
# Diagnostic script to check configuration paths

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load libraries
source lib/common.sh

echo "=== NAS Mount Configuration Check ==="
echo
echo "Script Information:"
echo "  Current directory: $PWD"
echo "  SCRIPT_DIR: $SCRIPT_DIR"
echo

echo "Path Functions:"
echo "  get_script_dir(): $(get_script_dir)"
echo "  get_config_dir(): $(get_config_dir)"
echo "  get_config_file(): $(get_config_file)"
echo "  get_credentials_file(): $(get_credentials_file)"
echo "  get_mount_root(): $(get_mount_root)"
echo

echo "File Status:"
config_file=$(get_config_file)
if [[ -f "$config_file" ]]; then
    echo "  Config file: EXISTS at $config_file"
    echo "  Config contents:"
    sed 's/^/    /' "$config_file"
else
    echo "  Config file: NOT FOUND at $config_file"
fi

echo

cred_file=$(get_credentials_file)
if [[ -f "$cred_file" ]]; then
    echo "  Credentials file: EXISTS at $cred_file"
else
    echo "  Credentials file: NOT FOUND at $cred_file"
fi

echo

# Check for config in common alternate locations
echo "Checking alternate locations:"
for dir in "$HOME/Scripts/nas_mounts" "$HOME/scripts/nas_mounts"; do
    if [[ -d "$dir" ]]; then
        echo "  Directory $dir: EXISTS"
        if [[ -f "$dir/config/config.sh" ]]; then
            echo "    Config found at: $dir/config/config.sh"
        fi
    else
        echo "  Directory $dir: NOT FOUND"
    fi
done