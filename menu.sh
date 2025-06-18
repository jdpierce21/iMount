#!/bin/bash
# Interactive CLI menu for NAS mount management

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load libraries
source lib/common.sh
source lib/platform.sh
source lib/output.sh

# Get version from git
get_version() {
    local version
    if command -v git >/dev/null 2>&1 && [[ -d .git ]]; then
        # Try to get tag first, otherwise use commit hash
        version=$(git describe --tags --always --dirty 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        # Add branch name if not on master/main
        local branch=$(git branch --show-current 2>/dev/null)
        if [[ -n "$branch" ]] && [[ "$branch" != "master" ]] && [[ "$branch" != "main" ]]; then
            version="${version} (${branch})"
        fi
    else
        version="1.0.0"
    fi
    echo "$version"
}

# Version will be updated dynamically
MENU_VERSION="$(get_version)"

# Menu colors
MENU_HEADER="\033[1;36m"  # Cyan bold
MENU_OPTION="\033[1;33m"  # Yellow bold
MENU_STATUS="\033[1;32m"  # Green bold
MENU_ERROR="\033[1;31m"   # Red bold
MENU_RESET="\033[0m"

# === Menu Functions ===

# Helper function for yes/no confirmations
# Usage: confirm_action "message"
# Returns: 0 for yes, 1 for no
confirm_action() {
    local message="$1"
    echo -e "${MENU_ERROR}${message}${MENU_RESET}"
    
    local choice=$(display_menu "Confirm: " "Yes" "No")
    
    case $choice in
        1) return 0 ;;  # Yes
        *) return 1 ;;  # No or any other option
    esac
}

# Helper function to display menu and handle input
# Usage: display_menu "prompt" "option1" "option2" ... 
# Returns: Selected option number (1-based) or 0 for quit
display_menu() {
    local prompt="$1"
    shift
    local options=("$@")
    local i choice
    
    # Display options to stderr so they show when function output is captured
    for i in "${!options[@]}"; do
        echo "[$((i+1))] ${options[$i]}" >&2
    done
    echo "[Q] Exit/Back" >&2
    echo >&2
    
    # Get input
    read -p "$prompt" choice
    
    # Convert to lowercase for q/Q handling (compatible with older bash)
    choice="$(echo "$choice" | tr '[:upper:]' '[:lower:]')"
    
    # Handle quit
    if [[ "$choice" == "q" ]]; then
        echo "0"
        return
    fi
    
    # Validate numeric input
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#options[@]}" ]]; then
        echo "$choice"
    else
        echo "Invalid option" >&2
        sleep 1
        echo "-1"  # Signal invalid input
    fi
}

show_header() {
    # Update version each time header is shown
    MENU_VERSION="$(get_version)"
    
    clear
    # Table width is 83 characters (41 + 1 + 41)
    local table_width=83
    local header_width=38
    
    # Center the header relative to the table
    local header1="======================================"
    local header2="       NAS Mount Manager Menu         "
    local header3="         Version: ${MENU_VERSION}         "
    
    # Calculate padding for centering relative to table
    local pad=$(( (table_width - header_width) / 2 ))
    
    printf "%*s" $pad ""
    echo -e "${MENU_HEADER}${header1}${MENU_RESET}"
    printf "%*s" $pad ""
    echo -e "${MENU_HEADER}${header2}${MENU_RESET}"
    printf "%*s" $pad ""
    echo -e "${MENU_HEADER}${header3}${MENU_RESET}"
    printf "%*s" $pad ""
    echo -e "${MENU_HEADER}${header1}${MENU_RESET}"
    echo
}

# Table drawing functions
draw_horizontal_line() {
    local width=$1
    printf "┌"
    printf "─%.0s" $(seq 1 $width)
    printf "┬"
    printf "─%.0s" $(seq 1 $width)
    printf "┐\n"
}

draw_middle_line() {
    local width=$1
    printf "├"
    printf "─%.0s" $(seq 1 $width)
    printf "┼"
    printf "─%.0s" $(seq 1 $width)
    printf "┤\n"
}

draw_bottom_line() {
    local width=$1
    printf "└"
    printf "─%.0s" $(seq 1 $width)
    printf "┴"
    printf "─%.0s" $(seq 1 $width)
    printf "┘\n"
}

# Pad string to fixed width
pad_string() {
    local str="$1"
    local width=$2
    # Remove ANSI color codes for length calculation
    local clean_str=$(echo -e "$str" | sed 's/\x1b\[[0-9;]*m//g')
    local str_len=${#clean_str}
    local pad_len=$((width - str_len))
    
    # Use echo -e to interpret color codes
    echo -en "$str"
    if [[ $pad_len -gt 0 ]]; then
        printf "%*s" $pad_len ""
    fi
}

# Get mount status as array
get_mount_status_lines() {
    load_config
    local lines=()
    
    lines+=("${MENU_STATUS}Current Mount Status:${MENU_RESET}")
    lines+=("")
    
    local share mount_point
    for share in "${SHARES[@]}"; do
        mount_point="${MOUNT_ROOT}/${MOUNT_DIR_PREFIX}${share}"
        
        if is_mounted "$mount_point" && ls "$mount_point" >/dev/null 2>&1; then
            lines+=("$(printf "%-20s %s✓ Mounted%s" "$share:" "$MENU_STATUS" "$MENU_RESET")")
        else
            lines+=("$(printf "%-20s %s✗ Not Mounted%s" "$share:" "$MENU_ERROR" "$MENU_RESET")")
        fi
    done
    
    printf '%s\n' "${lines[@]}"
}

# Get auto-mount status as array  
get_auto_mount_status_lines() {
    local lines=()
    
    if is_macos; then
        lines+=("${MENU_STATUS}Launch Agent Status:${MENU_RESET}")
    else
        lines+=("${MENU_STATUS}Auto-mount Service Status:${MENU_RESET}")
    fi
    lines+=("")
    
    if is_macos; then
        local plist_path="$HOME/Library/LaunchAgents/com.jpierce.nas-mounts.plist"
        
        if [[ -f "$plist_path" ]]; then
            lines+=("$(printf "%-20s %s✓ Installed%s" "Installation:" "$MENU_STATUS" "$MENU_RESET")")
            
            local launchctl_output
            launchctl_output=$(launchctl list 2>/dev/null || true)
            
            if echo "$launchctl_output" | grep -q "com.jpierce.nas-mounts"; then
                lines+=("$(printf "%-20s %s✓ Loaded%s" "Status:" "$MENU_STATUS" "$MENU_RESET")")
            else
                lines+=("$(printf "%-20s %s✗ Not Loaded%s" "Status:" "$MENU_ERROR" "$MENU_RESET")")
            fi
        else
            lines+=("$(printf "%-20s %s✗ Not Installed%s" "Installation:" "$MENU_ERROR" "$MENU_RESET")")
        fi
    else
        local service_path
        service_path=$(get_systemd_service_path)
        
        if [[ -f "$service_path" ]]; then
            lines+=("$(printf "%-20s %s✓ Installed%s" "Installation:" "$MENU_STATUS" "$MENU_RESET")")
            
            if systemctl --user is-active "${SYSTEMD_SERVICE_NAME}.service" >/dev/null 2>&1; then
                lines+=("$(printf "%-20s %s✓ Active%s" "Status:" "$MENU_STATUS" "$MENU_RESET")")
            else
                lines+=("$(printf "%-20s %s✗ Not Active%s" "Status:" "$MENU_ERROR" "$MENU_RESET")")
            fi
        else
            lines+=("$(printf "%-20s %s✗ Not Installed%s" "Installation:" "$MENU_ERROR" "$MENU_RESET")")
        fi
    fi
    
    printf '%s\n' "${lines[@]}"
}

show_mount_status() {
    load_config
    echo -e "${MENU_STATUS}Current Mount Status:${MENU_RESET}"
    echo "-------------------------------------"
    
    local share mount_point status_text status_color
    for share in "${SHARES[@]}"; do
        mount_point="${MOUNT_ROOT}/${MOUNT_DIR_PREFIX}${share}"
        
        if is_mounted "$mount_point" && ls "$mount_point" >/dev/null 2>&1; then
            status_text="✓ Mounted"
            status_color="${MENU_STATUS}"
        else
            status_text="✗ Not Mounted"
            status_color="${MENU_ERROR}"
        fi
        
        printf "%-20s %b%s%b\n" "$share:" "$status_color" "$status_text" "$MENU_RESET"
    done
    echo
}

show_auto_mount_status() {
    if is_macos; then
        echo -e "${MENU_STATUS}Launch Agent Status:${MENU_RESET}"
    else
        echo -e "${MENU_STATUS}Auto-mount Service Status:${MENU_RESET}"
    fi
    echo "-------------------------------------"
    
    if is_macos; then
        local plist_path="$HOME/Library/LaunchAgents/com.jpierce.nas-mounts.plist"
        
        if [[ -f "$plist_path" ]]; then
            printf "%-20s %b%s%b\n" "Installation:" "${MENU_STATUS}" "✓ Installed" "${MENU_RESET}"
            
            # Capture launchctl output to variable first for reliable checking
            local launchctl_output
            launchctl_output=$(launchctl list 2>/dev/null || true)
            
            # Check if our service is in the output
            if echo "$launchctl_output" | grep -q "com.jpierce.nas-mounts"; then
                printf "%-20s %b%s%b\n" "Status:" "${MENU_STATUS}" "✓ Loaded" "${MENU_RESET}"
            else
                printf "%-20s %b%s%b\n" "Status:" "${MENU_ERROR}" "✗ Not Loaded" "${MENU_RESET}"
            fi
        else
            printf "%-20s %b%s%b\n" "Installation:" "${MENU_ERROR}" "✗ Not Installed" "${MENU_RESET}"
        fi
    else
        local service_path
        service_path=$(get_systemd_service_path)
        
        if [[ -f "$service_path" ]]; then
            printf "%-20s %b%s%b\n" "Installation:" "${MENU_STATUS}" "✓ Installed" "${MENU_RESET}"
            
            # Check systemd service status
            if systemctl --user is-active "${SYSTEMD_SERVICE_NAME}.service" >/dev/null 2>&1; then
                printf "%-20s %b%s%b\n" "Status:" "${MENU_STATUS}" "✓ Active" "${MENU_RESET}"
            else
                printf "%-20s %b%s%b\n" "Status:" "${MENU_ERROR}" "✗ Not Active" "${MENU_RESET}"
            fi
        else
            printf "%-20s %b%s%b\n" "Installation:" "${MENU_ERROR}" "✗ Not Installed" "${MENU_RESET}"
        fi
    fi
    echo
}

mount_all() {
    echo -e "${MENU_STATUS}Mounting all shares...${MENU_RESET}"
    ./mount.sh mount
    echo
    echo "Press Enter to continue..."
    read -r
}

unmount_all() {
    echo -e "${MENU_STATUS}Unmounting all shares...${MENU_RESET}"
    ./mount.sh unmount
    echo
    echo "Press Enter to continue..."
    read -r
}

verify_mounts() {
    load_config
    echo -e "${MENU_STATUS}Verifying mounts with test operations...${MENU_RESET}"
    echo
    
    local share mount_point test_file
    for share in "${SHARES[@]}"; do
        mount_point="${MOUNT_ROOT}/${MOUNT_DIR_PREFIX}${share}"
        test_file="$mount_point/.nas_mount_test_$$"
        
        echo -n "Testing $share... "
        
        if is_mounted "$mount_point"; then
            # Try to create and delete a test file
            if touch "$test_file" 2>/dev/null && rm "$test_file" 2>/dev/null; then
                echo -e "${MENU_STATUS}✓ Working${MENU_RESET}"
            else
                echo -e "${MENU_ERROR}✗ Mounted but not writable${MENU_RESET}"
            fi
        else
            echo -e "${MENU_ERROR}✗ Not mounted${MENU_RESET}"
        fi
    done
    
    echo
    echo "Press Enter to continue..."
    read -r
}

test_connection() {
    load_config
    echo -e "${MENU_STATUS}Testing connection to remote host...${MENU_RESET}"
    echo "-------------------------------------"
    echo "Remote host: $NAS_HOST"
    echo
    
    validate_host "$NAS_HOST"
    local result=$?
    
    echo
    case $result in
        0)
            echo -e "${MENU_STATUS}Connection test successful!${MENU_RESET}"
            echo "The remote host is fully accessible for SMB operations."
            ;;
        1)
            echo -e "${MENU_ERROR}Connection test failed!${MENU_RESET}"
            echo "The remote host is not reachable. Please check:"
            echo "- Network connectivity"
            echo "- Hostname/IP address is correct"
            echo "- Remote host is powered on"
            ;;
        2)
            echo -e "${MENU_ERROR}Partial connection!${MENU_RESET}"
            echo "The host is reachable but SMB is not accessible. Please check:"
            echo "- SMB/CIFS service is running on the remote host"
            echo "- Firewall is not blocking port 445"
            echo "- SMB sharing is enabled"
            ;;
    esac
    
    echo
    echo "Press Enter to continue..."
    read -r
}

run_git_operations() {
    echo -e "${MENU_STATUS}Running Git operations...${MENU_RESET}"
    echo
    
    if [[ -x "./git.sh" ]]; then
        ./git.sh
    else
        echo -e "${MENU_ERROR}Error: git.sh script not found or not executable${MENU_RESET}"
    fi
    
    echo
    echo "Press Enter to continue..."
    read -r
}

edit_configuration() {
    while true; do
        show_header
        echo -e "${MENU_STATUS}Current Configuration:${MENU_RESET}"
        echo "-------------------------------------"
        
        load_config
        echo "Remote Host: $NAS_HOST"
        echo "Mount Root: $MOUNT_ROOT"
        echo
        echo "Existing Mounts:"
        for share in "${SHARES[@]}"; do
            echo "${MOUNT_DIR_PREFIX}${share}"
        done
        echo
        
        echo -e "${MENU_OPTION}Configuration Options:${MENU_RESET}"
        
        local choice=$(display_menu "Select option: " \
            "Edit remote host" \
            "Add a local mount" \
            "Remove a local mount" \
            "Edit local mount root directory" \
            "Edit credentials")
        
        case $choice in
            0) return ;;  # Back to main menu
            1) edit_nas_host ;;
            2) add_share ;;
            3) remove_share ;;
            4) edit_mount_root ;;
            5) edit_credentials ;;
            -1) ;;  # Invalid option, loop will refresh
        esac
    done
}

edit_nas_host() {
    local new_host=""
    local valid=false
    
    while [[ "$valid" == "false" ]]; do
        echo
        if ! read_input "Enter new remote host IP/hostname (current: $NAS_HOST) or Q to cancel: " new_host; then
            return  # User pressed q/Q
        fi
        
        # If empty, keep current value and exit
        if [[ -z "$new_host" ]]; then
            return
        fi
        
        # Validate the host using helper function
        validate_host "$new_host"
        local result=$?
        
        case $result in
            0)  # Fully valid
                sed -i '' "s/^NAS_HOST=.*/NAS_HOST=\"$new_host\"/" config/config.sh
                echo -e "${MENU_STATUS}Remote host updated to: $new_host${MENU_RESET}"
                echo "Press Enter to continue..."
                read -r
                valid=true
                ;;
            1)  # Not reachable
                echo "Please check the hostname/IP and try again."
                # Loop back to prompt automatically
                ;;
            2)  # Reachable but SMB not accessible
                echo
                if confirm_action "Save anyway?"; then
                    sed -i '' "s/^NAS_HOST=.*/NAS_HOST=\"$new_host\"/" config/config.sh
                    echo -e "${MENU_STATUS}Remote host updated to: $new_host${MENU_RESET}"
                    echo "Press Enter to continue..."
                    read -r
                    valid=true
                fi
                # If not saving, loop back to prompt
                ;;
        esac
    done
}

add_share() {
    while true; do
        echo
        if ! read_input "Enter share name to add (or press Enter/Q to cancel): " new_share; then
            return  # User pressed q/Q
        fi
        
        # If empty, return to config menu
        if [[ -z "$new_share" ]]; then
            return
        fi
        
        # Validate share name format
        if [[ ! "$new_share" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo -e "${MENU_ERROR}✗ Invalid share name${MENU_RESET}"
            echo "Only letters, numbers, underscore, and hyphen allowed."
            continue
        fi
        
        # Check if share already exists in config
        local share_exists=false
        for share in "${SHARES[@]}"; do
            if [[ "$share" == "$new_share" ]]; then
                share_exists=true
                break
            fi
        done
        
        if [[ "$share_exists" == "true" ]]; then
            echo -e "${MENU_ERROR}✗ Share '$new_share' already exists${MENU_RESET}"
            continue
        fi
        
        # Test if share exists on remote server
        echo "Validating share on remote server..."
        
        # Load credentials for share listing
        load_credentials
        
        # Try to list shares with authentication
        local share_list
        if [[ -n "${NAS_USER:-}" ]]; then
            # Use authenticated view - filter out header lines and extract share names
            share_list=$(smbutil view "//${NAS_USER}@${NAS_HOST}" 2>&1 <<< "$NAS_PASS" | \
                grep -E "^[a-zA-Z0-9_-]+\s+Disk" | \
                awk '{print $1}' 2>/dev/null || true)
        else
            # Try unauthenticated view (may not show all shares)
            share_list=$(smbutil view -N "//${NAS_HOST}" 2>&1 | \
                grep -E "^[a-zA-Z0-9_-]+\s+Disk" | \
                awk '{print $1}' 2>/dev/null || true)
        fi
        
        if echo "$share_list" | grep -q "^${new_share}$"; then
            echo -e "${MENU_STATUS}✓ Share exists on remote server${MENU_RESET}"
            
            # Add to SHARES array in config
            sed -i '' "/^SHARES=(/s/)$/ \"$new_share\")/" config/config.sh
            echo -e "${MENU_STATUS}Share '${MOUNT_DIR_PREFIX}${new_share}' added successfully${MENU_RESET}"
            
            # Reload config to reflect changes
            load_config
            
            echo "Press Enter to continue..."
            read -r
            return  # Go back to config menu
        else
            echo -e "${MENU_ERROR}✗ Share '$new_share' not found on remote server${MENU_RESET}"
            
            if [[ -n "$share_list" ]]; then
                echo "Available shares on ${NAS_HOST}:"
                echo "$share_list" | sort | sed 's/^/  /'
            else
                echo "Unable to list available shares (authentication may be required)"
            fi
            echo
            
            if confirm_action "Add anyway?"; then
                # Add even though it doesn't exist
                sed -i '' "/^SHARES=(/s/)$/ \"$new_share\")/" config/config.sh
                echo -e "${MENU_STATUS}Share '${MOUNT_DIR_PREFIX}${new_share}' added (not verified)${MENU_RESET}"
                
                # Reload config to reflect changes
                load_config
                
                echo "Press Enter to continue..."
                read -r
                return  # Go back to config menu
            fi
            # If not adding, loop back to prompt
        fi
    done
}

remove_share() {
    while true; do
        echo
        echo -e "${MENU_STATUS}Current shares:${MENU_RESET}"
        
        if [[ ${#SHARES[@]} -eq 0 ]]; then
            echo "No shares configured."
            echo "Press Enter to continue..."
            read -r
            return
        fi
        
        # Build share list for menu
        local share_list=()
        for share in "${SHARES[@]}"; do
            share_list+=("${MOUNT_DIR_PREFIX}${share}")
        done
        
        local choice=$(display_menu "Select share to remove: " "${share_list[@]}")
        
        case $choice in
            0) return ;;  # Back to config menu
            -1) ;;  # Invalid option, loop will refresh
            *)
                if [[ $choice -ge 1 && $choice -le ${#SHARES[@]} ]]; then
                    local share_to_remove="${SHARES[$((choice-1))]}"
                    
                    # Confirm removal
                    echo
                    if confirm_action "Are you sure you want to remove '${MOUNT_DIR_PREFIX}${share_to_remove}'?"; then
                        # Check if share is mounted and unmount it first
                        local mount_point="${MOUNT_ROOT}/${MOUNT_DIR_PREFIX}${share_to_remove}"
                        if is_mounted "$mount_point"; then
                            echo -e "${MENU_STATUS}Unmounting share before removal...${MENU_RESET}"
                            if is_macos; then
                                umount "$mount_point" 2>/dev/null || diskutil unmount "$mount_point" 2>/dev/null || {
                                    echo -e "${MENU_ERROR}Failed to unmount share. Please unmount manually first.${MENU_RESET}"
                                    echo "Press Enter to continue..."
                                    read -r
                                    continue
                                }
                            else
                                sudo umount "$mount_point" 2>/dev/null || {
                                    echo -e "${MENU_ERROR}Failed to unmount share. Please unmount manually first.${MENU_RESET}"
                                    echo "Press Enter to continue..."
                                    read -r
                                    continue
                                }
                            fi
                            echo -e "${MENU_STATUS}Share unmounted successfully${MENU_RESET}"
                        fi
                        
                        # Remove mount directory if it exists
                        if [[ -d "$mount_point" ]]; then
                            rmdir "$mount_point" 2>/dev/null || {
                                echo -e "${MENU_ERROR}Warning: Could not remove mount directory${MENU_RESET}"
                            }
                        fi
                        
                        # Remove from config file
                        if is_macos; then
                            sed -i '' "s/\"$share_to_remove\"//g" config/config.sh
                            # Clean up extra spaces and empty elements
                            sed -i '' 's/  */ /g' config/config.sh
                            sed -i '' 's/( /(/g' config/config.sh
                            sed -i '' 's/ )/)/g' config/config.sh
                        else
                            sed -i "s/\"$share_to_remove\"//g" config/config.sh
                            # Clean up extra spaces and empty elements
                            sed -i 's/  */ /g' config/config.sh
                            sed -i 's/( /(/g' config/config.sh
                            sed -i 's/ )/)/g' config/config.sh
                        fi
                        
                        echo -e "${MENU_STATUS}Share '${MOUNT_DIR_PREFIX}${share_to_remove}' removed${MENU_RESET}"
                        
                        # Reload config for next iteration
                        load_config
                        
                        echo "Press Enter to continue..."
                        read -r
                        
                        # If no more shares, return to config menu
                        if [[ ${#SHARES[@]} -eq 0 ]]; then
                            return
                        fi
                    else
                        echo "Removal cancelled."
                    fi
                fi
                ;;
        esac
    done
}

edit_mount_root() {
    echo
    if ! read_input "Enter new mount root directory (current: $MOUNT_ROOT) or Q to cancel: " new_root; then
        return  # User pressed q/Q
    fi
    if [[ -n "$new_root" ]]; then
        sed -i '' "s|^MOUNT_ROOT=.*|MOUNT_ROOT=\"$new_root\"|" config/config.sh
        echo -e "${MENU_STATUS}Mount root updated to: $new_root${MENU_RESET}"
    fi
    echo "Press Enter to continue..."
    read -r
}

edit_credentials() {
    echo
    echo "Enter NAS credentials:"
    if ! read_input "Username (or Q to cancel): " username; then
        return  # User pressed q/Q
    fi
    if ! read_secure_input "Password (or Q to cancel): " password; then
        return  # User pressed q/Q
    fi
    
    if [[ -n "$username" && -n "$password" ]]; then
        echo "${username}%${password}" > "$HOME/.nas_credentials"
        chmod 600 "$HOME/.nas_credentials"
        echo -e "${MENU_STATUS}Credentials updated${MENU_RESET}"
    fi
    echo "Press Enter to continue..."
    read -r
}

manage_auto_mount() {
    while true; do
        show_header
        show_auto_mount_status
        
        if is_macos; then
            echo -e "${MENU_OPTION}Launch Agent Options:${MENU_RESET}"
        else
            echo -e "${MENU_OPTION}Auto-mount Service Options:${MENU_RESET}"
        fi
        
        local choice
        if is_macos; then
            choice=$(display_menu "Select option: " \
                "Install/Update Launch Agent" \
                "Uninstall Launch Agent" \
                "Load Launch Agent" \
                "Unload Launch Agent" \
                "View Launch Agent logs")
        else
            choice=$(display_menu "Select option: " \
                "Install/Update Auto-mount Service" \
                "Uninstall Auto-mount Service" \
                "Start Auto-mount Service" \
                "Stop Auto-mount Service" \
                "View Service logs")
        fi
        
        case $choice in
            0) return ;;  # Back to main menu
            1) install_auto_mount ;;
            2) uninstall_auto_mount ;;
            3) load_auto_mount ;;
            4) unload_auto_mount ;;
            5) view_auto_mount_logs ;;
            -1) ;;  # Invalid option, loop will refresh
        esac
    done
}

install_auto_mount() {
    echo
    if is_macos; then
        echo -e "${MENU_STATUS}Installing Launch Agent...${MENU_RESET}"
    else
        echo -e "${MENU_STATUS}Installing Auto-mount Service...${MENU_RESET}"
    fi
    
    # Use the platform-specific function from platform.sh
    if create_auto_mount_service "$SCRIPT_DIR/mount.sh"; then
        echo -e "${MENU_STATUS}Installation successful!${MENU_RESET}"
    else
        echo -e "${MENU_ERROR}Installation failed!${MENU_RESET}"
    fi
    
    echo "Press Enter to continue..."
    read -r
}

uninstall_auto_mount() {
    echo
    local confirm_msg
    if is_macos; then
        confirm_msg="Are you sure you want to uninstall the Launch Agent?"
    else
        confirm_msg="Are you sure you want to uninstall the Auto-mount Service?"
    fi
    
    if confirm_action "$confirm_msg"; then
        if is_macos; then
            echo -e "${MENU_STATUS}Uninstalling Launch Agent...${MENU_RESET}"
        else
            echo -e "${MENU_STATUS}Uninstalling Auto-mount Service...${MENU_RESET}"
        fi
        
        # Use the platform-specific function from platform.sh
        remove_auto_mount_service
        
        if is_macos; then
            echo -e "${MENU_STATUS}Launch Agent uninstalled${MENU_RESET}"
        else
            echo -e "${MENU_STATUS}Auto-mount Service uninstalled${MENU_RESET}"
        fi
    else
        echo "Uninstall cancelled."
    fi
    echo "Press Enter to continue..."
    read -r
}

load_auto_mount() {
    echo
    if is_macos; then
        echo -e "${MENU_STATUS}Loading Launch Agent...${MENU_RESET}"
        local plist_path
        plist_path=$(get_launchagent_path)
        
        if [[ -f "$plist_path" ]]; then
            launchctl unload "$plist_path" 2>/dev/null || true
            if launchctl load "$plist_path"; then
                echo -e "${MENU_STATUS}Launch Agent loaded successfully${MENU_RESET}"
            else
                echo -e "${MENU_ERROR}Failed to load Launch Agent${MENU_RESET}"
            fi
        else
            echo -e "${MENU_ERROR}Launch Agent not installed${MENU_RESET}"
        fi
    else
        echo -e "${MENU_STATUS}Starting Auto-mount Service...${MENU_RESET}"
        if systemctl --user start "${SYSTEMD_SERVICE_NAME}.service"; then
            echo -e "${MENU_STATUS}Service started successfully${MENU_RESET}"
        else
            echo -e "${MENU_ERROR}Failed to start service${MENU_RESET}"
        fi
    fi
    echo "Press Enter to continue..."
    read -r
}

unload_auto_mount() {
    echo
    if is_macos; then
        echo -e "${MENU_STATUS}Unloading Launch Agent...${MENU_RESET}"
        local plist_path
        plist_path=$(get_launchagent_path)
        
        if launchctl unload "$plist_path" 2>/dev/null; then
            echo -e "${MENU_STATUS}Launch Agent unloaded${MENU_RESET}"
        else
            echo -e "${MENU_ERROR}Failed to unload Launch Agent${MENU_RESET}"
        fi
    else
        echo -e "${MENU_STATUS}Stopping Auto-mount Service...${MENU_RESET}"
        if systemctl --user stop "${SYSTEMD_SERVICE_NAME}.service"; then
            echo -e "${MENU_STATUS}Service stopped successfully${MENU_RESET}"
        else
            echo -e "${MENU_ERROR}Failed to stop service${MENU_RESET}"
        fi
    fi
    echo "Press Enter to continue..."
    read -r
}

view_auto_mount_logs() {
    echo
    if is_macos; then
        echo -e "${MENU_STATUS}Recent Launch Agent logs:${MENU_RESET}"
        echo "-------------------------------------"
        local log_dir
        log_dir=$(get_log_dir)
        if [[ -f "$log_dir/launchagent.log" ]]; then
            tail -n 20 "$log_dir/launchagent.log"
        else
            echo "No logs found"
        fi
    else
        echo -e "${MENU_STATUS}Recent Service logs:${MENU_RESET}"
        echo "-------------------------------------"
        journalctl --user -u "${SYSTEMD_SERVICE_NAME}.service" -n 20 --no-pager || echo "No logs found"
    fi
    echo
    echo "Press Enter to continue..."
    read -r
}

display_table_menu() {
    local cell_width=41
    
    # Get status content - using portable method instead of mapfile
    local mount_lines=()
    while IFS= read -r line; do
        mount_lines+=("$line")
    done < <(get_mount_status_lines)
    
    local auto_mount_lines=()
    while IFS= read -r line; do
        auto_mount_lines+=("$line")
    done < <(get_auto_mount_status_lines)
    
    # Main operations menu
    local main_ops=(
        "${MENU_OPTION}Main Operations:${MENU_RESET}"
        ""
        "[1] Mount all shares"
        "[2] Unmount all shares"
        "[3] Verify mounts (test read/write)"
        "[4] View logs"
        ""
        "[Q] Quit"
    )
    
    # Config operations menu
    local config_ops=(
        "${MENU_OPTION}Configuration & Testing:${MENU_RESET}"
        ""
        "[5] Edit configuration"
        "[6] Test remote connection"
        "[7] Manage Auto-mount"
        "[8] Git operations"
    )
    
    # Draw top line
    draw_horizontal_line $cell_width
    
    # Draw status row
    local max_lines=${#mount_lines[@]}
    if [[ ${#auto_mount_lines[@]} -gt $max_lines ]]; then
        max_lines=${#auto_mount_lines[@]}
    fi
    
    for ((i=0; i<max_lines; i++)); do
        printf "│ "
        if [[ $i -lt ${#mount_lines[@]} ]]; then
            pad_string "${mount_lines[$i]}" $((cell_width - 1))
        else
            printf "%*s" $((cell_width - 1)) ""
        fi
        printf "│ "
        if [[ $i -lt ${#auto_mount_lines[@]} ]]; then
            pad_string "${auto_mount_lines[$i]}" $((cell_width - 1))
        else
            printf "%*s" $((cell_width - 1)) ""
        fi
        printf "│\n"
    done
    
    # Draw middle line
    draw_middle_line $cell_width
    
    # Draw menu row
    max_lines=${#main_ops[@]}
    if [[ ${#config_ops[@]} -gt $max_lines ]]; then
        max_lines=${#config_ops[@]}
    fi
    
    for ((i=0; i<max_lines; i++)); do
        printf "│ "
        if [[ $i -lt ${#main_ops[@]} ]]; then
            pad_string "${main_ops[$i]}" $((cell_width - 1))
        else
            printf "%*s" $((cell_width - 1)) ""
        fi
        printf "│ "
        if [[ $i -lt ${#config_ops[@]} ]]; then
            pad_string "${config_ops[$i]}" $((cell_width - 1))
        else
            printf "%*s" $((cell_width - 1)) ""
        fi
        printf "│\n"
    done
    
    # Draw bottom line
    draw_bottom_line $cell_width
    echo
}

# === Main Menu ===
main_menu() {
    while true; do
        show_header
        display_table_menu
        
        # Simple input prompt
        printf "Select option: "
        read -r choice
        
        case ${choice,,} in  # Convert to lowercase
            q|quit|exit) exit 0 ;;
            1) mount_all ;;
            2) unmount_all ;;
            3) verify_mounts ;;
            4) less logs/nas_mount.log ;;
            5) edit_configuration ;;
            6) test_connection ;;
            7) manage_auto_mount ;;
            8) run_git_operations ;;
            *) echo -e "${MENU_ERROR}Invalid option. Please try again.${MENU_RESET}"; sleep 1 ;;
        esac
    done
}

# Check for updates (returns 0 if up to date or updated, 1 if not)
check_for_updates() {
    echo -e "${MENU_STATUS}Checking for updates...${MENU_RESET}"
    log_troubleshoot "Update check started"
    
    # Ensure we're in a git repo
    if ! command -v git >/dev/null 2>&1 || [[ ! -d .git ]]; then
        echo -e "${MENU_ERROR}Git not available or not a git repository${MENU_RESET}"
        echo "Cannot verify if software is up to date."
        return 1
    fi
    
    # Fetch latest changes from remote
    if ! git fetch origin master --quiet 2>/dev/null; then
        echo -e "${MENU_ERROR}Failed to check for updates (network issue?)${MENU_RESET}"
        echo "Cannot verify if software is up to date."
        return 1
    fi
    
    # Get current and remote commit hashes
    local current_commit=$(git rev-parse HEAD 2>/dev/null)
    local remote_commit=$(git rev-parse origin/master 2>/dev/null)
    
    if [[ "$current_commit" == "$remote_commit" ]]; then
        echo -e "${MENU_STATUS}✓ Already up to date${MENU_RESET}"
        return 0
    fi
    
    # Updates are required
    echo -e "${MENU_ERROR}⚠ Updates are required!${MENU_RESET}"
    echo
    echo "Your version: $(git rev-parse --short HEAD)"
    echo "Latest version: $(git rev-parse --short origin/master)"
    echo
    echo "Changes in the new version:"
    git log --oneline HEAD..origin/master | head -10
    echo
    
    # Check if there are local changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo -e "${MENU_ERROR}You have uncommitted local changes${MENU_RESET}"
        echo "Please commit or stash your changes before updating."
        echo
        echo "To bypass update check (not recommended):"
        echo "  ./menu.sh --skip-update-check"
        return 1
    fi
    
    # Force update
    echo -e "${MENU_OPTION}This software requires updating before use.${MENU_RESET}"
    echo
    if confirm_action "Update now?"; then
        echo -e "${MENU_STATUS}Updating...${MENU_RESET}"
        if git pull origin master; then
            echo -e "${MENU_STATUS}✓ Update successful!${MENU_RESET}"
            echo "Restarting menu with new version..."
            sleep 2
            exec "$0" "$@"  # Restart the script
        else
            echo -e "${MENU_ERROR}Update failed!${MENU_RESET}"
            echo
            echo "Please fix the issue and try again."
            echo "To bypass update check (not recommended):"
            echo "  ./menu.sh --skip-update-check"
            return 1
        fi
    else
        echo
        echo "Update cancelled. This software requires the latest version to run."
        echo "To bypass update check (not recommended):"
        echo "  ./menu.sh --skip-update-check"
        return 1
    fi
}

# Parse command line arguments
SKIP_UPDATE_CHECK=false
SHOW_HELP=false

for arg in "$@"; do
    case "$arg" in
        --skip-update-check)
            SKIP_UPDATE_CHECK=true
            ;;
        --help|-h)
            SHOW_HELP=true
            ;;
    esac
done

# Show help if requested
if [[ "$SHOW_HELP" == "true" ]]; then
    echo "NAS Mount Manager Menu"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --skip-update-check    Skip update check (not recommended)"
    echo "  --help, -h            Show this help message"
    echo
    exit 0
fi

# Check for updates unless explicitly skipped
if [[ "$SKIP_UPDATE_CHECK" == "false" ]]; then
    if ! check_for_updates; then
        echo
        echo -e "${MENU_ERROR}Exiting - updates required${MENU_RESET}"
        exit 1
    fi
    echo
fi

# Start the menu
main_menu