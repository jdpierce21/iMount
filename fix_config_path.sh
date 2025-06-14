#!/bin/bash
# Script to fix config path issues on macOS

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load output functions
source lib/output.sh

echo "=== Config Path Fix for macOS ==="
echo

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    error "This script is only needed on macOS"
    exit 1
fi

# Check current situation
current_dir="$SCRIPT_DIR"
echo "Current installation directory: $current_dir"

# Check for config in current location
if [[ -f "$current_dir/config/config.sh" ]]; then
    success "Config file found in current location"
    echo "No action needed - your config is in the right place"
    exit 0
fi

# Check alternate locations
found_config=""
for dir in "$HOME/Scripts/nas_mounts" "$HOME/scripts/nas_mounts"; do
    if [[ "$dir" != "$current_dir" ]] && [[ -f "$dir/config/config.sh" ]]; then
        found_config="$dir/config/config.sh"
        echo "Found config at: $found_config"
        break
    fi
done

if [[ -z "$found_config" ]]; then
    error "No config file found"
    message "Please run ./setup.sh to create a new configuration"
    exit 1
fi

# Offer to copy config
echo
if prompt_yn "Copy config to current location?" "Y"; then
    # Create config directory
    mkdir -p "$current_dir/config"
    
    # Copy config file
    cp "$found_config" "$current_dir/config/config.sh"
    
    success "Config file copied successfully"
    echo
    echo "Your config is now at: $current_dir/config/config.sh"
    echo "You can now use ./mount.sh normally"
else
    echo
    echo "Config not copied. You may need to run ./setup.sh"
fi