#!/bin/bash
# Migrate defaults from legacy location to new config/defaults.sh

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

# Load output functions
source lib/output.sh

echo "=== NAS Mount Manager - Defaults Migration ==="
echo ""

# Define locations
legacy_defaults="$HOME/.nas_mount_defaults"
new_defaults="$SCRIPT_DIR/config/defaults.sh"

# Check if legacy file exists
if [[ ! -f "$legacy_defaults" ]]; then
    message "No legacy defaults file found at: $legacy_defaults"
    echo "Nothing to migrate."
    exit 0
fi

# Check if new file already exists
if [[ -f "$new_defaults" ]]; then
    warning "New defaults file already exists at: $new_defaults"
    if ! prompt_yn "Overwrite with contents from legacy file?" "N"; then
        echo "Migration cancelled."
        exit 0
    fi
fi

# Create config directory if needed
mkdir -p "$SCRIPT_DIR/config"

# Copy the file
echo "Copying $legacy_defaults to $new_defaults..."
cp "$legacy_defaults" "$new_defaults"
success "Defaults file copied successfully"

# Show what was migrated
echo ""
echo "Migrated settings:"
grep "^export NAS_MOUNT_" "$new_defaults" | sed 's/^export /  /' || echo "  (none)"

# Offer to remove legacy file
echo ""
if prompt_yn "Remove legacy defaults file?" "Y"; then
    rm "$legacy_defaults"
    success "Legacy file removed"
else
    warning "Legacy file kept at: $legacy_defaults"
    echo "Note: The new location at config/defaults.sh will take precedence"
fi

echo ""
success "Migration complete!"
echo ""
echo "Your defaults are now at: $new_defaults"
echo "This location will be used by all scripts going forward."