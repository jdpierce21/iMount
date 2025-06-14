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
    
    log_info "Starting mount operation for ${#SHARES[@]} shares"
    
    local share mount_point mount_cmd
    local failed=0
    
    for share in "${SHARES[@]}"; do
        mount_point="${MOUNT_ROOT}/${MOUNT_DIR_PREFIX}${share}"
        log_debug "Processing share: $share"
        log_debug "Mount point: $mount_point"
        
        # Check if already mounted and verify it's working
        if is_mounted "$mount_point"; then
            # Test if mount is actually accessible
            if ls "$mount_point" >/dev/null 2>&1; then
                log_info "Share $share already mounted and accessible at $mount_point - skipping"
                continue
            else
                log_info "Share $share has stale mount at $mount_point - unmounting"
                umount "$mount_point" 2>/dev/null || true
            fi
        fi
        
        # Ensure mount point exists
        log_debug "Creating mount point directory: $mount_point"
        ensure_dir "$mount_point"
        
        # Get mount command
        mount_cmd=$(get_mount_command "$share" "$mount_point")
        log_debug "Generated mount command: $mount_cmd"
        
        # Execute mount
        progress "Mounting $share"
        # Execute directly based on platform to avoid eval quote issues
        if is_macos; then
            # Log the exact command for debugging
            log_debug "Mount command: mount_smbfs -N -o nobrowse \"//${NAS_USER}:****@${NAS_HOST}/${share}\" \"${mount_point}\""
            
            # Log before executing
            log_debug "Executing mount for $share"
            log_debug "User: $NAS_USER, Host: $NAS_HOST, Share: $share"
            log_debug "Mount point exists: $(test -d "$mount_point" && echo "yes" || echo "no")"
            
            # Capture mount output for logging
            mount_output=$(mount_smbfs ${DEFAULT_MACOS_MOUNT_OPTIONS} "//${NAS_USER}:${NAS_PASS}@${NAS_HOST}/${share}" "${mount_point}" 2>&1)
            mount_result=$?
            
            log_debug "Mount command returned: $mount_result"
            log_debug "Mount output: $mount_output"
            
            if [[ $mount_result -eq 0 ]]; then
                progress_done
                log_info "Mount command succeeded for $share"
                
                # Verify mount actually worked by checking if it's in mount table
                if mount | grep -q " ${mount_point} "; then
                    log_debug "Mount verified in mount table"
                    
                    # Wait a moment for SMB connection to establish
                    sleep ${DEFAULT_MOUNT_WAIT}
                    
                    # Check if we can access the mount
                    if ls "$mount_point" >/dev/null 2>&1; then
                        local file_count=$(ls -1 "$mount_point" 2>/dev/null | wc -l | tr -d ' ')
                        log_info "Mount accessible: $share has $file_count items"
                        
                        # If no files visible, retry once more
                        if [[ $file_count -eq 0 ]]; then
                            log_debug "No files visible, waiting and retrying..."
                            sleep ${DEFAULT_MOUNT_RETRY_WAIT}
                            file_count=$(ls -1 "$mount_point" 2>/dev/null | wc -l | tr -d ' ')
                            log_info "After retry: $share has $file_count items"
                        fi
                    else
                        log_error "Mount exists but cannot list contents of $share"
                    fi
                else
                    log_error "Mount command succeeded but not found in mount table!"
                fi
            else
                progress_fail
                log_error "Failed to mount $share: exit code $mount_result"
                log_error "Error output: $mount_output"
                ((failed++))
            fi
        else
            # Linux mount command
            mount_output=$(sudo mount -t cifs "//${NAS_HOST}/${share}" "${mount_point}" -o "username=${NAS_USER},password=${NAS_PASS},uid=$(id -u),gid=$(id -g),${DEFAULT_LINUX_MOUNT_OPTIONS}" 2>&1)
            mount_result=$?
            
            if [[ $mount_result -eq 0 ]]; then
                progress_done
                log_info "Mounted $share"
            else
                progress_fail
                log_error "Failed to mount $share: $mount_output"
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
            # Use a timeout function to prevent hanging
            unmount_with_timeout() {
                local mp="$1"
                local timeout="$2"
                local cmd="$3"
                
                # Run command in background
                eval "$cmd" &
                local pid=$!
                
                # Wait for timeout
                local count=0
                while [[ $count -lt $timeout ]]; do
                    if ! kill -0 $pid 2>/dev/null; then
                        # Process finished
                        wait $pid
                        return $?
                    fi
                    sleep 0.1
                    ((count++))
                done
                
                # Timeout reached, kill the process
                kill -9 $pid 2>/dev/null || true
                return 1
            }
            
            # Try unmount strategies with timeouts
            unmounted_this_share=false
            
            # Strategy 1: Normal umount
            log_debug "Trying normal umount for $share"
            if unmount_with_timeout "$mount_point" ${DEFAULT_UNMOUNT_TIMEOUT} "umount \"$mount_point\" 2>/dev/null"; then
                if ! mount | grep -q " ${mount_point} "; then
                    unmounted_this_share=true
                fi
            fi
            
            # Strategy 2: diskutil unmount
            if [[ "$unmounted_this_share" == "false" ]]; then
                log_debug "Trying diskutil unmount for $share"
                if unmount_with_timeout "$mount_point" ${DEFAULT_UNMOUNT_TIMEOUT} "diskutil unmount \"$mount_point\" 2>/dev/null"; then
                    if ! mount | grep -q " ${mount_point} "; then
                        unmounted_this_share=true
                    fi
                fi
            fi
            
            # Strategy 3: Force unmount
            if [[ "$unmounted_this_share" == "false" ]]; then
                log_debug "Trying force unmount for $share"
                unmount_with_timeout "$mount_point" ${DEFAULT_FORCE_UNMOUNT_TIMEOUT} "umount -f \"$mount_point\" 2>/dev/null" || true
                if ! mount | grep -q " ${mount_point} "; then
                    unmounted_this_share=true
                fi
            fi
            
            # Strategy 4: diskutil force
            if [[ "$unmounted_this_share" == "false" ]]; then
                log_debug "Trying diskutil force for $share"
                unmount_with_timeout "$mount_point" ${DEFAULT_FORCE_UNMOUNT_TIMEOUT} "diskutil unmount force \"$mount_point\" 2>/dev/null" || true
                if ! mount | grep -q " ${mount_point} "; then
                    unmounted_this_share=true
                fi
            fi
            
            if [[ "$unmounted_this_share" == "true" ]]; then
                progress_done
                log_info "Unmounted $share"
                ((unmounted++))
            else
                progress_fail
                log_error "Failed to unmount $share (mount might be busy)"
                # Continue to next share instead of hanging
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

cmd_remount() {
    log_info "Force remounting all shares"
    
    # First unmount everything
    cmd_unmount
    
    # Then mount fresh
    cmd_mount
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
        test_file="$mount_point/${DEFAULT_TEST_FILE_PREFIX}$$"
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
    remount    Force remount all shares
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
        remount) cmd_remount ;;
        validate) cmd_validate ;;
        *) usage; exit 1 ;;
    esac
}

main "$@"