#!/bin/bash
# Complete removal of NAS mount system

set -uo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load libraries
source lib/common.sh
source lib/platform.sh

# === Main cleanup ===
main() {
    # Move to safe directory first (in case we're in the script directory)
    cd "$HOME" || true
    
    # Start cleanup process
    if ! prompt_yn "This will remove all configurations. Continue?" "Y"; then
        message "Cleanup cancelled"
        exit 0
    fi
    
    # Unmount shares
    if [[ -f "$(get_config_file)" ]]; then
        progress "Unmounting shares"
        if bash mount.sh unmount </dev/null >/dev/null 2>&1; then
            progress_done
        else
            progress_fail
        fi
    fi
    
    # Remove auto-mount service
    progress "Removing auto-mount"
    remove_auto_mount_service
    progress_done
    
    # Remove shell aliases
    progress "Removing aliases"
    remove_shell_aliases
    progress_done
    
    # Handle credentials
    local cred_file
    cred_file=$(get_credentials_file)
    if [[ -f "$cred_file" ]]; then
        if prompt_yn "Delete saved credentials?" "N"; then
            rm -f "$cred_file"
        fi
    fi
    # Handle mount directories  
    local config_file
    config_file=$(get_config_file)
    if [[ -f "$config_file" ]]; then
        # Extract MOUNT_ROOT without sourcing the file
        local mount_root
        mount_root=$(grep "^MOUNT_ROOT=" "$config_file" | cut -d'"' -f2)
        if [[ -n "$mount_root" ]] && [[ -d "$mount_root" ]]; then
            # Remove ALL mount directories (not just empty ones)
            rm -rf "$mount_root"/${MOUNT_DIR_PREFIX}* 2>/dev/null || true
            # Try to remove mount root if empty
            rmdir "$mount_root" 2>/dev/null || true
        fi
    fi
    # Handle script directory
    if prompt_yn "Remove script directory?" "Y"; then
        rm -rf "$SCRIPT_DIR"
        
        success "Cleanup complete"
        
        # Offer reinstall
        if prompt_yn "Reinstall NAS mounts?" "Y"; then
            # Change to parent directory before reinstalling
            cd "$(dirname "$SCRIPT_DIR")"
            curl -fsSL "$(get_install_url)" | bash
        fi
    else
        # Just remove config
        rm -rf "$(get_config_dir)"
        rm -rf "$(get_log_dir)"
        
        success "Cleanup complete"
    fi
}

main "$@"