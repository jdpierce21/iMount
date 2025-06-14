#!/bin/bash
# Entry point for curl installation

set -eo pipefail

# === Constants ===
readonly INSTALL_SCRIPT_VERSION="2.0.0"

# === Handle piped installation ===
if [[ "${BASH_SOURCE[0]}" == "bash" ]] || [[ -z "${BASH_SOURCE[0]:-}" ]]; then
    # Running from curl pipe
    RUNNING_FROM_CURL=true
    
    # Minimal output functions for bootstrap
    progress() { echo -n "$1... "; }
    progress_done() { echo "✓"; }
    progress_fail() { echo "✗"; }
    error() { echo "✗ Error: $1" >&2; [[ -n "${2:-}" ]] && echo "  $2" >&2; }
    die() { error "$@"; exit 1; }
    
    echo "=== Installation ==="
    
    # Determine installation directory (can't use lib functions during bootstrap)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        INSTALL_DIR="$HOME/Scripts/nas_mounts"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        INSTALL_DIR="$HOME/scripts/nas_mounts"
    else
        die "Unsupported OS: $OSTYPE"
    fi
    
    # GitHub constants (can't source lib during bootstrap)
    readonly GITHUB_URL="https://github.com/jdpierce21/nas_mount.git"
    
    # Check for git
    if ! command -v git >/dev/null 2>&1; then
        die "Git is required" "Please install git first"
    fi
    
    # Clone or update repository
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        progress "Updating repository"
        cd "$INSTALL_DIR"
        if git pull --quiet >/dev/null 2>&1; then
            progress_done
        else
            progress_fail
            die "Failed to update repository"
        fi
    else
        progress "Downloading repository"
        mkdir -p "$(dirname "$INSTALL_DIR")"
        
        # Backup non-git directory if exists
        if [[ -d "$INSTALL_DIR" ]]; then
            mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%s)"
        fi
        
        if git clone --quiet --branch master \
            "$GITHUB_URL" "$INSTALL_DIR" >/dev/null 2>&1; then
            progress_done
        else
            progress_fail
            die "Failed to download repository" "Check internet connection"
        fi
    fi
    
    # Execute the real installer
    cd "$INSTALL_DIR"
    exec bash ./install.sh
fi

# === Normal execution (from cloned repo) ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load libraries
source lib/common.sh
source lib/platform.sh

# === Check for existing installation ===
check_existing() {
    local found=false
    
    # Check for config
    [[ -f "$(get_config_file)" ]] && found=true
    
    # Check for services
    if is_macos; then
        [[ -f "$(get_launchagent_path)" ]] && found=true
    else
        [[ -f "$(get_systemd_service_path)" ]] && found=true
    fi
    
    # Check for mount directories
    local mount_root
    mount_root=$(get_mount_root)
    if [[ -d "$mount_root" ]] && ls "$mount_root"/${MOUNT_DIR_PREFIX}* >/dev/null 2>&1; then
        found=true
    fi
    
    $found
}

# === Main ===
main() {
    # Check if already installed
    if check_existing; then
        message "Existing installation detected"
        exec bash ./cleanup.sh
    fi
    
    # Fresh installation
    exec bash ./setup.sh
}

main "$@"