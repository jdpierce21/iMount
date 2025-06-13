#!/bin/bash

###############################################################################
# File: validate_mounts.sh
# Date: 2025-06-12
# Version: 3.2.0
# Description: Validates that NAS shares are mounted and accessible.
###############################################################################

# === Load Configuration ===
# Determine script directory dynamically
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"
source "$CONFIG_FILE"

# === Load Shared Functions ===
PROCESS_NAME="validate_nas_mounts"
source "$SCRIPT_DIR/shared_functions.sh"

# === Validation ===
log "Validating NAS mount accessibility..."

MISSING_MOUNTS=()
for SHARE in "${SHARES[@]}"; do
  MOUNT_PATH=$(get_mount_path "$SHARE")

  if [[ -d "$MOUNT_PATH" ]] && is_mounted "$SHARE"; then
    log "✅ $SHARE mounted at $MOUNT_PATH"
  else
    error "❌ $SHARE is not mounted properly at $MOUNT_PATH"
    MISSING_MOUNTS+=("$SHARE")
  fi

done

if [[ ${#MISSING_MOUNTS[@]} -eq 0 ]]; then
  log "🎉 All NAS shares validated successfully."
else
  error "⚠️  ${#MISSING_MOUNTS[@]} mount(s) failed: ${MISSING_MOUNTS[*]}"
  exit 1
fi
