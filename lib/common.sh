#!/bin/bash
# Common functions and constants - no duplication allowed

# Ensure we don't load twice
[[ -n "${_COMMON_SH_LOADED:-}" ]] && return 0
readonly _COMMON_SH_LOADED=1

# Load output functions first
source "$(dirname "${BASH_SOURCE[0]}")/output.sh"

# Load defaults
source "$(dirname "${BASH_SOURCE[0]}")/defaults.sh"

# === Constants ===
# GitHub configuration
readonly GITHUB_USER="${DEFAULT_GITHUB_USER}"
readonly GITHUB_REPO="${DEFAULT_GITHUB_REPO}"
readonly GITHUB_BRANCH="${DEFAULT_GITHUB_BRANCH}"
readonly GITHUB_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
readonly GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

# File names
readonly CREDENTIALS_FILENAME="${DEFAULT_CREDENTIALS_FILENAME}"
readonly CONFIG_FILENAME="${DEFAULT_CONFIG_FILENAME}"
readonly MOUNT_DIR_PREFIX="${DEFAULT_MOUNT_DIR_PREFIX}"

# Platform-specific service names
readonly LAUNCHAGENT_NAME="${DEFAULT_LAUNCHAGENT_NAME}"
readonly SYSTEMD_SERVICE_NAME="${DEFAULT_SYSTEMD_SERVICE_NAME}"

# Default values for setup
readonly DEFAULT_NAS_HOST="${DEFAULT_NAS_HOST}"
readonly DEFAULT_SHARES="${DEFAULT_SHARES}"

# === Path Functions ===
# All paths derived from these functions - no hardcoding

get_os_type() {
    case "$OSTYPE" in
        darwin*) echo "macos" ;;
        linux-gnu*) echo "linux" ;;
        *) die "Unsupported OS: $OSTYPE" ;;
    esac
}

get_script_dir() {
    # Try to find the actual script directory dynamically
    # First check if we have SCRIPT_DIR set (from calling script)
    if [[ -n "${SCRIPT_DIR:-}" ]]; then
        echo "$SCRIPT_DIR"
        return
    fi
    
    # Try to find based on this library file's location
    local lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -d "$lib_dir" ]] && [[ "$(basename "$lib_dir")" == "lib" ]]; then
        echo "$(dirname "$lib_dir")"
        return
    fi
    
    # Fall back to OS-specific defaults using the defaults function
    local os_type
    os_type=$(get_os_type)
    get_default_script_dir "$os_type"
}

get_config_dir() {
    echo "$(get_script_dir)/${DEFAULT_CONFIG_DIR_NAME}"
}

get_config_file() {
    echo "$(get_config_dir)/$CONFIG_FILENAME"
}

get_credentials_file() {
    echo "$HOME/$CREDENTIALS_FILENAME"
}

get_mount_root() {
    # Default mount location (can be overridden)
    echo "${DEFAULT_MOUNT_ROOT}"
}

get_log_dir() {
    echo "$(get_script_dir)/${DEFAULT_LOG_DIR_NAME}"
}

get_log_file() {
    echo "$(get_log_dir)/${DEFAULT_LOG_FILENAME}"
}

# Platform-specific paths
get_launchagent_dir() {
    echo "$HOME/Library/LaunchAgents"
}

get_launchagent_path() {
    echo "$(get_launchagent_dir)/${LAUNCHAGENT_NAME}.plist"
}

get_systemd_user_dir() {
    echo "$HOME/.config/systemd/user"
}

get_systemd_service_path() {
    echo "$(get_systemd_user_dir)/${SYSTEMD_SERVICE_NAME}.service"
}

# === Installation URLs ===
get_install_url() {
    echo "${GITHUB_RAW_URL}/install.sh"
}

# === Directory Management ===
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || {
            # If mkdir fails, check if dir was created by another process
            if [[ ! -d "$dir" ]]; then
                die "Failed to create directory: $dir"
            fi
        }
    fi
}

# === Configuration Management ===
load_config() {
    local config_file
    config_file=$(get_config_file)
    
    if [[ -f "$config_file" ]]; then
        source "$config_file"
        
        # Validate SHARES array
        if [[ ${#SHARES[@]} -eq 0 ]]; then
            die "No shares configured" "Run setup to add shares"
        fi
        
        # Check for shares containing commas or other invalid characters
        local share
        for share in "${SHARES[@]}"; do
            if [[ "$share" =~ [,\;] ]]; then
                die "Invalid share name: $share" "Share names cannot contain commas or semicolons"
            fi
            if [[ -z "$share" ]]; then
                die "Empty share name detected" "Please check your config file"
            fi
        done
    else
        die "Configuration not found" "Run setup first"
    fi
}

# === Credential Management ===
save_credentials() {
    local username="$1"
    local password="$2"
    local cred_file
    cred_file=$(get_credentials_file)
    
    # Strip any trailing newlines from username and password
    username="${username%$'\n'}"
    password="${password%$'\n'}"
    
    echo "${username}%${password}" > "$cred_file"
    chmod 600 "$cred_file"
}

load_credentials() {
    local cred_file
    cred_file=$(get_credentials_file)
    
    if [[ -f "$cred_file" ]]; then
        NAS_USER=$(cut -d'%' -f1 "$cred_file")
        NAS_PASS=$(cut -d'%' -f2- "$cred_file")
        export NAS_USER NAS_PASS
        log_debug "Loaded credentials successfully (${#NAS_PASS} chars)"
    else
        die "Credentials not found" "Run setup first"
    fi
}

# === Validation ===
validate_share_name() {
    local share="$1"
    if [[ ! "$share" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        die "Invalid share name: $share" "Only letters, numbers, underscore, and hyphen allowed"
    fi
}

# Validate that a share exists on the remote NAS
validate_remote_share() {
    local share="$1"
    local host="${2:-$NAS_HOST}"
    local user="${3:-$NAS_USER}"
    local pass="${4:-$NAS_PASS}"
    
    log_debug "Validating remote share: $share on $host"
    
    # Try to list the share using smbclient
    if command -v smbclient >/dev/null 2>&1; then
        local output
        output=$(smbclient -L "//$host" -U "$user%$pass" -g 2>&1 | grep -E "^Disk\|$share\|" || true)
        if [[ -n "$output" ]]; then
            log_debug "Share $share found on remote host"
            return 0
        fi
    fi
    
    # If smbclient not available, try basic SMB connection test
    if is_macos; then
        # Try to connect without mounting
        local test_output
        test_output=$(osascript -e "try
            mount volume \"smb://$user:$pass@$host/$share\"
            return \"success\"
        on error
            return \"failed\"
        end try" 2>&1 || echo "failed")
        
        if [[ "$test_output" != "failed" ]]; then
            # Unmount if we accidentally mounted it
            diskutil unmount "/Volumes/$share" 2>/dev/null || true
            return 0
        fi
    fi
    
    log_debug "Could not validate share $share on remote host"
    return 1
}

# Validate host connection
# Usage: validate_host "hostname/ip" [show_messages]
# Returns: 0 if valid, 1 if not reachable, 2 if reachable but SMB not accessible
validate_host() {
    local host="$1"
    local show_messages="${2:-true}"  # Default to showing messages
    
    if [[ "$show_messages" == "true" ]]; then
        echo "Testing connection to $host..."
    fi
    
    # Test basic connectivity
    if command -v ping >/dev/null 2>&1; then
        if ! ping -c 1 -W 2 "$host" >/dev/null 2>&1; then
            if [[ "$show_messages" == "true" ]]; then
                error "✗ Host is NOT reachable"
            fi
            return 1
        fi
        if [[ "$show_messages" == "true" ]]; then
            success "✓ Host is reachable"
        fi
    else
        # If ping is not available, skip to port test
        if [[ "$show_messages" == "true" ]]; then
            warning "ping command not found, skipping ICMP test"
        fi
    fi
    
    if [[ "$show_messages" == "true" ]]; then
        echo "Testing SMB connection..."
    fi
    
    # Test SMB port
    if ! nc -zv -w2 "$host" 445 >/dev/null 2>&1; then
        if [[ "$show_messages" == "true" ]]; then
            error "✗ SMB port (445) is not accessible"
            echo "Host is reachable but SMB service may not be running."
        fi
        return 2
    fi
    
    if [[ "$show_messages" == "true" ]]; then
        success "✓ SMB port (445) is open"
    fi
    
    return 0
}

# === Logging Configuration ===
# These can be overridden by environment variables
readonly LOG_MAX_SIZE_MB="${LOG_MAX_SIZE_MB:-10}"  # Max log file size in MB
readonly LOG_MAX_FILES="${LOG_MAX_FILES:-5}"       # Number of rotated logs to keep
readonly LOG_MAX_AGE_DAYS="${LOG_MAX_AGE_DAYS:-30}" # Delete logs older than this

# === Logging Functions ===
# Rotate logs if needed
rotate_logs() {
    local log_file="$1"
    local max_size_bytes=$((LOG_MAX_SIZE_MB * 1024 * 1024))
    
    # Check if log file exists and needs rotation
    if [[ -f "$log_file" ]]; then
        local file_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0)
        
        if [[ $file_size -gt $max_size_bytes ]]; then
            # Rotate existing logs
            for i in $(seq $((LOG_MAX_FILES - 1)) -1 1); do
                [[ -f "${log_file}.$i" ]] && mv "${log_file}.$i" "${log_file}.$((i + 1))"
            done
            
            # Move current log to .1
            mv "$log_file" "${log_file}.1"
            
            # Remove oldest log if it exists
            [[ -f "${log_file}.${LOG_MAX_FILES}" ]] && rm -f "${log_file}.${LOG_MAX_FILES}"
        fi
    fi
    
    # Clean up old logs
    if command -v find >/dev/null 2>&1; then
        find "$(dirname "$log_file")" -name "$(basename "$log_file")*" -type f -mtime +${LOG_MAX_AGE_DAYS} -delete 2>/dev/null || true
    fi
}

# Main logging function
log() {
    local level="$1"
    local message="$2"
    local log_file timestamp
    
    log_file=$(get_log_file)
    ensure_dir "$(dirname "$log_file")"
    
    # Rotate logs if needed
    rotate_logs "$log_file"
    
    # Ensure log file exists
    touch "$log_file"
    
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$log_file"
}

log_info() {
    log "INFO" "$1"
}

log_error() {
    log "ERROR" "$1"
}

log_debug() {
    log "DEBUG" "$1"
}

log_warning() {
    log "WARNING" "$1"
}

# Simplified troubleshooting logger
# Usage: log_troubleshoot "Operation failed" "Error details"
log_troubleshoot() {
    local context="${1:-Unknown}"
    local details="${2:-}"
    
    if [[ -n "$details" ]]; then
        log "TROUBLESHOOT" "$context - $details"
    else
        log "TROUBLESHOOT" "$context"
    fi
}

# Simplified - just use log_info for everything
log_msg() {
    log "LOG" "$1"
}

# === Common Utilities ===
# Ensure stdin is connected
ensure_stdin() {
    if [[ ! -t 0 ]] && [[ -e /dev/tty ]]; then
        exec < /dev/tty
    fi
}

# Read input with q/Q handling for quit
# Usage: read_input "prompt" [var_name]
# Returns: 0 if input provided, 1 if user quit with q/Q
read_input() {
    local prompt="$1"
    local var_name="${2:-REPLY}"
    local input
    
    read -p "$prompt" input
    
    # Check if user wants to quit (case-insensitive)
    local lower_input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "q" ]]; then
        return 1
    fi
    
    # Set the variable
    eval "$var_name=\"\$input\""
    return 0
}

# Read secure input (password) with q/Q handling
# Usage: read_secure_input "prompt" [var_name]
# Returns: 0 if input provided, 1 if user quit with q/Q
read_secure_input() {
    local prompt="$1"
    local var_name="${2:-REPLY}"
    local input
    
    read -s -p "$prompt" input
    echo  # New line after hidden input
    
    # Check if user wants to quit (case-insensitive)
    local lower_input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_input" == "q" ]]; then
        return 1
    fi
    
    # Set the variable
    eval "$var_name=\"\$input\""
    return 0
}

# Get shell RC file
get_shell_rc() {
    if [[ -f "$HOME/.zshrc" ]]; then
        echo "$HOME/.zshrc"
    elif [[ -f "$HOME/.bashrc" ]]; then
        echo "$HOME/.bashrc"
    else
        return 1
    fi
}