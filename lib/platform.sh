#!/bin/bash
# Platform-specific functions

# Ensure we don't load twice
[[ -n "${_PLATFORM_SH_LOADED:-}" ]] && return 0
readonly _PLATFORM_SH_LOADED=1

# Load dependencies
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# === Platform Detection ===
is_macos() {
    [[ "$(get_os_type)" == "macos" ]]
}

is_linux() {
    [[ "$(get_os_type)" == "linux" ]]
}

# === Dependency Checks ===
check_dependencies() {
    if is_linux; then
        if ! command -v mount.cifs >/dev/null 2>&1; then
            error "Missing dependency: cifs-utils"
            message "Install with:"
            message "  Ubuntu/Debian: sudo apt-get install cifs-utils"
            message "  RHEL/CentOS: sudo yum install cifs-utils"
            message "  Arch: sudo pacman -S cifs-utils"
            return 1
        fi
    fi
    return 0
}

# === Mount Commands ===
get_mount_command() {
    local share="$1"
    local mount_point="$2"
    local host="${NAS_HOST:?NAS_HOST not set}"
    local user="${NAS_USER:?NAS_USER not set}"
    local pass="${NAS_PASS:?NAS_PASS not set}"
    
    if is_macos; then
        echo "mount_smbfs ${DEFAULT_MACOS_MOUNT_OPTIONS} \"//${user}:${pass}@${host}/${share}\" \"${mount_point}\""
    else
        echo "sudo mount -t cifs \"//${host}/${share}\" \"${mount_point}\" -o username=${user},password=${pass},uid=$(id -u),gid=$(id -g),${DEFAULT_LINUX_MOUNT_OPTIONS}"
    fi
}

get_unmount_command() {
    local mount_point="$1"
    
    if is_macos; then
        echo "umount \"${mount_point}\""
    else
        echo "sudo umount \"${mount_point}\""
    fi
}

# === Mount Status ===
is_mounted() {
    local mount_point="$1"
    
    if is_macos; then
        mount | grep -q " ${mount_point} "
    else
        findmnt -n "${mount_point}" >/dev/null 2>&1
    fi
}

get_mount_info() {
    local mount_point="$1"
    
    if is_macos; then
        mount | grep " ${mount_point} " | awk '{print $1 " on " $3}'
    else
        findmnt -n -o SOURCE,TARGET "${mount_point}" 2>/dev/null
    fi
}

# === Service Management ===
create_auto_mount_service() {
    local mount_script="$1"
    
    if is_macos; then
        create_launchagent "$mount_script"
    else
        create_systemd_service "$mount_script"
    fi
}

remove_auto_mount_service() {
    if is_macos; then
        remove_launchagent
    else
        remove_systemd_service
    fi
}

# === macOS LaunchAgent ===
create_launchagent() {
    local mount_script="$1"
    local plist_path
    plist_path=$(get_launchagent_path)
    
    ensure_dir "$(dirname "$plist_path")"
    
    cat > "$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LAUNCHAGENT_NAME}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${mount_script}</string>
        <string>mount</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$(get_log_dir)/launchagent.log</string>
    <key>StandardErrorPath</key>
    <string>$(get_log_dir)/launchagent.err</string>
</dict>
</plist>
EOF
    
    # Load the agent
    launchctl unload "$plist_path" 2>/dev/null || true
    launchctl load "$plist_path"
}

remove_launchagent() {
    local plist_path
    plist_path=$(get_launchagent_path)
    
    if [[ -f "$plist_path" ]]; then
        launchctl unload "$plist_path" 2>/dev/null || true
        rm -f "$plist_path"
    fi
}

# === Linux systemd ===
create_systemd_service() {
    local mount_script="$1"
    local service_path
    service_path=$(get_systemd_service_path)
    
    ensure_dir "$(dirname "$service_path")"
    
    cat > "$service_path" <<EOF
[Unit]
Description=Mount NAS shares
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${mount_script} mount
ExecStop=${mount_script} unmount
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF
    
    # Enable the service
    systemctl --user daemon-reload
    systemctl --user enable "${SYSTEMD_SERVICE_NAME}.service"
}

remove_systemd_service() {
    local service_path
    service_path=$(get_systemd_service_path)
    
    if [[ -f "$service_path" ]]; then
        systemctl --user stop "${SYSTEMD_SERVICE_NAME}.service" 2>/dev/null || true
        systemctl --user disable "${SYSTEMD_SERVICE_NAME}.service" 2>/dev/null || true
        rm -f "$service_path"
        systemctl --user daemon-reload
    fi
}

# === Shell Integration ===
add_shell_aliases() {
    local mount_script="$1"
    local shell_rc
    
    # Get shell RC file
    shell_rc=$(get_shell_rc) || return 1
    
    # Check if aliases already exist
    if grep -q "# NAS mount aliases" "$shell_rc"; then
        return 0
    fi
    
    # Add aliases
    cat >> "$shell_rc" <<EOF

# NAS mount aliases
alias nas-mount='${mount_script} mount'
alias nas-unmount='${mount_script} unmount'
alias nas-status='${mount_script} status'
EOF
}

remove_shell_aliases() {
    local shell_rc
    
    # Try both possible RC files
    for shell_rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$shell_rc" ]] && grep -q "# NAS mount aliases" "$shell_rc"; then
            # Create backup
            cp "$shell_rc" "${shell_rc}.backup"
            # Remove aliases section
            if is_macos; then
                sed -i '' '/# NAS mount aliases/,/^$/d' "$shell_rc"
            else
                sed -i '/# NAS mount aliases/,/^$/d' "$shell_rc"
            fi
        fi
    done
}