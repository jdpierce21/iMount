#!/bin/bash
# Mount/unmount/status operations

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load libraries
source lib/common.sh
source lib/platform.sh

# === Commands ===
cmd_mount() {
    load_config
    load_credentials
    
    local share mount_point mount_cmd
    local failed=0
    
    for share in "${SHARES[@]}"; do
        mount_point="${MOUNT_ROOT}/${MOUNT_DIR_PREFIX}${share}"
        
        # Skip if already mounted
        if is_mounted "$mount_point"; then
            continue
        fi
        
        # Ensure mount point exists
        ensure_dir "$mount_point"
        
        # Get mount command
        mount_cmd=$(get_mount_command "$share" "$mount_point")
        
        # Execute mount
        progress "Mounting $share"
        # Execute directly based on platform to avoid eval quote issues
        if is_macos; then
            if mount_smbfs -N -o nobrowse "//${NAS_USER}:${NAS_PASS}@${NAS_HOST}/${share}" "${mount_point}" >/dev/null 2>&1; then
                progress_done
                log_info "Mounted $share"
            else
                progress_fail
                log_error "Failed to mount $share"
                ((failed++))
            fi
        else
            # Linux mount command
            if sudo mount -t cifs "//${NAS_HOST}/${share}" "${mount_point}" -o "username=${NAS_USER},password=${NAS_PASS},uid=$(id -u),gid=$(id -g),iocharset=utf8,file_mode=0777,dir_mode=0777" >/dev/null 2>&1; then
                progress_done
                log_info "Mounted $share"
            else
                progress_fail
                log_error "Failed to mount $share"
                ((failed++))
            fi
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        success "All shares mounted"
    else
        error "Failed to mount $failed share(s)"
        return 1
    fi
}

cmd_unmount() {
    load_config
    
    local share mount_point unmount_cmd
    local unmounted=0
    
    for share in "${SHARES[@]}"; do
        mount_point="${MOUNT_ROOT}/${MOUNT_DIR_PREFIX}${share}"
        
        # Skip if not mounted
        if ! is_mounted "$mount_point"; then
            continue
        fi
        
        # Get unmount command
        unmount_cmd=$(get_unmount_command "$mount_point")
        
        # Execute unmount
        progress "Unmounting $share"
        # Execute directly based on platform to avoid eval issues
        if is_macos; then
            if umount "${mount_point}" >/dev/null 2>&1; then
                progress_done
                log_info "Unmounted $share"
                ((unmounted++))
            else
                progress_fail
                log_error "Failed to unmount $share"
            fi
        else
            if sudo umount "${mount_point}" >/dev/null 2>&1; then
                progress_done
                log_info "Unmounted $share"
                ((unmounted++))
            else
                progress_fail
                log_error "Failed to unmount $share"
            fi
        fi
    done
    
    if [[ $unmounted -gt 0 ]]; then
        success "Unmounted $unmounted share(s)"
    else
        message "No shares were mounted"
    fi
}

cmd_status() {
    load_config
    
    local share mount_point
    local mounted=0
    local total=0
    
    # Show mount status
    
    for share in "${SHARES[@]}"; do
        mount_point="${MOUNT_ROOT}/${MOUNT_DIR_PREFIX}${share}"
        ((total++))
        
        if is_mounted "$mount_point"; then
            echo "$share → $mount_point $SYMBOL_SUCCESS"
            ((mounted++))
        else
            echo "$share → not mounted $SYMBOL_FAILURE"
        fi
    done
    
    echo ""
    message "$mounted of $total shares mounted"
}

cmd_validate() {
    load_config
    load_credentials
    
    # Start validation
    
    # Check connectivity
    progress "Checking NAS connectivity"
    if ping -c 1 -W 2 "$NAS_HOST" >/dev/null 2>&1; then
        progress_done
    else
        progress_fail
        error "Cannot reach $NAS_HOST"
        return 1
    fi
    
    # Check each mount
    local share mount_point test_file
    local failed=0
    
    for share in "${SHARES[@]}"; do
        mount_point="${MOUNT_ROOT}/${MOUNT_DIR_PREFIX}${share}"
        
        progress "Testing $share"
        
        if ! is_mounted "$mount_point"; then
            progress_fail
            ((failed++))
            continue
        fi
        
        # Try to create test file
        test_file="$mount_point/.nas_mount_test_$$"
        if touch "$test_file" 2>/dev/null && rm -f "$test_file" 2>/dev/null; then
            progress_done
        else
            progress_fail
            ((failed++))
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        success "All mounts healthy"
    else
        error "$failed mount(s) have issues"
        return 1
    fi
}

# === Usage ===
usage() {
    cat <<EOF
Usage: $(basename "$0") <command>

Commands:
    mount      Mount all configured shares
    unmount    Unmount all shares
    status     Show mount status
    validate   Check mount health
EOF
}

# === Main ===
main() {
    local cmd="${1:-}"
    
    case "$cmd" in
        mount) cmd_mount ;;
        unmount) cmd_unmount ;;
        status) cmd_status ;;
        validate) cmd_validate ;;
        *) usage; exit 1 ;;
    esac
}

main "$@"