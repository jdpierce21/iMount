# Changelog

All notable changes to the NAS Mount Manager project will be documented in this file.

## [Unreleased] - 2025-01-14

### Fixed
- **Unmount hanging issue** - Implemented robust timeout mechanism with background process monitoring
  - Added `unmount_with_timeout()` function that kills hung unmount processes after timeout
  - Tries multiple unmount strategies: standard unmount, diskutil (macOS), and force unmount
  - Each strategy has configurable timeout (3 seconds for normal, 2 seconds for force)
  
- **Cleanup script stdin handling** - Fixed hanging when run via curl installation
  - Added stdin redirection to `/dev/tty` when not in interactive mode
  - Ensures proper terminal input for prompts during curl pipe execution
  - Redirects stdin to `/dev/null` for mount.sh unmount to prevent consumption

- **Busy mount handling** - Enhanced unmount robustness on macOS
  - Uses `diskutil unmount` as fallback for busy mounts
  - Implements force unmount as last resort
  - Properly handles mount points with spaces in paths

- **Stale mount detection** - Improved mount verification
  - Checks if mount is actually accessible with `ls` before considering it mounted
  - Automatically unmounts stale mounts before remounting
  - Prevents "already mounted" false positives

### Added
- **Comprehensive debug script** - Enhanced troubleshooting capabilities
  - Network connectivity and SMB diagnostics
  - Mount command variations testing
  - SMB protocol version testing
  - Automated test sequences
  - Stale mount detection
  - All output saved to timestamped log files

- **Centralized logging** - All debug output to logs directory
  - Debug reports saved with timestamps
  - Trace logs for detailed execution flow
  - Error logs for each mount attempt
  - Automatic cleanup of old logs (keeps last 10)

### Changed
- **Mount verification** - Added delay and retry logic for SMB mounts
  - Waits up to 2 seconds for mount to become accessible
  - Checks mount table and actual accessibility
  - More reliable mount success detection

## Previous Versions

### Error Handling Improvements
- Removed strict `set -e` that could cause silent exits
- Added proper error handling for read commands
- Default values for failed user input reads

### Installation Enhancements
- Fixed hang during reinstallation
- Proper cleanup of existing mounts
- Better handling of existing installations

### Platform Support
- Linux mount commands with proper permissions
- macOS LaunchAgent configuration
- Cross-platform mount detection

## Notes

This project follows semantic versioning. For detailed commit history, see the git log.