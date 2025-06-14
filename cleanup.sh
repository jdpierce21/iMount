#!/bin/bash
# Complete removal of NAS mount system

set -uo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Ensure we have proper terminal input
if [[ ! -t 0 ]] && [[ -e /dev/tty ]]; then
    exec < /dev/tty
fi

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
    progress "Unmounting shares"
    # Try graceful unmount first
    bash mount.sh unmount </dev/null >/dev/null 2>&1 || true
    
    # Force unmount any remaining mounts
    mount_root=$(get_mount_root)
    if [[ -d "$mount_root" ]]; then
        # Force unmount all nas_ directories
        for mount_point in "$mount_root"/${MOUNT_DIR_PREFIX}*; do
            if [[ -d "$mount_point" ]] && mount | grep -q " $mount_point "; then
                umount -f "$mount_point" 2>/dev/null || sudo umount -f "$mount_point" 2>/dev/null || true
            fi
        done
    fi
    
    # Check if all unmounted
    if mount | grep -q " $mount_root/${MOUNT_DIR_PREFIX}"; then
        progress_fail
    else
        progress_done
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
        # Get install URL before deleting files
        local install_url
        install_url=$(get_install_url)
        
        # Now remove the directory
        rm -rf "$SCRIPT_DIR"
        
        success "Cleanup complete"
        
        # Offer reinstall
        if prompt_yn "Reinstall NAS mounts?" "Y"; then
            # Change to parent directory before reinstalling
            cd "$(dirname "$SCRIPT_DIR")"
            curl -fsSL "$install_url" | bash
        fi
    else
        # Just remove config
        rm -rf "$(get_config_dir)"
        rm -rf "$(get_log_dir)"
        
        success "Cleanup complete"
    fi
}

main "$@"