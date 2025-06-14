#!/bin/bash
# Compare script mount vs manual mount

set -euo pipefail

# Load configuration
source config/config.sh
source lib/common.sh
load_credentials

echo "=== Mount Comparison Test ==="
echo ""

# Test share
share="backups"
mount_point="/Users/jpierce/nas_mounts/nas_${share}"

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
echo "   Command: mount_smbfs -N -o nobrowse \"//${NAS_USER}:${NAS_PASS}@${NAS_HOST}/${share}\" \"${mount_point}\""

mount_smbfs -N -o nobrowse "//${NAS_USER}:${NAS_PASS}@${NAS_HOST}/${share}" "${mount_point}"
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