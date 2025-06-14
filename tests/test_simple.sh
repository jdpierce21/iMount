#!/bin/bash
# Simple test without full library dependencies

set -x  # Enable debug

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

# Detect OS
case "$OSTYPE" in
    darwin*) IS_MACOS=true ;;
    linux*) IS_MACOS=false ;;
    *) echo "Unsupported OS"; exit 1 ;;
esac

# Manually load credentials
CRED_FILE="$HOME/.nas_credentials"
if [[ -f "$CRED_FILE" ]]; then
    if [[ "$IS_MACOS" == "true" ]]; then
        # macOS format: user%pass
        NAS_USER=$(cut -d'%' -f1 "$CRED_FILE")
        NAS_PASS=$(cut -d'%' -f2- "$CRED_FILE")
    else
        # Linux format: username=user\npassword=pass
        NAS_USER=$(grep "^username=" "$CRED_FILE" | cut -d'=' -f2-)
        NAS_PASS=$(grep "^password=" "$CRED_FILE" | cut -d'=' -f2-)
    fi
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
if [[ "$IS_MACOS" == "true" ]]; then
    echo "Mount command: mount_smbfs -N -o nobrowse \"//${NAS_USER}:${NAS_PASS}@${NAS_HOST}/${share}\" \"${mount_point}\""
    mount_smbfs -N -o nobrowse "//${NAS_USER}:${NAS_PASS}@${NAS_HOST}/${share}" "${mount_point}"
else
    echo "Mount command: sudo mount -t cifs \"//${NAS_HOST}/${share}\" \"${mount_point}\" -o \"username=${NAS_USER},password=${NAS_PASS},uid=$(id -u),gid=$(id -g)\""
    sudo mount -t cifs "//${NAS_HOST}/${share}" "${mount_point}" -o "username=${NAS_USER},password=${NAS_PASS},uid=$(id -u),gid=$(id -g),iocharset=utf8,file_mode=0777,dir_mode=0777"
fi

# Check result
echo "Exit code: $?"
echo "Directory contents:"
ls -la "$mount_point" | head -5