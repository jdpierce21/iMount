#!/bin/bash
# Common functions and constants - no duplication allowed

# Ensure we don't load twice
[[ -n "${_COMMON_SH_LOADED:-}" ]] && return 0
readonly _COMMON_SH_LOADED=1

# Load output functions first
source "$(dirname "${BASH_SOURCE[0]}")/output.sh"

# === Constants ===
readonly GITHUB_USER="jdpierce21"
readonly GITHUB_REPO="nas_mount"
readonly GITHUB_BRANCH="master"
readonly GITHUB_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
readonly GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

readonly CREDENTIALS_FILENAME=".nas_credentials"
readonly CONFIG_FILENAME="config.sh"
readonly MOUNT_DIR_PREFIX="nas_"

# Platform-specific service names
readonly LAUNCHAGENT_NAME="com.jpierce.nas-mounts"
readonly SYSTEMD_SERVICE_NAME="nas-mounts"

# Default values
readonly DEFAULT_NAS_HOST="192.168.54.249"
readonly DEFAULT_SHARES="backups documents media notes PacificRim photos timemachine_mbp14"

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
    local os_type
    os_type=$(get_os_type)
    
    if [[ "$os_type" == "macos" ]]; then
        echo "$HOME/Scripts/nas_mounts"
    else
        echo "$HOME/scripts/nas_mounts"
    fi
}

get_config_dir() {
    echo "$(get_script_dir)/config"
}

get_config_file() {
    echo "$(get_config_dir)/$CONFIG_FILENAME"
}

get_credentials_file() {
    echo "$HOME/$CREDENTIALS_FILENAME"
}

get_mount_root() {
    # Default mount location
    echo "$HOME/nas_mounts"
}

get_log_dir() {
    echo "$(get_script_dir)/logs"
}

get_log_file() {
    echo "$(get_log_dir)/nas_mount.log"
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
    [[ -d "$dir" ]] || mkdir -p "$dir"
}

# === Configuration Management ===
load_config() {
    local config_file
    config_file=$(get_config_file)
    
    if [[ -f "$config_file" ]]; then
        source "$config_file"
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

# === Logging ===
log() {
    local level="$1"
    local message="$2"
    local log_file timestamp
    
    log_file=$(get_log_file)
    ensure_dir "$(dirname "$log_file")"
    
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

# === Common Utilities ===
# Ensure stdin is connected
ensure_stdin() {
    if [[ ! -t 0 ]] && [[ -e /dev/tty ]]; then
        exec < /dev/tty
    fi
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