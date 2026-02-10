# Project Architecture

## Overview

This project uses a modular architecture to build OpenWrt firmware images through GitHub Actions.

## Directory Structure

```
refactoring/
├── .github/workflows/          # CI/CD pipeline definitions
│   ├── build-lede.yml         # LEDE build workflow
│   ├── build-immortalwrt.yml  # ImmortalWrt build workflow
│   └── cleanup.yml            # Cleanup workflow
│
├── configs/                    # OpenWrt build configurations
│   ├── lede-full.config       # LEDE full version
│   ├── lede-mini.config       # LEDE mini version
│   ├── immortalwrt-full.config
│   └── immortalwrt-mini.config
│
├── scripts/                    # Build and customization scripts
│   ├── lib/
│   │   └── common.sh          # Shared functions library
│   ├── customize-full.sh      # Full version customizations
│   ├── customize-mini.sh      # Mini version customizations
│   ├── setup-feeds.sh         # Feed configuration
│   ├── build.sh               # Build with retry logic
│   └── update-immortalwrt-version.sh
│
├── patches/                    # Patch and fix scripts
│   ├── init-settings.sh       # First-boot configuration
│   ├── fix-versions.sh        # Version fixes
│   └── update-network.sh      # Network configuration
│
├── images/                     # Theme images
│   └── background.jpg         # Argon theme background
│
└── docs/                       # Documentation
    └── ARCHITECTURE.md        # This file
```

## Workflow Architecture

### Build Pipeline

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Prepare   │────▶│    Build    │────▶│   Release   │
│   (Setup)   │     │  (Compile)  │     │  (Publish)  │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   │
       ▼                   ▼
┌─────────────┐     ┌─────────────┐
│ Clone Source│     │ Full Build  │
│ Get Info    │     │ Mini Build  │
└─────────────┘     │ (Matrix)    │
                    └─────────────┘
```

### Script Dependencies

```
scripts/
├── lib/common.sh (shared by all)
│
├── customize-full.sh
│   └── lib/common.sh
│
├── customize-mini.sh
│   └── lib/common.sh
│
├── setup-feeds.sh
│   └── lib/common.sh
│
├── build.sh (standalone)
│
└── update-immortalwrt-version.sh (standalone)
```

## Key Design Decisions

### 1. Modular Scripts

- **Library Pattern**: `lib/common.sh` provides shared functions
- **Separation of Concerns**: Each script has a single responsibility
- **Reusability**: Scripts can be run independently

### 2. Configuration Management

- Clear naming convention: `{source}-{variant}.config`
- Version controlled configurations
- Easy to add new variants

### 3. Error Handling

- `set -euo pipefail` in all scripts
- Retry logic for network operations
- Proper exit codes

### 4. Source Abstraction

The `detect_source_type()` function in `lib/common.sh` allows scripts to work with both LEDE and ImmortalWrt sources without modification.

## Extension Points

### Adding a New Source

1. Create workflow: `.github/workflows/build-{source}.yml`
2. Add detection in `lib/common.sh`
3. Add source-specific logic in customization scripts

### Adding a New Variant

1. Create config: `configs/{source}-{variant}.config`
2. Add to workflow matrix
3. Create customization script if needed

### Adding a New Plugin

1. Add clone command in `customize-full.sh` or `customize-mini.sh`
2. Update relevant configuration file

## Build Process Flow

1. **Prepare Phase**
   - Maximize disk space
   - Clone source repository
   - Extract git information

2. **Build Phase (Matrix)**
   - Free disk space
   - Initialize environment
   - Setup scripts and feeds
   - Update and install feeds
   - Apply patches
   - Apply customizations
   - Download dependencies
   - Compile firmware
   - Organize artifacts

3. **Release Phase**
   - Download all artifacts
   - Prepare release notes
   - Create GitHub Release

## Security Considerations

- No secrets in code (use GitHub Secrets)
- Minimal permissions in workflows
- Input validation in scripts
- Safe file operations (mktemp, backups)
