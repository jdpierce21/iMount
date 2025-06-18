# Logging System

## Overview
The NAS Mount Manager includes a built-in logging system for troubleshooting purposes.

## Configuration
Logging configuration is defined in `lib/common.sh`:

| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_MAX_SIZE_MB` | 10 | Maximum log file size in MB before rotation |
| `LOG_MAX_FILES` | 5 | Number of rotated log files to keep |
| `LOG_MAX_AGE_DAYS` | 30 | Delete log files older than this many days |

These can be overridden using environment variables:
```bash
export LOG_MAX_SIZE_MB=20
export LOG_MAX_FILES=10
./menu.sh
```

## Log Location
- **Primary log**: `logs/nas_mount.log`
- **Rotated logs**: `logs/nas_mount.log.1`, `logs/nas_mount.log.2`, etc.

## Log Levels
- `INFO` - General information
- `ERROR` - Error conditions
- `DEBUG` - Detailed debugging information
- `TROUBLESHOOT` - Specific troubleshooting information

## Usage in Scripts

### Basic Logging
```bash
source lib/common.sh

log_info "Operation completed successfully"
log_error "Failed to mount share: $share"
log_debug "Variable state: var=$var"
log_troubleshoot "Mount failed" "Permission denied for user $USER"
```

### Troubleshooting Logger
The `log_troubleshoot` function is designed for logging issues:
```bash
# Simple message
log_troubleshoot "Connection test failed"

# With details
log_troubleshoot "Mount operation failed" "Share: $share, Error: $error_msg"
```

## Log Rotation
- Logs are automatically rotated when they exceed `LOG_MAX_SIZE_MB`
- Old logs are automatically deleted after `LOG_MAX_AGE_DAYS`
- Rotation happens on each write if needed

## Viewing Logs
```bash
# View current log
less logs/nas_mount.log

# View last 50 lines
tail -50 logs/nas_mount.log

# Follow log in real-time
tail -f logs/nas_mount.log

# Search for errors
grep ERROR logs/nas_mount.log

# Search for troubleshooting entries
grep TROUBLESHOOT logs/nas_mount.log
```