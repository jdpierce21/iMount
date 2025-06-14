# NAS Mount Manager

Automated mounting of network shares for macOS and Linux with robust error handling and timeout mechanisms.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/jdpierce21/nas_mount/master/install.sh | bash
```

## Usage

```bash
nas-mount      # Mount all shares
nas-unmount    # Unmount all shares  
nas-status     # Show mount status
```

## Removal

```bash
~/scripts/nas_mounts/cleanup.sh
```

## Requirements

- macOS: No additional requirements
- Linux: cifs-utils package

## Recent Improvements (2025)

### Enhanced Unmount Operations
- **Timeout mechanism**: Prevents hanging during unmount operations with configurable timeouts
- **Multiple unmount strategies**: Tries standard unmount, diskutil (macOS), and force unmount
- **Non-blocking approach**: Uses background processes with timeout monitoring
- **Robust cleanup**: Handles stale mounts and busy filesystems

### Fixed Installation Issues
- **Stdin handling**: Fixed cleanup script hanging when run via curl
- **Busy mount handling**: Uses diskutil for unmounting busy mounts on macOS
- **Reinstall support**: Properly handles unmounting during reinstallation

### Improved Mount Verification
- **Stale mount detection**: Checks if mounts are accessible before considering them mounted
- **Retry logic**: Adds delay and retry for SMB mount verification
- **Better error handling**: Captures and logs mount errors comprehensively

### Enhanced Debugging
- **Centralized logging**: All debug output goes to the logs directory
- **Comprehensive debug script**: Extensive diagnostics including network, SMB, and mount tests
- **Trace logging**: Detailed execution traces for troubleshooting

## Architecture

### Directory Structure
```
nas_mounts/
├── install.sh       # Entry point for curl installation
├── setup.sh         # Core setup and configuration
├── cleanup.sh       # Complete removal with timeout handling
├── mount.sh         # Mount/unmount/status operations
├── debug.sh         # Comprehensive debugging tool
├── lib/
│   ├── common.sh      # Shared functions and constants
│   ├── defaults.sh    # System defaults (do not edit)
│   ├── output.sh      # Consistent output formatting
│   └── platform.sh    # Platform-specific mount commands
├── config/
│   ├── defaults.sh    # User defaults (optional)
│   └── config.sh      # Installation configuration
├── logs/             # All debug and error logs
└── tests/            # Test scripts for development
```

### Key Features

- **Cross-platform**: Supports macOS (mount_smbfs) and Linux (mount.cifs)
- **Auto-mount**: LaunchAgent (macOS) or systemd (Linux) for login mounting
- **Secure credentials**: Stored with 600 permissions in home directory
- **Consistent output**: All messages follow standardized format
- **Error recovery**: Handles network interruptions and stale mounts
- **Clean uninstall**: Complete removal with optional credential preservation

## Troubleshooting

Run the debug script for comprehensive diagnostics:
```bash
~/scripts/nas_mounts/debug.sh
```

This will generate a detailed report including:
- System and network connectivity
- Mount status and accessibility
- Configuration verification
- SMB protocol testing
- Recent error logs

## Configuration

The NAS Mount Manager uses a simple configuration hierarchy:

1. **System Defaults** (`lib/defaults.sh`) - Built-in defaults
2. **User Defaults** (`config/defaults.sh`) - Optional overrides
3. **Installation Config** (`config/config.sh`) - Actual settings

To customize defaults:
```bash
cp config/defaults.sh.example config/defaults.sh
# Edit config/defaults.sh with your preferences
```

See [DEFAULTS.md](DEFAULTS.md) for detailed configuration options.

## License

MIT