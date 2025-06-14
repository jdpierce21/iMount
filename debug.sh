#!/bin/bash
# Debug script for NAS Mount Manager

echo "=== NAS Mount Manager Debug Report ==="
echo "Generated: $(date)"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load libraries
source lib/common.sh
source lib/platform.sh

echo "=== System Information ==="
echo "OS: $(uname -s)"
echo "OS Version: $(uname -r)"
echo "Hostname: $(hostname)"
echo "User: $USER"
echo "Home: $HOME"
echo "Current Dir: $(pwd)"
echo ""

echo "=== Installation Paths ==="
echo "Script Dir: $(get_script_dir)"
echo "Config Dir: $(get_config_dir)"
echo "Config File: $(get_config_file)"
echo "Credentials File: $(get_credentials_file)"
echo "Mount Root: $(get_mount_root)"
echo "Log Dir: $(get_log_dir)"
echo "Log File: $(get_log_file)"
echo ""

echo "=== File Existence Check ==="
[[ -f "$(get_config_file)" ]] && echo "✓ Config file exists" || echo "✗ Config file missing"
[[ -f "$(get_credentials_file)" ]] && echo "✓ Credentials file exists" || echo "✗ Credentials file missing"
[[ -d "$(get_mount_root)" ]] && echo "✓ Mount root exists" || echo "✗ Mount root missing"
[[ -d "$(get_log_dir)" ]] && echo "✓ Log directory exists" || echo "✗ Log directory missing"
[[ -f "$(get_log_file)" ]] && echo "✓ Log file exists" || echo "✗ Log file missing"
echo ""

echo "=== Configuration Contents ==="
if [[ -f "$(get_config_file)" ]]; then
    echo "Config file contents:"
    cat "$(get_config_file)" | sed 's/^/  /'
    echo ""
    # Load config to get variables
    load_config
else
    echo "✗ No config file found"
fi
echo ""

echo "=== Credentials Check ==="
if [[ -f "$(get_credentials_file)" ]]; then
    echo "✓ Credentials file exists with permissions: $(stat -f %p "$(get_credentials_file)" 2>/dev/null || stat -c %a "$(get_credentials_file)" 2>/dev/null)"
    # Parse credentials
    load_credentials
    echo "Username: ${NAS_USER:-NOT SET}"
    echo "Password: $(echo "${NAS_PASS:-NOT SET}" | sed 's/./*/g')"
else
    echo "✗ No credentials file"
fi
echo ""

echo "=== Service Status ==="
if is_macos; then
    PLIST="$(get_launchagent_path)"
    if [[ -f "$PLIST" ]]; then
        echo "✓ LaunchAgent exists: $PLIST"
        echo "LaunchAgent status:"
        launchctl list | grep com.jpierce.nas-mounts || echo "  Not loaded"
    else
        echo "✗ No LaunchAgent found"
    fi
else
    SERVICE="$(get_systemd_service_path)"
    if [[ -f "$SERVICE" ]]; then
        echo "✓ Systemd service exists: $SERVICE"
        systemctl --user status nas-mounts.service --no-pager || true
    else
        echo "✗ No systemd service found"
    fi
fi
echo ""

echo "=== Shell Aliases ==="
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$rc" ]]; then
        if grep -q "nas-mount" "$rc"; then
            echo "✓ Aliases found in $rc:"
            grep -A3 "# NAS mount aliases" "$rc" | sed 's/^/  /'
        else
            echo "✗ No aliases in $rc"
        fi
    fi
done
echo ""

echo "=== Mount Directories ==="
if [[ -d "$(get_mount_root)" ]]; then
    echo "Contents of $(get_mount_root):"
    ls -la "$(get_mount_root)" | sed 's/^/  /'
else
    echo "✗ Mount root directory does not exist"
fi
echo ""

echo "=== Current Mount Status ==="
echo "System mounts:"
if is_macos; then
    mount | grep -E "($(get_mount_root)|SMB|smbfs)" | sed 's/^/  /' || echo "  No relevant mounts found"
else
    mount | grep -E "($(get_mount_root)|cifs)" | sed 's/^/  /' || echo "  No relevant mounts found"
fi
echo ""

echo "=== Mount Command Test ==="
if [[ -n "${SHARES:-}" ]]; then
    echo "Testing mount command generation for first share (${SHARES[0]}):"
    if [[ -n "${NAS_HOST:-}" ]] && [[ -n "${NAS_USER:-}" ]] && [[ -n "${NAS_PASS:-}" ]]; then
        cmd=$(get_mount_command "${SHARES[0]}" "$(get_mount_root)/${MOUNT_DIR_PREFIX}${SHARES[0]}")
        # Mask password in output
        echo "  ${cmd//$NAS_PASS/****}"
        echo ""
        echo "  Password details:"
        echo "    Length: ${#NAS_PASS}"
        echo "    First 3 chars: ${NAS_PASS:0:3}***"
        echo "    Last 3 chars: ***${NAS_PASS: -3}"
        echo "    Contains spaces: $(echo "$NAS_PASS" | grep -q ' ' && echo "YES" || echo "NO")"
        echo "    Contains quotes: $(echo "$NAS_PASS" | grep -q "'" && echo "YES" || echo "NO")"
        echo "    Contains dollars: $(echo "$NAS_PASS" | grep -q '\$' && echo "YES" || echo "NO")"
        echo ""
        echo "  ACTUAL COMMAND (CONTAINS PASSWORD - BE CAREFUL):"
        echo "    $cmd"
    else
        echo "  Cannot generate - missing NAS_HOST, NAS_USER, or NAS_PASS"
    fi
else
    echo "  No shares configured"
fi
echo ""

echo "=== Mount Script Status Check ==="
if [[ -f "mount.sh" ]]; then
    echo "Running mount.sh status:"
    ./mount.sh status 2>&1 | sed 's/^/  /'
else
    echo "✗ mount.sh not found"
fi
echo ""

echo "=== Network Connectivity ==="
if [[ -n "${NAS_HOST:-}" ]]; then
    echo "Checking connectivity to $NAS_HOST:"
    if ping -c 1 -W 2 "$NAS_HOST" >/dev/null 2>&1; then
        echo "  ✓ Host is reachable"
    else
        echo "  ✗ Host is NOT reachable"
    fi
else
    echo "✗ NAS_HOST not configured"
fi
echo ""

echo "=== Log Files ==="
LOG_DIR="$(get_log_dir)"
if [[ -d "$LOG_DIR" ]]; then
    echo "Log directory contents:"
    ls -la "$LOG_DIR" | sed 's/^/  /'
    echo ""
    for log in "$LOG_DIR"/*; do
        if [[ -f "$log" ]]; then
            echo "Last 10 lines of $(basename "$log"):"
            tail -10 "$log" | sed 's/^/  /'
            echo ""
        fi
    done
else
    echo "✗ No log directory"
fi

echo "=== Recent Commands ==="
echo "Last 20 commands from history mentioning 'nas':"
if is_macos; then
    # macOS with zsh
    [[ -f ~/.zsh_history ]] && grep -i nas ~/.zsh_history | tail -20 | sed 's/^/  /'
else
    # Linux with bash
    history | grep -i nas | tail -20 | sed 's/^/  /'
fi
echo ""

echo "=== Debug Mount Attempt ==="
echo "Attempting to mount first share with verbose output..."
if [[ -f "mount.sh" ]] && [[ -n "${SHARES:-}" ]]; then
    echo "Running: bash -x mount.sh mount (showing mount commands only)"
    bash -x mount.sh mount 2>&1 | grep -E "(mount_smbfs|eval.*mount|progress.*Mount)" | sed 's/^/  /'
else
    echo "✗ Cannot run mount test"
fi

echo ""
echo "=== Manual Mount Test ==="
if [[ -n "${SHARES:-}" ]] && [[ -n "${NAS_HOST:-}" ]] && [[ -n "${NAS_USER:-}" ]] && [[ -n "${NAS_PASS:-}" ]]; then
    share="${SHARES[0]}"
    mount_point="$(get_mount_root)/${MOUNT_DIR_PREFIX}${share}"
    echo "Testing manual mount of $share:"
    echo "  Mount point: $mount_point"
    echo "  Is currently mounted: $(is_mounted "$mount_point" && echo "YES" || echo "NO")"
    echo ""
    echo "  Try this command manually (contains password):"
    echo "    $(get_mount_command "$share" "$mount_point")"
fi

echo ""
echo "=== End Debug Report ==="