# NAS Mount Manager

Automated mounting of network shares for macOS and Linux.

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

## License

MIT