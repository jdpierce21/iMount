# Configuration System Simplification

## Summary of Changes

We've simplified the configuration system from 3 files to a clearer 2-file hierarchy:

### Before:
1. `lib/defaults.sh` - System defaults (with user override logic)
2. `~/.nas_mount_defaults` - Hidden user overrides in home directory
3. `config/config.sh` - Actual installation configuration

### After:
1. `lib/defaults.sh` - System defaults (read-only, part of codebase)
2. `config/defaults.sh` - User defaults (optional, in project directory)
3. `config/config.sh` - Actual installation configuration (no change)

## Key Improvements

1. **Clearer Separation**: 
   - `lib/` directory is read-only system files
   - `config/` directory contains all user-editable files

2. **Better Organization**:
   - No hidden files in home directory
   - All configuration in one place (config/ directory)
   - Example file provided as `config/defaults.sh.example`

3. **Backward Compatibility**:
   - Still reads `~/.nas_mount_defaults` if it exists
   - New location takes precedence if both exist
   - Migration script provided (`migrate_defaults.sh`)

## Migration

For users with existing `~/.nas_mount_defaults`:

```bash
# Option 1: Use the migration script
./migrate_defaults.sh

# Option 2: Manual migration
cp ~/.nas_mount_defaults config/defaults.sh
rm ~/.nas_mount_defaults
```

## Benefits

1. **Simpler to understand**: All user configuration in config/ directory
2. **Easier to manage**: No need to look in multiple places
3. **Better for version control**: Can include config/defaults.sh in .gitignore
4. **Cleaner home directory**: No hidden configuration files

## Files Changed

- `lib/defaults.sh` - Updated to check both locations
- `setup.sh` - Now saves to config/defaults.sh
- `show_defaults.sh` - Shows both locations and precedence
- `migrate_defaults.sh` - New script for migration
- `config/defaults.sh.example` - New example file
- Documentation updated to reflect new structure