#!/bin/bash
# Test mount script for debugging mount issues

set -x  # Enable debug output

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

# Load the configuration
source config/config.sh
source lib/common.sh
source lib/platform.sh

# Load credentials properly
load_credentials

# Test variables
echo "NAS_HOST: $NAS_HOST"
echo "NAS_USER: $NAS_USER"
echo "NAS_PASS: ${NAS_PASS:0:3}...${NAS_PASS: -3}"
echo "First share: ${SHARES[0]}"
echo "Mount root: $MOUNT_ROOT"

# Test mount point
MOUNT_POINT="${MOUNT_ROOT}/nas_${SHARES[0]}"
echo "Mount point: $MOUNT_POINT"

# Check if already mounted
if mount | grep -q " ${MOUNT_POINT} "; then
    echo "Already mounted, unmounting first..."
    umount "$MOUNT_POINT"
fi

# Try mounting with full error output
echo "Attempting mount..."
if is_macos; then
    mount_smbfs -N -o nobrowse "//${NAS_USER}:${NAS_PASS}@${NAS_HOST}/${SHARES[0]}" "${MOUNT_POINT}"
else
    sudo mount -t cifs "//${NAS_HOST}/${SHARES[0]}" "${MOUNT_POINT}" -o "username=${NAS_USER},password=${NAS_PASS},uid=$(id -u),gid=$(id -g),iocharset=utf8,file_mode=0777,dir_mode=0777"
fi
RESULT=$?

echo "Mount command exit code: $RESULT"

# Check if mounted
if mount | grep -q " ${MOUNT_POINT} "; then
    echo "Mount successful!"
    ls -la "$MOUNT_POINT"
else
    echo "Mount failed!"
fi