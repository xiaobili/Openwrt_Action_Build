#!/bin/bash
#
# OpenWrt 固件完整版自定义脚本
# 添加插件、主题和配置
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

print_header "customize-full.sh"

# ============================================
# 通用插件（适用于所有源码）
# ============================================

add_common_plugins() {
    log_info "正在添加通用插件..."

    # OpenAppFilter - 应用过滤
    log_info "添加 OpenAppFilter..."
    git clone --depth=1 https://github.com/destan19/OpenAppFilter.git package/OpenAppFilter || log_warn "添加 OpenAppFilter 失败"

    # Openlist - 域名列表管理
    log_info "添加 Openlist..."
    git clone --depth=1 https://github.com/sbwml/luci-app-openlist2.git package/openlist || log_warn "添加 Openlist 失败"

    # NetSpeedTest - 网速测试
    log_info "添加 NetSpeedTest..."
    git clone --depth=1 https://github.com/sirpdboy/luci-app-netspeedtest.git package/netspeedtest || log_warn "添加 NetSpeedTest 失败"

    # 复制 Argon 主题背景
    copy_argon_background
}

# ============================================
# LEDE 源码特定配置
# ============================================

configure_lede() {
    log_info "正在配置 LEDE 源码..."

    local date_version
    date_version=$(date +"%y.%m.%d")

    # 尝试多个可能的默认设置文件路径
    local settings_files=(
        "package/lean/default-settings/files/zzz-default-settings"
        "package/default-settings/files/zzz-default-settings"
        "files/etc/zzz-default-settings"
    )

    local settings_updated=false
    for settings_file in "${settings_files[@]}"; do
        if [[ -f "$settings_file" ]]; then
            log_info "找到设置文件: $settings_file"
            if update_version_string "$settings_file" "R${date_version} by billyJR"; then
                settings_updated=true
                break
            fi
        fi
    done

    if [[ "$settings_updated" == false ]]; then
        log_warn "无法更新 LEDE 版本字符串"
    fi

    log_success "LEDE 配置完成"
}

# ============================================
# ImmortalWrt 源码特定配置
# ============================================

configure_immortalwrt() {
    log_info "正在配置 ImmortalWrt 源码..."

    # 更新版本信息
    if [[ -f "$SCRIPT_DIR/update-immortalwrt-version.sh" ]]; then
        "$SCRIPT_DIR/update-immortalwrt-version.sh"
    else
        log_warn "未找到 update-immortalwrt-version.sh"
    fi

    # 添加 AdGuardHome
    log_info "添加 AdGuardHome..."
    git_sparse_clone openwrt-23.05 https://github.com/coolsnowwolf/luci applications/luci-app-adguardhome 2>/dev/null || {
        log_warn "稀疏克隆失败，尝试直接克隆..."
        git clone --depth=1 https://github.com/coolsnowwolf/luci-app-adguardhome.git package/luci-app-adguardhome 2>/dev/null || true
    }

    # 添加 MosDNS
    log_info "添加 MosDNS..."
    find ./ -name "*mosdns*" -type f -name "Makefile" -delete 2>/dev/null || true
    git clone --depth=1 https://github.com/sbwml/luci-app-mosdns -b v5 package/mosdns 2>/dev/null || log_warn "添加 MosDNS 失败"

    log_success "ImmortalWrt 配置完成"
}

# ============================================
# 主执行流程
# ============================================

main() {
    add_common_plugins

    local source_type
    source_type=$(detect_source_type)
    log_info "检测到的源码类型: $source_type"

    case "$source_type" in
        lede)
            configure_lede
            ;;
        immortalwrt)
            configure_immortalwrt
            ;;
        *)
            log_warn "未知的源码类型，应用通用配置"
            ;;
    esac

    print_footer "customize-full.sh"
}

main "$@"
