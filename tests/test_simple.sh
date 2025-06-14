#!/bin/bash
# Simple test without sourcing issues

set -x  # Enable debug

# Manually load credentials
CRED_FILE="$HOME/.nas_credentials"
if [[ -f "$CRED_FILE" ]]; then
    NAS_USER=$(cut -d'%' -f1 "$CRED_FILE")
    NAS_PASS=$(cut -d'%' -f2- "$CRED_FILE")
    echo "Loaded: user=$NAS_USER, pass=${NAS_PASS:0:3}..."
else
    echo "No credentials file found"
    exit 1
fi

# Load config
if [[ -f "config/config.sh" ]]; then
    source config/config.sh
else
    echo "No config file"
    exit 1
fi

# Test mount
share="${SHARES[0]}"
mount_point="${MOUNT_ROOT}/nas_${share}"

echo "Testing mount:"
echo "  Host: $NAS_HOST"
echo "  Share: $share"
echo "  Mount point: $mount_point"

# Ensure unmounted
umount "$mount_point" 2>/dev/null || true

# Try mount
echo "Mount command: mount_smbfs -N -o nobrowse \"//${NAS_USER}:${NAS_PASS}@${NAS_HOST}/${share}\" \"${mount_point}\""
mount_smbfs -N -o nobrowse "//${NAS_USER}:${NAS_PASS}@${NAS_HOST}/${share}" "${mount_point}"

# Check result
echo "Exit code: $?"
echo "Directory contents:"
ls -la "$mount_point" | head -5