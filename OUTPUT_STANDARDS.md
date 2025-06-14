# Output Standards

## Core Principles
1. **One style**: Every message uses the same format
2. **One line**: Each operation outputs one line (unless error)
3. **One source**: All output goes through lib/output.sh functions

## Message Formats

### Sections (Major Transitions)
```
=== Installation ===
=== Configuration ===
=== Cleanup ===
```

### Prompts (User Input)
```
Host [192.168.1.100]: 
Username: 
Password: 
Mount location [/home/user/nas_mounts]: 
Auto-mount at login? [Y/n] 
Delete credentials? [y/N] 
```

Rules:
- Question text followed by space
- Default in brackets if applicable
- Colon and space at end
- Y/n = default Yes, y/N = default No

### Progress Messages
```
Downloading repository... ✓
Writing configuration... ✓
Configuring auto-mount... ✓
Creating mount points... ✗
```

Rules:
- Present progressive tense
- Three dots
- Space before result
- ✓ for success, ✗ for failure

### Status Messages
```
✓ Installation complete
✗ Mount failed: Permission denied
```

Rules:
- Start with ✓ or ✗
- Space after symbol
- Brief description
- Error includes colon and reason

### Information
```
Note: Requires sudo on Linux
Using existing credentials
Commands: nas-mount, nas-unmount, nas-status
```

Rules:
- Only for essential information
- "Note:" prefix for warnings/important info
- No prefix for simple statements
- Keep extremely brief

## Function Mapping

| Purpose | Function | Example |
|---------|----------|---------|
| Section header | print_section | `=== Installation ===` |
| User prompt | prompt | `Host [192.168.1.100]: ` |
| Yes/no prompt | prompt_yn | `Continue? [Y/n] ` |
| Progress start | progress | `Downloading repository... ` |
| Progress end | progress_done | `✓` |
| Progress fail | progress_fail | `✗` |
| Success message | success | `✓ Installation complete` |
| Error message | error | `✗ Error: File not found` |
| Information | info | `Note: Requires sudo` |
| Simple message | message | `Using existing credentials` |

## Examples

### Installation Flow
```
=== Installation ===
Downloading repository... ✓
Host [192.168.1.100]: 
Shares [documents media]: 
Using existing credentials
Mount location [/home/user/nas_mounts]: 
Auto-mount at login? [Y/n] 
Create aliases? [Y/n] 
Writing configuration... ✓
Configuring auto-mount... ✓
✓ Installation complete
Commands: nas-mount, nas-unmount, nas-status
```

### Error Flow
```
=== Installation ===
Downloading repository... ✗
✗ Error: Failed to connect to GitHub
  Check your internet connection
```

### Cleanup Flow
```
=== Cleanup ===
This will remove all configurations. Continue? [Y/n] 
Unmounting shares... ✓
Removing auto-mount... ✓
Delete credentials? [y/N] 
Remove scripts? [Y/n] 
✓ Cleanup complete
```

## Implementation Rules

1. **No direct echo**: All output through output.sh functions
2. **No inline formatting**: No hardcoded symbols or colors
3. **No variations**: Same operation always produces same message
4. **No verbosity**: Minimum necessary information only
5. **No blank lines**: Except between major sections
6. **No repeated messages**: Each status reported once