#!/bin/bash
# Migrate user defaults from ~/.nas_mount_defaults to config/defaults.sh

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load output functions
source lib/output.sh

# Check if old defaults exist
OLD_DEFAULTS="$HOME/.nas_mount_defaults"
NEW_DEFAULTS="$SCRIPT_DIR/config/defaults.sh"

if [[ ! -f "$OLD_DEFAULTS" ]]; then
    message "No legacy defaults file found at $OLD_DEFAULTS"
    exit 0
fi

message "Found legacy defaults file at: $OLD_DEFAULTS"

# Check if new defaults already exist
if [[ -f "$NEW_DEFAULTS" ]]; then
    error "New defaults file already exists at: $NEW_DEFAULTS"
    
    if prompt_yn "Do you want to view the differences?" "Y"; then
        echo ""
        echo "=== Legacy file ($OLD_DEFAULTS) ==="
        cat "$OLD_DEFAULTS"
        echo ""
        echo "=== Current file ($NEW_DEFAULTS) ==="
        cat "$NEW_DEFAULTS"
        echo ""
    fi
    
    if ! prompt_yn "Overwrite the existing config/defaults.sh?" "N"; then
        message "Migration cancelled"
        exit 0
    fi
fi

# Perform migration
progress "Migrating defaults"
cp "$OLD_DEFAULTS" "$NEW_DEFAULTS"
progress_done

success "Defaults migrated successfully"

if prompt_yn "Delete the old defaults file?" "Y"; then
    rm "$OLD_DEFAULTS"
    message "Old defaults file deleted"
else
    message "Old defaults file kept at: $OLD_DEFAULTS"
    message "Note: The new location takes precedence"
fi

message ""
message "Your defaults are now at: $NEW_DEFAULTS"
message "You can edit this file directly to change default values"