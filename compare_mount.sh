#!/bin/bash
# Compare script mount vs manual mount

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load configuration
source lib/common.sh
source lib/platform.sh
load_config
load_credentials

echo "=== Mount Comparison Test ==="
echo ""

# Test with first configured share
if [[ ${#SHARES[@]} -eq 0 ]]; then
    echo "No shares configured!"
    exit 1
fi

share="${SHARES[0]}"
mount_point="$(get_mount_root)/${MOUNT_DIR_PREFIX}${share}"

echo "Configuration:"
echo "  NAS_HOST: $NAS_HOST"
echo "  NAS_USER: $NAS_USER"
echo "  Share: $share"
echo "  Mount point: $mount_point"
echo ""

# First ensure it's unmounted
echo "1. Ensuring share is unmounted..."
if mount | grep -q " ${mount_point} "; then
    umount "$mount_point" 2>/dev/null || sudo umount "$mount_point" 2>/dev/null || true
fi

# Try script method
echo ""
echo "2. Testing script mount method:"
mount_cmd=$(get_mount_command "$share" "$mount_point")
echo "   Command: ${mount_cmd//$NAS_PASS/****}"

if is_macos; then
    mount_smbfs -N -o nobrowse "//${NAS_USER}:${NAS_PASS}@${NAS_HOST}/${share}" "${mount_point}"
else
    sudo mount -t cifs "//${NAS_HOST}/${share}" "${mount_point}" -o "username=${NAS_USER},password=${NAS_PASS},uid=$(id -u),gid=$(id -g),iocharset=utf8,file_mode=0777,dir_mode=0777"
fi
result=$?

echo "   Exit code: $result"

if mount | grep -q " ${mount_point} "; then
    echo "   ✓ Mount shows in mount table"
    echo "   Directory contents:"
    ls -la "$mount_point" | head -5
    
    # Test write
    test_file="${mount_point}/.test_$$"
    if touch "$test_file" 2>/dev/null; then
        echo "   ✓ Write test successful"
        rm -f "$test_file"
    else
        echo "   ✗ Write test failed"
    fi
else
    echo "   ✗ Mount NOT in mount table"
fi

echo ""
echo "3. Mount table entry:"
mount | grep "${mount_point}" || echo "   No entry found"

echo ""
echo "=== End Comparison Test ==="