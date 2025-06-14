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
    
    # Start installation process
    
    # Ensure we're in a valid directory (in case user is in deleted directory)
    cd "$HOME" || die "Cannot change to home directory"
    
    # Determine installation directory (can't use lib functions during bootstrap)
    # Check for environment override first
    if [[ -n "${NAS_MOUNT_SCRIPT_DIR:-}" ]]; then
        INSTALL_DIR="${NAS_MOUNT_SCRIPT_DIR}"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # Check if lowercase scripts directory already exists and has nas_mounts
        if [[ -d "$HOME/scripts/nas_mounts" ]]; then
            INSTALL_DIR="$HOME/scripts/nas_mounts"
        else
            INSTALL_DIR="${NAS_MOUNT_SCRIPT_DIR:-$HOME/Scripts/nas_mounts}"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        INSTALL_DIR="${NAS_MOUNT_SCRIPT_DIR:-$HOME/scripts/nas_mounts}"
    else
        die "Unsupported OS: $OSTYPE"
    fi
    
    # GitHub constants (can't source lib during bootstrap)
    # Use environment overrides if available
    readonly GITHUB_USER="${NAS_MOUNT_GITHUB_USER:-jdpierce21}"
    readonly GITHUB_REPO="${NAS_MOUNT_GITHUB_REPO:-nas_mount}"
    readonly GITHUB_BRANCH="${NAS_MOUNT_GITHUB_BRANCH:-master}"
    readonly GITHUB_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
    
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
            # If update fails, remove and re-clone
            cd "$HOME"
            rm -rf "$INSTALL_DIR"
            progress "Re-downloading repository"
            if git clone --quiet --branch "$GITHUB_BRANCH" \
                "$GITHUB_URL" "$INSTALL_DIR" >/dev/null 2>&1; then
                progress_done
            else
                progress_fail
                die "Failed to download repository" "Check internet connection"
            fi
        fi
    else
        progress "Downloading repository"
        mkdir -p "$(dirname "$INSTALL_DIR")"
        
        # Backup non-git directory if exists
        if [[ -d "$INSTALL_DIR" ]]; then
            mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%s)"
        fi
        
        if git clone --quiet --branch "$GITHUB_BRANCH" \
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
    # Move to safe directory first (in case we're in a directory that will be deleted)
    cd "$HOME" || cd / || true
    
    # Check if already installed
    if check_existing; then
        message "Existing installation detected"
        cd "$SCRIPT_DIR" && exec bash ./cleanup.sh < /dev/tty
    fi
    
    # Fresh installation
    cd "$SCRIPT_DIR" && exec bash ./setup.sh < /dev/tty
}

main "$@"