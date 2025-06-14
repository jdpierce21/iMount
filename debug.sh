#!/bin/bash
# Debug script for NAS Mount Manager

# Save all output to file as well
REPORT_FILE="$HOME/nas_debug_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$REPORT_FILE")
exec 2>&1

echo "=== NAS Mount Manager Debug Report ==="
echo "Generated: $(date)"
echo "Report saved to: $REPORT_FILE"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load libraries
source lib/common.sh
source lib/platform.sh

# Enhanced debug mode
set -x 2>$HOME/debug_trace.log

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
    
    # Enhanced network diagnostics
    echo ""
    echo "Network diagnostics:"
    echo "  Route to NAS:"
    route get "$NAS_HOST" 2>&1 | grep -E "(interface:|gateway:|destination:)" | sed 's/^/    /'
    
    echo ""
    echo "  DNS resolution:"
    host "$NAS_HOST" 2>&1 | head -3 | sed 's/^/    /'
    
    echo ""
    echo "  ARP entry:"
    arp -n "$NAS_HOST" 2>&1 | sed 's/^/    /'
else
    echo "✗ NAS_HOST not configured"
fi
echo ""

echo "=== SMB/CIFS Diagnostics ==="
if [[ -n "${NAS_HOST:-}" ]]; then
    echo "SMB connection test:"
    
    # Test SMB connectivity
    echo "  Testing SMB port 445:"
    nc -zv -w2 "$NAS_HOST" 445 2>&1 | sed 's/^/    /'
    
    echo ""
    echo "  SMB shares visible (without auth):"
    smbutil view -N "//${NAS_HOST}" 2>&1 | head -20 | sed 's/^/    /'
    
    if [[ -n "${NAS_USER:-}" ]]; then
        echo ""
        echo "  SMB shares visible (with auth):"
        echo "  Command: smbutil view //${NAS_USER}@${NAS_HOST}"
        # Note: This will prompt for password
        echo "  (Skipping to avoid password prompt)"
    fi
    
    echo ""
    echo "  Current SMB mounts statistics:"
    smbutil statshares -a 2>&1 | sed 's/^/    /'
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

echo "=== macOS System Logs ==="
echo "Checking system logs for mount-related errors:"
echo "  Last 2 minutes of kernel/mount logs:"
log show --last 2m --predicate 'process == "kernel" OR process == "KernelEventAgent" OR process == "mount_smbfs" OR process == "NetAuthSysAgent"' 2>&1 | grep -v "DBG" | tail -20 | sed 's/^/    /'
echo ""

echo "=== Mount Process Diagnostics ==="
echo "Active mount processes:"
ps aux | grep -E "(mount|smb)" | grep -v grep | sed 's/^/  /'
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
    
    # Test actual mount with error capture
    echo ""
    echo "=== Live Mount Test ==="
    if is_mounted "$mount_point"; then
        echo "Share is already mounted. Testing access..."
        echo "Directory contents:"
        ls -la "$mount_point" 2>&1 | head -10
        echo ""
        echo "Attempting to create test file..."
        test_file="$mount_point/.nas_mount_test_$$"
        if touch "$test_file" 2>&1; then
            echo "✓ Write test successful"
            rm -f "$test_file"
        else
            echo "✗ Write test failed"
        fi
    else
        echo "Attempting to mount share with full error output..."
        echo "Command: mount_smbfs -N -o nobrowse \"//${NAS_USER}:****@${NAS_HOST}/${share}\" \"${mount_point}\""
        
        # Try mounting with error capture
        mount_output=$(mount_smbfs -N -o nobrowse "//${NAS_USER}:${NAS_PASS}@${NAS_HOST}/${share}" "${mount_point}" 2>&1)
        mount_result=$?
        
        if [[ $mount_result -eq 0 ]]; then
            echo "✓ Mount command returned success"
        else
            echo "✗ Mount command failed with exit code: $mount_result"
            echo "Error output: $mount_output"
        fi
        
        # Check if actually mounted
        if is_mounted "$mount_point"; then
            echo "✓ Share is now mounted"
            echo "Directory contents:"
            ls -la "$mount_point" 2>&1 | head -10
        else
            echo "✗ Share is NOT mounted despite command"
        fi
    fi
fi

echo ""
echo "=== Automated Test Sequence ==="
if [[ -n "${SHARES:-}" ]] && [[ -n "${NAS_HOST:-}" ]] && [[ -n "${NAS_USER:-}" ]] && [[ -n "${NAS_PASS:-}" ]]; then
    echo "Running full automated test..."
    echo ""
    
    # Test 1: Unmount all shares
    echo "TEST 1: Unmounting all shares..."
    ./mount.sh unmount
    echo ""
    
    # Test 2: Clear log and mount with full logging
    echo "TEST 2: Mounting shares with detailed logging..."
    echo "" > logs/nas_mount.log  # Clear log
    ./mount.sh mount
    echo ""
    
    # Test 3: Check what got logged
    echo "TEST 3: Log file analysis:"
    echo "  Total log lines: $(wc -l < logs/nas_mount.log | tr -d ' ')"
    echo "  DEBUG entries: $(grep -c DEBUG logs/nas_mount.log || echo 0)"
    echo "  INFO entries: $(grep -c INFO logs/nas_mount.log || echo 0)"
    echo "  ERROR entries: $(grep -c ERROR logs/nas_mount.log || echo 0)"
    echo ""
    echo "  Full log contents:"
    echo "  ===================="
    cat logs/nas_mount.log
    echo "  ===================="
    echo ""
    
    # Test 4: Verify each mount
    echo "TEST 4: Verifying each mount point..."
    for share in "${SHARES[@]}"; do
        mount_point="${MOUNT_ROOT}/${MOUNT_DIR_PREFIX}${share}"
        echo -n "  $share: "
        
        if mount | grep -q " ${mount_point} "; then
            echo -n "mounted, "
            file_count=$(ls -1 "$mount_point" 2>/dev/null | wc -l | tr -d ' ')
            echo "$file_count files"
        else
            echo "NOT MOUNTED"
        fi
    done
    echo ""
    
    # Test 5: Manual mount test of first share
    echo "TEST 5: Manual mount test..."
    share="${SHARES[0]}"
    mount_point="${MOUNT_ROOT}/${MOUNT_DIR_PREFIX}${share}"
    
    # First unmount it
    echo "  Unmounting $share..."
    umount "$mount_point" 2>/dev/null || true
    
    # Now mount manually
    echo "  Manually mounting $share..."
    echo "  Command: mount_smbfs -N -o nobrowse \"//${NAS_USER}:${NAS_PASS}@${NAS_HOST}/${share}\" \"${mount_point}\""
    mount_smbfs -N -o nobrowse "//${NAS_USER}:${NAS_PASS}@${NAS_HOST}/${share}" "${mount_point}"
    
    echo "  Checking contents:"
    ls -la "$mount_point" | head -10
    
    # Unmount again
    echo "  Cleaning up..."
    umount "$mount_point" 2>/dev/null || true
    
    # Test different SMB versions
    echo ""
    echo "TEST 6: SMB Protocol Version Tests..."
    for vers in "1.0" "2.0" "3.0" ""; do
        echo "  Testing SMB version: ${vers:-default}"
        
        # Build mount options
        if [[ -n "$vers" ]]; then
            mount_opts="-N -o nobrowse,vers=${vers}"
        else
            mount_opts="-N -o nobrowse"
        fi
        
        # Try mount
        echo "    Command: mount_smbfs ${mount_opts} \"//${NAS_USER}:****@${NAS_HOST}/${share}\" \"${mount_point}\""
        
        if mount_smbfs ${mount_opts} "//${NAS_USER}:${NAS_PASS}@${NAS_HOST}/${share}" "${mount_point}" 2>$HOME/mount_err_${vers:-default}.log; then
            echo "    ✓ Mount succeeded"
            
            # Check if accessible
            if ls "$mount_point" >/dev/null 2>&1; then
                file_count=$(ls -1 "$mount_point" 2>/dev/null | wc -l | tr -d ' ')
                echo "    ✓ Mount accessible with $file_count items"
            else
                echo "    ✗ Mount succeeded but not accessible"
            fi
            
            # Show mount info
            mount | grep "$mount_point" | sed 's/^/      /'
            
            # Unmount
            umount "$mount_point" 2>/dev/null || true
        else
            echo "    ✗ Mount failed"
            echo "    Error: $(cat $HOME/mount_err_${vers:-default}.log)"
        fi
        echo ""
    done
    
    # Test with delay after mount
    echo "TEST 7: Mount with access delay test..."
    echo "  Mounting and waiting before access..."
    
    if mount_smbfs -N -o nobrowse "//${NAS_USER}:${NAS_PASS}@${NAS_HOST}/${share}" "${mount_point}" 2>&1; then
        echo "  Mount command completed"
        
        # Check mount table immediately
        echo "  Mount table check:"
        mount | grep "$mount_point" | sed 's/^/    /'
        
        # Try accessing with delays
        for delay in 0 0.5 1 2; do
            echo "  After ${delay}s delay:"
            sleep "$delay"
            
            if ls "$mount_point" >/dev/null 2>&1; then
                file_count=$(ls -1 "$mount_point" 2>/dev/null | wc -l | tr -d ' ')
                echo "    ✓ Accessible with $file_count items"
                break
            else
                echo "    ✗ Not accessible yet"
            fi
        done
        
        # Cleanup
        umount "$mount_point" 2>/dev/null || true
    fi
else
    echo "Cannot run automated tests - configuration not loaded"
fi

echo ""
echo "=== Stale Mount Detection ==="
echo "Checking for potentially stale mounts..."
for share in "${SHARES[@]}"; do
    mount_point="${MOUNT_ROOT}/${MOUNT_DIR_PREFIX}${share}"
    
    if mount | grep -q " ${mount_point} "; then
        echo "  $share is in mount table"
        
        # Test 1: Can we stat the mount point?
        if stat "$mount_point" >/dev/null 2>&1; then
            echo "    ✓ stat succeeds"
        else
            echo "    ✗ stat fails - likely stale"
        fi
        
        # Test 2: Can we ls the mount?
        if timeout 2 ls "$mount_point" >/dev/null 2>&1; then
            echo "    ✓ ls succeeds"
        else
            echo "    ✗ ls fails/hangs - likely stale"
        fi
        
        # Test 3: Check df status
        if df "$mount_point" >/dev/null 2>&1; then
            echo "    ✓ df succeeds"
        else
            echo "    ✗ df fails - likely stale"
        fi
    fi
done

echo ""
echo "=== Mount Command Variations ==="
if [[ -n "${SHARES:-}" ]] && [[ -n "${NAS_HOST:-}" ]] && [[ -n "${NAS_USER:-}" ]] && [[ -n "${NAS_PASS:-}" ]]; then
    share="${SHARES[0]}"
    mount_point="${MOUNT_ROOT}/${MOUNT_DIR_PREFIX}${share}"
    
    # Ensure unmounted
    umount "$mount_point" 2>/dev/null || true
    
    echo "Testing different mount command formats:"
    
    # Test 1: With explicit port
    echo "  1. With explicit port 445:"
    echo "    Command: mount_smbfs -N -o nobrowse,port=445 \"//${NAS_USER}:****@${NAS_HOST}/${share}\" \"${mount_point}\""
    if mount_smbfs -N -o nobrowse,port=445 "//${NAS_USER}:${NAS_PASS}@${NAS_HOST}/${share}" "${mount_point}" 2>&1; then
        echo "    ✓ Mount succeeded"
        file_count=$(ls -1 "$mount_point" 2>/dev/null | wc -l | tr -d ' ')
        echo "    Files visible: $file_count"
        umount "$mount_point" 2>/dev/null || true
    else
        echo "    ✗ Mount failed"
    fi
    
    # Test 2: With soft option
    echo "  2. With soft mount option:"
    echo "    Command: mount_smbfs -N -o nobrowse,soft \"//${NAS_USER}:****@${NAS_HOST}/${share}\" \"${mount_point}\""
    if mount_smbfs -N -o nobrowse,soft "//${NAS_USER}:${NAS_PASS}@${NAS_HOST}/${share}" "${mount_point}" 2>&1; then
        echo "    ✓ Mount succeeded"
        file_count=$(ls -1 "$mount_point" 2>/dev/null | wc -l | tr -d ' ')
        echo "    Files visible: $file_count"
        umount "$mount_point" 2>/dev/null || true
    else
        echo "    ✗ Mount failed"
    fi
fi

echo ""
echo "=== Debug Trace Log ==="
if [[ -f $HOME/debug_trace.log ]]; then
    echo "Script execution trace (last 50 lines):"
    tail -50 $HOME/debug_trace.log | sed 's/^/  /'
fi

echo ""
echo "=== End Debug Report ==="