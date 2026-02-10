#!/bin/bash
#
# OpenWrt 软件包源配置脚本
# 添加第三方软件包仓库到 feeds.conf.default
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

log_info "正在配置额外的软件包源..."

# 添加 PassWall 软件包源
if ! grep -q "passwall_packages" feeds.conf.default 2>/dev/null; then
    sed -i '1i src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main' feeds.conf.default
    log_success "已添加 PassWall 软件包源"
else
    log_info "PassWall 软件包源已存在"
fi

# 添加 PassWall Luci 源
if ! grep -q "passwall_luci" feeds.conf.default 2>/dev/null; then
    sed -i '2i src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main' feeds.conf.default
    log_success "已添加 PassWall Luci 源"
else
    log_info "PassWall Luci 源已存在"
fi

log_success "软件包源配置完成"
