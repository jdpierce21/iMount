#!/bin/bash
# Core setup logic

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load libraries
source lib/common.sh
source lib/platform.sh

# === Ensure stdin is connected ===
ensure_stdin

# === Main setup ===
main() {
    # Start configuration
    
    # Check if we have saved defaults
    local config_defaults="$(get_config_dir)/defaults.sh"
    if [[ -f "$config_defaults" ]]; then
        message "Found saved preferences in config/defaults.sh"
    elif [[ -f "$HOME/.nas_mount_defaults" ]]; then
        message "Found saved preferences from previous installation"
        message "Consider moving $HOME/.nas_mount_defaults to $config_defaults"
    fi
    
    # Check dependencies
    progress "Checking dependencies"
    if check_dependencies; then
        progress_done
    else
        progress_fail
        exit 1
    fi
    
    # Get NAS host
    NAS_HOST=$(prompt "Remote host" "$DEFAULT_NAS_HOST")
    
    # Get shares
    local input_shares
    input_shares=$(prompt "Remote shares" "$DEFAULT_SHARES")
    
    # Parse shares into array
    IFS=' ' read -ra SHARES <<< "${input_shares:-$DEFAULT_SHARES}"
    
    # Validate share names
    for share in "${SHARES[@]}"; do
        validate_share_name "$share"
    done
    
    # Get credentials
    local cred_file username password
    cred_file=$(get_credentials_file)
    
    if [[ -f "$cred_file" ]]; then
        message "Using existing credentials"
        load_credentials
    else
        username=$(prompt "Username" "")
        password=$(prompt_password "Password")
        
        [[ -z "$username" ]] && die "Username required"
        [[ -z "$password" ]] && die "Password required"
        
        save_credentials "$username" "$password"
    fi
    
    # Get mount location
    MOUNT_ROOT=$(prompt "Mount location" "$(get_mount_root)")
    
    # Get preferences
    # Check for saved preference defaults
    local default_auto_start="Y"
    local default_add_aliases="Y"
    
    if [[ "${NAS_MOUNT_AUTO_START:-}" == "no" ]]; then
        default_auto_start="N"
    fi
    if [[ "${NAS_MOUNT_ADD_ALIASES:-}" == "no" ]]; then
        default_add_aliases="N"
    fi
    
    if prompt_yn "Auto-mount at login?" "$default_auto_start"; then
        AUTO_START="yes"
    else
        AUTO_START="no"
    fi
    if prompt_yn "Create command aliases?" "$default_add_aliases"; then
        ADD_ALIASES="yes" 
    else
        ADD_ALIASES="no"
    fi
    
    # Create config file
    progress "Writing configuration"
    create_config
    progress_done
    
    # Make scripts executable
    chmod +x mount.sh cleanup.sh
    
    # Continue with installation steps
    
    # Create mount directories
    progress "Creating mount points"
    ensure_dir "$MOUNT_ROOT"
    for share in "${SHARES[@]}"; do
        ensure_dir "${MOUNT_ROOT}/${MOUNT_DIR_PREFIX}${share}"
    done
    progress_done
    
    # Configure auto-mount
    if [[ "$AUTO_START" == "yes" ]]; then
        progress "Configuring auto-mount"
        if create_auto_mount_service "$SCRIPT_DIR/mount.sh"; then
            progress_done
        else
            progress_fail
        fi
    fi
    
    # Add aliases
    if [[ "$ADD_ALIASES" == "yes" ]]; then
        progress "Creating command aliases"
        if add_shell_aliases "$SCRIPT_DIR/mount.sh"; then
            progress_done
        else
            progress_fail
        fi
    fi
    
    # Ask if user wants to save preferences
    if prompt_yn "Save these preferences as defaults for future installations?" "Y"; then
        save_user_defaults
    fi
    
    # Check if old defaults file exists and suggest migration
    if [[ -f "$HOME/.nas_mount_defaults" ]] && [[ ! -f "$(get_config_dir)/defaults.sh" ]]; then
        if prompt_yn "Migrate existing defaults from ~/.nas_mount_defaults to config/defaults.sh?" "Y"; then
            progress "Migrating defaults"
            cp "$HOME/.nas_mount_defaults" "$(get_config_dir)/defaults.sh"
            progress_done
            message "You can now delete ~/.nas_mount_defaults"
        fi
    fi
    
    # Done - show completion message last
    success "Installation complete"
    message "Commands: nas-mount, nas-unmount, nas-status"
    
    if [[ "$ADD_ALIASES" == "yes" ]]; then
        local shell_rc
        if shell_rc=$(get_shell_rc); then
            message "Run 'source $shell_rc' to activate aliases"
        fi
    fi
}

# === Create configuration ===
create_config() {
    local config_dir config_file
    config_dir=$(get_config_dir)
    config_file=$(get_config_file)
    
    ensure_dir "$config_dir"
    
    cat > "$config_file" <<EOF
# NAS Mount Configuration
# Generated: $(date)

# Connection
NAS_HOST="$NAS_HOST"

# Shares to mount
SHARES=($(printf '"%s" ' "${SHARES[@]}"))

# Mount location
MOUNT_ROOT="$MOUNT_ROOT"

# Preferences
AUTO_START="$AUTO_START"
ADD_ALIASES="$ADD_ALIASES"
EOF
    
    chmod 600 "$config_file"
}

# === Save user defaults ===
save_user_defaults() {
    local defaults_file="$(get_config_dir)/defaults.sh"
    local temp_file="${defaults_file}.tmp"
    
    progress "Saving preferences"
    
    # Start with empty file
    > "$temp_file"
    
    # Add header
    cat >> "$temp_file" <<'EOF'
#!/bin/bash
# NAS Mount Manager - User Defaults
# Generated by setup.sh
# These values will be used as defaults for future installations

EOF
    
    # Save non-default values only
    local has_values=false
    
    # NAS host
    if [[ "$NAS_HOST" != "$DEFAULT_NAS_HOST" ]]; then
        echo "export NAS_MOUNT_DEFAULT_HOST=\"$NAS_HOST\"" >> "$temp_file"
        has_values=true
    fi
    
    # Shares (convert array to space-separated string)
    local shares_string="${SHARES[*]}"
    if [[ "$shares_string" != "$DEFAULT_SHARES" ]]; then
        echo "export NAS_MOUNT_DEFAULT_SHARES=\"$shares_string\"" >> "$temp_file"
        has_values=true
    fi
    
    # Mount location
    local default_mount_root
    default_mount_root=$(get_mount_root)
    if [[ "$MOUNT_ROOT" != "$default_mount_root" ]]; then
        echo "export NAS_MOUNT_ROOT=\"$MOUNT_ROOT\"" >> "$temp_file"
        has_values=true
    fi
    
    # Auto-start preference (we don't have a default for this in defaults.sh, so save if no)
    if [[ "$AUTO_START" == "no" ]]; then
        echo "export NAS_MOUNT_AUTO_START=\"no\"" >> "$temp_file"
        has_values=true
    fi
    
    # Aliases preference (we don't have a default for this in defaults.sh, so save if no)
    if [[ "$ADD_ALIASES" == "no" ]]; then
        echo "export NAS_MOUNT_ADD_ALIASES=\"no\"" >> "$temp_file"
        has_values=true
    fi
    
    if [[ "$has_values" == "true" ]]; then
        # Add footer
        cat >> "$temp_file" <<'EOF'

# To reset to factory defaults, delete this file
# To modify defaults, edit this file or re-run setup.sh
EOF
        
        # Move temp file to final location
        mv "$temp_file" "$defaults_file"
        chmod 600 "$defaults_file"
        progress_done
        message "Preferences saved to $defaults_file"
    else
        # No custom values, remove temp file
        rm -f "$temp_file"
        progress_done
        log_info "All values match defaults - no preferences file created"
    fi
}

# Run main
main "$@"