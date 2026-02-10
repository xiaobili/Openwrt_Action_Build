# OpenWrt Automated Build Project

<div align="center">

[![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/xiaobili/Openwrt_Action_Build/build-lede.yml?style=for-the-badge&logo=openwrt&label=LEDE)](https://github.com/xiaobili/OpenWrt_Action_Build/actions)
[![License](https://img.shields.io/github/license/mashape/apistatus.svg?style=for-the-badge&logo=github)](https://github.com/xiaobili/OpenWrt_Action_Build/blob/master/LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/xiaobili/OpenWrt_Action_Build?display_name=release&style=for-the-badge&logo=github)](https://github.com/xiaobili/OpenWrt_Action_Build/releases/latest)

**Automated OpenWrt Firmware Builder** | **CI/CD Pipeline** | **Multi-Source Support**

</div>

---

## Features

- **Continuous Integration** - GitHub Actions powered automated build pipeline
- **Multi-Source Support** - Build from both LEDE and ImmortalWrt sources
- **Dual Versions** - Full and Mini firmware variants
- **Parallel Builds** - Matrix strategy for simultaneous builds
- **Rich Plugins** - Pre-configured with popular packages
- **Theme Customization** - Argon theme with custom background
- **Automatic Versioning** - Compile date based version strings

---

## Build Workflows

| Workflow | Description | File |
|----------|-------------|------|
| **Build LEDE Firmware** | Build LEDE source (Full + Mini) | [build-lede.yml](.github/workflows/build-lede.yml) |
| **Build ImmortalWrt Firmware** | Build ImmortalWrt source (Full + Mini) | [build-immortalwrt.yml](.github/workflows/build-immortalwrt.yml) |
| **Cleanup** | Remove old workflow runs and releases | [cleanup.yml](.github/workflows/cleanup.yml) |

---

## Project Structure

```
.
├── .github/workflows/      # GitHub Actions workflows
├── configs/                # OpenWrt configuration files
├── docs/                   # Documentation
├── images/                 # Theme images and assets
├── patches/                # Patch scripts for fixes
├── scripts/                # Build and customization scripts
│   └── lib/                # Shared library functions
├── LICENSE                 # MIT License
└── README.md               # This file
```

---

## Configuration Files

| File | Description |
|------|-------------|
| [lede-full.config](configs/lede-full.config) | LEDE Full version configuration |
| [lede-mini.config](configs/lede-mini.config) | LEDE Mini version configuration |
| [immortalwrt-full.config](configs/immortalwrt-full.config) | ImmortalWrt Full configuration |
| [immortalwrt-mini.config](configs/immortalwrt-mini.config) | ImmortalWrt Mini configuration |

---

## Scripts

### Customization Scripts

| Script | Purpose |
|--------|---------|
| [customize-full.sh](scripts/customize-full.sh) | Full version customizations |
| [customize-mini.sh](scripts/customize-mini.sh) | Mini version customizations |
| [setup-feeds.sh](scripts/setup-feeds.sh) | Add third-party package feeds |

### Build Scripts

| Script | Purpose |
|--------|---------|
| [build.sh](scripts/build.sh) | Build with retry logic |
| [update-immortalwrt-version.sh](scripts/update-immortalwrt-version.sh) | Update ImmortalWrt version |
| [lib/common.sh](scripts/lib/common.sh) | Shared library functions |

### Patch Scripts

| Script | Purpose |
|--------|---------|
| [init-settings.sh](patches/init-settings.sh) | First-boot initialization |
| [fix-versions.sh](patches/fix-versions.sh) | Fix package versions (golang, etc.) |
| [update-network.sh](patches/update-network.sh) | Network interface configuration |

---

## Included Plugins

### System Plugins
- **OpenAppFilter** - Application filtering
- **PassWall** - Proxy solution
- **NetSpeedTest** - Network speed testing

### Network Tools
- **AdGuardHome** - Ad blocking (ImmortalWrt only)
- **MosDNS** - DNS resolution (ImmortalWrt only)

### UI Enhancements
- **Argon Theme** - Modern web interface with custom background

---

## Build Process

1. **Environment Setup** - Install dependencies, free disk space
2. **Source Clone** - Clone OpenWrt source code
3. **Feed Setup** - Add custom package feeds
4. **Patch Application** - Apply fixes and customizations
5. **Package Installation** - Install selected packages
6. **Configuration** - Apply build configuration
7. **Download** - Download package sources
8. **Compilation** - Build firmware images
9. **Release** - Upload to GitHub Releases

---

## Usage

### Manual Trigger

1. Go to GitHub Actions tab
2. Select a workflow (Build LEDE or Build ImmortalWrt)
3. Click "Run workflow"

### Scheduled Builds

Edit the workflow file and uncomment the schedule section:

```yaml
on:
  workflow_dispatch:
  schedule:
    - cron: '0 16 */3 * *'  # Every 3 days at 16:00 UTC
```

### Customization

1. Modify configuration files in `configs/`
2. Edit customization scripts in `scripts/`
3. Commit and push changes
4. Trigger a new build

---

## Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| OS | Ubuntu 22.04 | Ubuntu 22.04 |
| CPU | 4 cores | 8+ cores |
| Memory | 8 GB | 16+ GB |
| Disk | 20 GB | 50+ GB |

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CACHE_TOOLCHAIN` | Enable toolchain caching | `true` |
| `FIRMWARE_RELEASE` | Upload to GitHub Releases | `true` |
| `FIX_GOLANG` | Fix golang version for xray | `true` |
| `TZ` | Timezone | `Asia/Shanghai` |

---

## License

This project is licensed under the [MIT License](LICENSE).

Copyright 2019-2020 P3TERX, 2024 billyJR

---

## Acknowledgments

- [LEDE](https://github.com/coolsnowwolf/lede) - Lean's LEDE source
- [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) - ImmortalWrt source
- [OpenWrt](https://openwrt.org/) - The OpenWrt project
