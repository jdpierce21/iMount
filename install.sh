#!/bin/bash

###############################################################################
# File: install.sh
# Date: 2025-06-13
# Version: 1.0.0
# Description: Interactive installer for NAS mount scripts
###############################################################################

set -e  # Exit on error

# === Colors for output ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# === Helper functions ===
print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# === Handle curl installation ===
if [ -z "${BASH_SOURCE[0]}" ] || [ "${BASH_SOURCE[0]}" = "bash" ]; then
    # Script is being run from curl, need to clone the repo
    print_header "NAS Mount Manager - GitHub Installation"
    
    # Determine installation directory
    if [[ "$(uname)" == "Darwin" ]]; then
        INSTALL_DIR="$HOME/Scripts/nas_mounts"
    else
        INSTALL_DIR="$HOME/scripts/nas_mounts"
    fi
    
    print_info "Installing to $INSTALL_DIR..."
    
    # Clone or update repository
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        print_info "Existing installation found, updating..."
        cd "$INSTALL_DIR"
        git pull
    else
        # Backup existing directory if it exists
        if [[ -d "$INSTALL_DIR" ]]; then
            print_warning "Backing up existing directory to ${INSTALL_DIR}.backup"
            mv "$INSTALL_DIR" "${INSTALL_DIR}.backup"
        fi
        
        # Clone repository
        mkdir -p "$(dirname "$INSTALL_DIR")"
        git clone https://github.com/jdpierce21/nas_mount.git "$INSTALL_DIR"
    fi
    
    # Continue with normal installation
    cd "$INSTALL_DIR"
    exec bash ./install.sh
fi

# === Normal installation (from cloned repo) ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"

# === Main installation logic ===
main() {
    print_header "NAS Mount Scripts Installer"
    
    # Check if config already exists
    if [[ -f "$CONFIG_FILE" ]]; then
        print_warning "Configuration file already exists at:"
        echo "  $CONFIG_FILE"
        echo ""
        echo "Options:"
        echo "  1. Run './setup_nas_mount.sh' to set up mounts with existing config"
        echo "  2. Run './mount_nas_shares.sh status' to check mount status"
        echo "  3. Delete config.sh and run this installer again for a fresh setup"
        echo ""
        read -p "Would you like to delete the existing config and start fresh? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Exiting installer. Use existing scripts with current configuration."
            exit 0
        else
            print_warning "Backing up existing config to config.sh.backup"
            cp "$CONFIG_FILE" "$CONFIG_FILE.backup"
            rm "$CONFIG_FILE"
        fi
    fi
    
    print_header "Creating Configuration File"
    
    # === Gather configuration from user ===
    
    # NAS Host
    echo "Enter your NAS host IP address or hostname:"
    read -p "NAS Host [192.168.54.249]: " nas_host
    nas_host=${nas_host:-192.168.54.249}
    
    # Save nas_host temporarily for connectivity check
    temp_nas_host="$nas_host"
    
    # Share selection
    echo ""
    echo "Which shares would you like to mount?"
    echo "Enter share names separated by spaces, or press Enter for defaults."
    echo ""
    echo "Common share names: backups documents media photos downloads public"
    echo ""
    read -p "Shares [backups documents media notes PacificRim photos timemachine_mbp14]: " -a input_shares
    
    if [[ ${#input_shares[@]} -eq 0 ]]; then
        # Use defaults
        shares=("backups" "documents" "media" "notes" "PacificRim" "photos" "timemachine_mbp14")
    else
        shares=("${input_shares[@]}")
    fi
    
    print_success "Will mount ${#shares[@]} shares: ${shares[*]}"
    
    # === Get credentials ===
    echo ""
    echo "Enter your NAS credentials:"
    read -p "Username: " nas_user
    read -s -p "Password: " nas_pass
    echo ""
    echo ""
    
    # === Get mount location preference ===
    if [[ "$(uname)" == "Darwin" ]]; then
        default_mount="$HOME/NAS_Mounts"
    else
        default_mount="$HOME/nas_mounts"
    fi
    
    echo "Where would you like to mount the shares?"
    read -p "Mount location [$default_mount]: " mount_location
    mount_location=${mount_location:-$default_mount}
    
    # === Get auto-start preference ===
    echo ""
    read -p "Would you like shares to mount automatically at login? (Y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        auto_start="no"
    else
        auto_start="yes"
    fi
    
    # === Get shell aliases preference ===
    read -p "Would you like to add convenient shell aliases (nas-mount, nas-unmount, nas-status)? (Y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        add_aliases="no"
    else
        add_aliases="yes"
    fi
    
    # === Create config file ===
    print_header "Creating Configuration"
    
    cat > "$CONFIG_FILE" << 'EOF'
#!/bin/bash

###############################################################################
# File: config.sh
# Date: 2025-06-13
# Version: 2.0.0
# Description: Cross-platform configuration file for NAS mount scripts.
###############################################################################

# === Platform Detection ===
OS_TYPE=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

# === Base Configuration Variables ===
EOF

    # Add NAS host
    echo "NAS_HOST=\"$nas_host\"" >> "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" << 'EOF'
CREDENTIALS_FILE="$HOME/.nas_credentials"

# === Platform-Specific Paths ===
if [[ "$OS_TYPE" == "macos" ]]; then
    # macOS uses capital S in Scripts
    SCRIPT_BASE="$HOME/Scripts/nas_mounts"
    PLIST_PATH="$HOME/Library/LaunchAgents/com.jpierce.nas-mounts.plist"
elif [[ "$OS_TYPE" == "linux" ]]; then
    # Linux uses lowercase s in scripts
    SCRIPT_BASE="$HOME/scripts/nas_mounts"
    # Systemd service path for Linux
    SERVICE_DIR="$HOME/.config/systemd/user"
    SERVICE_FILE="$SERVICE_DIR/nas-mounts.service"
fi

# === Common Paths ===
# Keep mounts OUTSIDE the script directory to avoid conflicts during updates
MOUNT_ROOT="$mount_location"

# Logs stay with the scripts for easier debugging
LOG_DIR="$SCRIPT_BASE/logs"
LOG_FILE="$LOG_DIR/nas_mount_setup.log"
MOUNT_SCRIPT="$SCRIPT_BASE/mount_nas_shares.sh"

# === Define shares to mount ===
declare -a SHARES=(
EOF

    # Add shares
    for share in "${shares[@]}"; do
        echo "  \"$share\"" >> "$CONFIG_FILE"
    done
    
    cat >> "$CONFIG_FILE" << 'EOF'
)

# === Optional Flags ===
FORCE_REPLACE=false
EOF

    # Add installation preferences with variable substitution
    cat >> "$CONFIG_FILE" << EOF

# === Installation Preferences ===
AUTO_START="$auto_start"
ADD_ALIASES="$add_aliases"
EOF

    chmod +x "$CONFIG_FILE"
    print_success "Configuration file created at $CONFIG_FILE"
    
    # === Load shared functions and create credentials ===
    print_header "Saving Credentials"
    
    # Source the config to get CREDENTIALS_FILE variable
    source "$CONFIG_FILE"
    # Source shared functions
    source "$SCRIPT_DIR/shared_functions.sh"
    
    # Use the shared function to save credentials
    ensure_credentials "$nas_user" "$nas_pass"
    
    # === Make all scripts executable ===
    print_header "Setting Script Permissions"
    
    for script in "$SCRIPT_DIR"/*.sh; do
        if [[ -f "$script" ]]; then
            chmod +x "$script"
            print_success "Made $(basename "$script") executable"
        fi
    done
    
    # === Run setup ===
    print_header "Running Setup"
    
    echo "Configuration complete! Now running setup script..."
    echo ""
    sleep 2
    
    # Run the setup script
    "$SCRIPT_DIR/setup_nas_mount.sh"
    
    # === Post-installation instructions ===
    print_header "Installation Complete!"
    
    echo "Your NAS mount system is now configured."
    echo ""
    echo "Available commands:"
    echo "  ./mount_nas_shares.sh mount      - Mount all shares"
    echo "  ./mount_nas_shares.sh unmount    - Unmount all shares"
    echo "  ./mount_nas_shares.sh status     - Check mount status"
    echo "  ./validate_nas_mounts.sh         - Validate all mounts"
    echo ""
    
    if command -v nas-mount >/dev/null 2>&1; then
        echo "Shell aliases are available:"
        echo "  nas-mount     - Mount all shares"
        echo "  nas-unmount   - Unmount all shares"
        echo "  nas-status    - Check mount status"
        echo ""
    fi
    
    print_success "Installation complete!"
}

# === Run main installation ===
main "$@"