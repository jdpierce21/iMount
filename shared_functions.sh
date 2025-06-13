#!/bin/bash

###############################################################################
# File: shared_functions.sh
# Date: 2025-06-13
# Version: 1.0.0
# Description: Shared functions for NAS mount scripts
###############################################################################

# === Ensure credentials exist ===
# Usage: ensure_credentials [username] [password]
# If username and password are provided, saves them
# Otherwise prompts user if file doesn't exist
ensure_credentials() {
    local username="$1"
    local password="$2"
    
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        return 0  # Credentials already exist
    fi
    
    # If credentials provided as arguments, use them
    if [[ -n "$username" && -n "$password" ]]; then
        echo "${username}%${password}" > "$CREDENTIALS_FILE"
        chmod 600 "$CREDENTIALS_FILE"
        echo "✅ Credentials saved to $CREDENTIALS_FILE"
        return 0
    fi
    
    # Otherwise prompt for credentials
    echo "Creating NAS credentials file (will be stored as username%password)..."
    read -p "Enter your NAS username: " username
    read -s -p "Enter your NAS password: " password
    echo ""
    echo "${username}%${password}" > "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE"
    echo "✅ Credentials saved to $CREDENTIALS_FILE"
}

# === Logging Configuration ===
MAX_LOG_SIZE=$((10 * 1024 * 1024))  # 10MB
MAX_ROTATED_LOGS=5
HOSTNAME=$(hostname -s)
PROCESS_NAME="${PROCESS_NAME:-nas_mount}"
PID=$$

# === Log Rotation Function ===
rotate_log() {
    local log_file="$1"
    
    # Check if log exists and is too large
    if [[ -f "$log_file" ]] && [[ $(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null) -gt $MAX_LOG_SIZE ]]; then
        # Remove oldest rotated log if we have too many
        if [[ -f "${log_file}.${MAX_ROTATED_LOGS}" ]]; then
            rm -f "${log_file}.${MAX_ROTATED_LOGS}"
        fi
        
        # Rotate existing logs
        for ((i=$((MAX_ROTATED_LOGS-1)); i>0; i--)); do
            if [[ -f "${log_file}.${i}" ]]; then
                mv "${log_file}.${i}" "${log_file}.$((i+1))"
            fi
        done
        
        # Move current log to .1
        mv "$log_file" "${log_file}.1"
        
        # Create new empty log file
        touch "$log_file"
    fi
}

# === System-Style Logging Functions ===
syslog() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%b %d %H:%M:%S')
    local log_entry="$timestamp $HOSTNAME $PROCESS_NAME[$PID]: $level: $message"
    
    # Rotate logs if needed
    rotate_log "$LOG_FILE"
    
    # Write to log
    echo "$log_entry" >> "$LOG_FILE"
    
    # Also output to console
    echo "$log_entry"
}

log() {
    syslog "INFO" "$1"
}

error() {
    local message="$1"
    local timestamp=$(date '+%b %d %H:%M:%S')
    local log_entry="$timestamp $HOSTNAME $PROCESS_NAME[$PID]: ERROR: $message"
    local error_file="${LOG_DIR}/nas_mount.err"
    
    # Rotate error log if needed
    rotate_log "$error_file"
    
    # Write to both logs
    echo "$log_entry" >> "$error_file"
    echo "$log_entry" >> "$LOG_FILE"
    
    # Output to stderr
    echo "$log_entry" >&2
}

# === Check NAS connectivity ===
# Usage: check_nas_connectivity
# Returns 0 if reachable, 1 if not
check_nas_connectivity() {
    if ping -c 1 -W 2 "$NAS_HOST" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# === Add shell aliases ===
# Usage: add_shell_aliases
add_shell_aliases() {
    local shell_rc=""
    
    if [[ -f "$HOME/.bashrc" ]]; then
        shell_rc="$HOME/.bashrc"
    elif [[ -f "$HOME/.zshrc" ]]; then
        shell_rc="$HOME/.zshrc"
    fi
    
    if [[ -n "$shell_rc" ]]; then
        # Check if aliases already exist
        if ! grep -q "alias nas-mount" "$shell_rc"; then
            echo "" >> "$shell_rc"
            echo "# NAS mount aliases" >> "$shell_rc"
            echo "alias nas-mount='$MOUNT_SCRIPT mount'" >> "$shell_rc"
            echo "alias nas-unmount='$MOUNT_SCRIPT unmount'" >> "$shell_rc"
            echo "alias nas-status='$MOUNT_SCRIPT status'" >> "$shell_rc"
            echo "✅ Added aliases to $shell_rc"
            echo "Run 'source $shell_rc' to activate aliases in current shell"
        else
            echo "ℹ️  Aliases already exist in $shell_rc"
        fi
    fi
}

# === Create mount directories ===
# Usage: create_mount_directories [--force]
create_mount_directories() {
    local force_replace=false
    [[ "$1" == "--force" ]] && force_replace=true
    
    mkdir -p "$MOUNT_ROOT"
    
    for share in "${SHARES[@]}"; do
        local target="$MOUNT_ROOT/nas_${share}"
        
        if [[ -d "$target" && $force_replace == true ]]; then
            if [[ "$OS_TYPE" == "linux" ]]; then
                sudo umount "$target" 2>/dev/null
            else
                umount "$target" 2>/dev/null
            fi
            rm -rf "$target"
        fi
        
        mkdir -p "$target"
        log "📂 Ensured directory for nas_${share}"
    done
}

# === Get mount path for a share ===
# Usage: get_mount_path "share_name"
# Returns: the full mount path for the share
get_mount_path() {
    local share="$1"
    echo "$MOUNT_ROOT/nas_${share}"
}

# === Parse credentials ===
# Usage: parse_credentials
# Sets: NAS_USER and NAS_PASS global variables
parse_credentials() {
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        error "Credentials file not found at $CREDENTIALS_FILE"
        return 1
    fi
    
    NAS_USER=$(cut -d'%' -f1 "$CREDENTIALS_FILE")
    NAS_PASS=$(cut -d'%' -f2- "$CREDENTIALS_FILE")
}

# === Check if share is mounted ===
# Usage: is_mounted "share_name" or is_mounted "/path/to/mount"
# Returns: 0 if mounted, 1 if not
is_mounted() {
    local target="$1"
    
    # If it's a share name, convert to path
    if [[ ! "$target" =~ ^/ ]]; then
        target=$(get_mount_path "$target")
    fi
    
    if [[ "$OS_TYPE" == "macos" ]]; then
        mount | grep -q "$target"
    elif [[ "$OS_TYPE" == "linux" ]]; then
        findmnt -n "$target" >/dev/null 2>&1
    fi
}

# === Get platform-specific mount command ===
# Usage: get_mount_command "share" "target"
get_mount_command() {
    local share="$1"
    local target="$2"
    
    # Ensure credentials are parsed
    [[ -z "$NAS_USER" ]] && parse_credentials
    
    if [[ "$OS_TYPE" == "macos" ]]; then
        echo "mount_smbfs -N -o nobrowse \"//$NAS_USER:$NAS_PASS@$NAS_HOST/$share\" \"$target\""
    elif [[ "$OS_TYPE" == "linux" ]]; then
        echo "sudo mount -t cifs \"//$NAS_HOST/$share\" \"$target\" -o username=$NAS_USER,password=$NAS_PASS,uid=$(id -u),gid=$(id -g),iocharset=utf8,file_mode=0777,dir_mode=0777"
    fi
}

# === Get platform-specific unmount command ===
# Usage: get_unmount_command "target"
get_unmount_command() {
    local target="$1"
    
    if [[ "$OS_TYPE" == "macos" ]]; then
        echo "umount \"$target\""
    elif [[ "$OS_TYPE" == "linux" ]]; then
        echo "sudo umount \"$target\""
    fi
}