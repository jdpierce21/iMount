#!/bin/bash
# Fix LaunchAgent for NAS mounts on Mac

echo "Fixing NAS mount LaunchAgent..."

# Create the plist file
cat > ~/Library/LaunchAgents/com.user.nasmount.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.nasmount</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/jpierce/scripts/nas_mounts/mount.sh</string>
        <string>mount</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/Users/jpierce/scripts/nas_mounts/logs/launchagent.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/jpierce/scripts/nas_mounts/logs/launchagent.err</string>
</dict>
</plist>
EOF

# Unload if already loaded
launchctl unload ~/Library/LaunchAgents/com.user.nasmount.plist 2>/dev/null || true

# Load the agent
launchctl load ~/Library/LaunchAgents/com.user.nasmount.plist

# Check if loaded
if launchctl list | grep -q com.user.nasmount; then
    echo "✓ LaunchAgent successfully loaded"
    echo "The NAS mounts will now persist across reboots"
else
    echo "✗ Failed to load LaunchAgent"
    echo "You may need to run this script directly on your Mac (not via SSH)"
fi