#!/bin/bash

###############################################################################
# File: mount_nas_shares.sh
# Date: 2025-06-13
# Version: 5.0.0
# Description: Cross-platform NAS mount script with system-style logging
###############################################################################

# === Load Configuration ===
# Determine script directory dynamically
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"
source "$CONFIG_FILE"

# === Load Shared Functions ===
PROCESS_NAME="mount_nas_shares"  # Set before sourcing shared functions
source "$SCRIPT_DIR/shared_functions.sh"

# === Create Required Directories ===
mkdir -p "$LOG_DIR"
mkdir -p "$MOUNT_ROOT"
LOG_FILE="$LOG_DIR/nas_mount.log"

# === Validate and Parse Credentials ===
if ! parse_credentials; then
    echo ""
    echo "Please create credentials file with: echo 'username%password' > $CREDENTIALS_FILE"
    echo "Then set permissions with: chmod 600 $CREDENTIALS_FILE"
    echo ""
    echo "Or run ./setup_nas_mount.sh to configure everything automatically."
    exit 1
fi

# === Check connectivity ===
if ! check_nas_connectivity; then
    error "Cannot reach NAS at $NAS_HOST"
    exit 1
fi

log "Starting NAS mount process for host $NAS_HOST on $OS_TYPE"

# === Mount Function ===
mount_share() {
    local share="$1"
    local target=$(get_mount_path "$share")
    
    # Check if already mounted
    if is_mounted "$target"; then
        log "Share $share is already mounted at $target"
        return 0
    fi
    
    # Create mount point if needed
    if [[ ! -d "$target" ]]; then
        mkdir -p "$target"
        log "Created mount point: $target"
    else
        # Check if directory is empty (unmounted)
        if [[ -n "$(ls -A "$target" 2>/dev/null)" ]]; then
            # Directory has contents but not mounted - clean it
            if ! is_mounted "$target"; then
                log "Cleaning stale mount point: $target"
                rm -rf "$target"
                mkdir -p "$target"
            fi
        fi
    fi
    
    # Get platform-specific mount command
    local mount_cmd=$(get_mount_command "$share" "$target")
    
    # Attempt mount
    log "Mounting $share..."
    if eval "$mount_cmd" 2>>"$ERROR_FILE"; then
        log "Successfully mounted $share"
        return 0
    else
        error "Failed to mount $share"
        # Clean up failed mount point
        rmdir "$target" 2>/dev/null
        return 1
    fi
}

# === Unmount Function ===
unmount_share() {
    local share="$1"
    local target=$(get_mount_path "$share")
    
    if is_mounted "$target"; then
        log "Unmounting $share..."
        
        # Get platform-specific unmount command
        local unmount_cmd=$(get_unmount_command "$target")
        
        if eval "$unmount_cmd" 2>>"$ERROR_FILE"; then
            log "Unmounted $share"
            rmdir "$target" 2>/dev/null
            return 0
        else
            error "Failed to unmount $share"
            return 1
        fi
    else
        log "Share $share is not mounted"
        return 0
    fi
}

# === Clean Old Logs Function ===
clean_old_logs() {
    log "Performing log maintenance"
    
    # Clean rotated logs beyond MAX_ROTATED_LOGS
    for log_type in "$LOG_FILE" "$ERROR_FILE"; do
        for ((i=$((MAX_ROTATED_LOGS+1)); i<=20; i++)); do
            if [[ -f "${log_type}.${i}" ]]; then
                rm -f "${log_type}.${i}"
                log "Removed old log: ${log_type}.${i}"
            fi
        done
    done
}

# === Main Logic ===
case "${1:-mount}" in
    mount)
        # Clean logs on startup
        clean_old_logs
        
        SUCCESS=0
        FAILED=0
        
        for share in "${SHARES[@]}"; do
            if mount_share "$share"; then
                ((SUCCESS++))
            else
                ((FAILED++))
            fi
        done
        
        log "Mount complete: $SUCCESS successful, $FAILED failed"
        
        if [[ $FAILED -gt 0 ]]; then
            exit 1
        fi
        ;;
        
    unmount|umount)
        for share in "${SHARES[@]}"; do
            unmount_share "$share"
        done
        log "Unmount complete"
        ;;
        
    status)
        log "Checking mount status..."
        echo "Platform: $OS_TYPE"
        echo "NAS Host: $NAS_HOST"
        echo ""
        
        for share in "${SHARES[@]}"; do
            target=$(get_mount_path "$share")
            if is_mounted "$share"; then
                echo "✅ $share is mounted at $target"
            else
                echo "❌ $share is not mounted"
            fi
        done
        ;;
        
    clean-logs)
        clean_old_logs
        log "Log maintenance complete"
        ;;
        
    *)
        echo "Usage: $0 [mount|unmount|status|clean-logs]"
        echo ""
        echo "Commands:"
        echo "  mount       - Mount all configured NAS shares (default)"
        echo "  unmount     - Unmount all NAS shares"
        echo "  status      - Show current mount status"
        echo "  clean-logs  - Clean up old rotated logs"
        echo ""
        echo "Platform: $OS_TYPE"
        exit 1
        ;;
esac