# NAS Mount Manager Requirements

## Project Overview
Cross-platform tool to automatically mount network shares with minimal user interaction.

## Functional Requirements

### Core Features
1. **Installation**
   - One-command installation via curl
   - Detect and handle existing installations
   - Configure auto-mount at login
   - Create command aliases

2. **Mount Management**
   - Mount/unmount network shares
   - Check mount status
   - Validate mount health
   - Auto-reconnect on network changes

3. **Configuration**
   - Store credentials securely (600 permissions)
   - Support multiple shares
   - Platform-specific mount commands
   - User-configurable mount location

4. **Cleanup**
   - Complete removal of all components
   - Preserve or delete credentials (user choice)
   - Remove or keep script directory (user choice)

### Platform Support
- macOS: Using mount_smbfs and LaunchAgent
- Linux: Using mount.cifs and systemd user service

## Technical Requirements

### Code Standards
1. **No Duplication**
   - Single source of truth for all functions
   - Centralized configuration
   - Shared constants in one location

2. **No Hardcoded Values**
   - All paths derived from functions
   - All messages in constants
   - All defaults in configuration

3. **Error Handling**
   - Exit on first error (set -euo pipefail)
   - Clear error messages with context
   - Proper cleanup on failure

4. **Modularity**
   - One script = one responsibility
   - Shared functions in dedicated file
   - Clear separation of concerns

### Output Standards

#### General Rules
1. **Consistency**: All output follows same format
2. **Brevity**: One line per operation unless error
3. **Clarity**: Plain English, no jargon
4. **Uniformity**: Same style throughout all scripts

#### Output Format Specification
```
# Section headers (major transitions)
=== Section Name ===

# User prompts (all follow same pattern)
Question [default]: 

# Status messages (operation... result)
Operation description... [OK|FAIL]

# Final status (at end of major operations)
✓ Operation complete

# Errors (always include context)
✗ Error: Description
  Detail or suggestion

# Information (minimal, only when essential)
Note: Important information
```

#### Message Types
1. **PROMPT**: "Question [default]: "
2. **PROGRESS**: "Action in progress... "
3. **SUCCESS**: "✓" (after progress) or "✓ Message"
4. **ERROR**: "✗ Error: Message"
5. **INFO**: "Note: Message"
6. **SECTION**: "=== Title ==="

### File Structure
```
nas_mounts/
├── install.sh              # Entry point, handles curl installation
├── setup.sh                # Core setup logic
├── cleanup.sh              # Removal script
├── mount.sh                # Mount/unmount/status operations
├── lib/
│   ├── common.sh          # Shared functions and constants
│   ├── output.sh          # Output formatting functions
│   └── platform.sh        # Platform-specific logic
└── config/
    └── config.sh          # User configuration (generated)
```

### Script Responsibilities

#### install.sh
- Handle curl pipe installation
- Clone/update repository
- Detect existing installation
- Hand off to setup.sh or cleanup.sh

#### setup.sh
- Gather user configuration
- Create config file
- Install platform services
- Configure auto-start
- Add shell aliases

#### cleanup.sh
- Remove all components
- Handle user choices for credentials/directory
- Offer reinstallation

#### mount.sh
- Mount shares
- Unmount shares
- Show status
- Validate mounts

#### lib/common.sh
- Path functions
- Credential management
- Configuration loading
- Error handling

#### lib/output.sh
- All print functions
- Consistent formatting
- No direct echo in other scripts

#### lib/platform.sh
- OS detection
- Platform-specific mount commands
- Service management

## Design Principles
1. **Single Responsibility**: Each function/script does one thing
2. **DRY**: Don't Repeat Yourself - ever
3. **Fail Fast**: Exit immediately on errors
4. **Explicit**: No magic, no hidden behavior
5. **Predictable**: Same input = same output
6. **Maintainable**: Clear code over clever code