#!/bin/bash
#
# OpenWrt 构建脚本的公共函数库
# 作者: billyJR
#

set -euo pipefail

# 输出颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # 无颜色

# 日志函数
log_info() {
    echo -e "${BLUE}[信息]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[成功]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[警告]${NC} $*"
}

log_error() {
    echo -e "${RED}[错误]${NC} $*" >&2
}

# 检查是否在 GitHub Actions 环境中运行
is_github_actions() {
    [[ -n "${GITHUB_WORKSPACE:-}" ]]
}

# 获取工作目录
get_workspace() {
    if is_github_actions; then
        echo "$GITHUB_WORKSPACE"
    else
        cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
    fi
}

# 从环境变量检测源码类型
detect_source_type() {
    # 方法1: SOURCE_TYPE 环境变量（最高优先级）
    if [[ -n "${SOURCE_TYPE:-}" ]]; then
        case "${SOURCE_TYPE}" in
            LEDE|lede)
                echo "lede"
                return 0
                ;;
            ImmortalWrt|immortalwrt)
                echo "immortalwrt"
                return 0
                ;;
        esac
    fi

    # 方法2: SOURCE_REPO 环境变量
    if [[ -n "${SOURCE_REPO:-}" ]]; then
        if [[ "${SOURCE_REPO}" == *"lede"* ]]; then
            echo "lede"
            return 0
        elif [[ "${SOURCE_REPO}" == *"immortalwrt"* ]]; then
            echo "immortalwrt"
            return 0
        fi
    fi

    # 方法3: GITHUB_WORKFLOW 变量
    if [[ -n "${GITHUB_WORKFLOW:-}" ]]; then
        if [[ "${GITHUB_WORKFLOW}" == *"LEDE"* ]]; then
            echo "lede"
            return 0
        elif [[ "${GITHUB_WORKFLOW}" == *"ImmortalWrt"* ]]; then
            echo "immortalwrt"
            return 0
        fi
    fi

    echo "unknown"
    return 1
}

# Git 稀疏克隆函数
git_sparse_clone() {
    local branch="$1"
    local repo_url="$2"
    shift 2

    log_info "从 $repo_url 稀疏克隆 (分支: $branch)"

    git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repo_url"
    local repo_dir
    repo_dir=$(echo "$repo_url" | awk -F '/' '{print $NF}')

    cd "$repo_dir" && git sparse-checkout set "$@"
    mv -f "$@" ../package/
    cd .. && rm -rf "$repo_dir"

    log_success "稀疏克隆完成"
}

# 更新设置文件中的版本字符串
update_version_string() {
    local settings_file="$1"
    local version="$2"

    if [[ ! -f "$settings_file" ]]; then
        log_warn "设置文件不存在: $settings_file"
        return 1
    fi

    local orig_version
    orig_version=$(grep DISTRIB_REVISION= "$settings_file" | awk -F "'" '{print $2}' 2>/dev/null || echo "")

    if [[ -n "$orig_version" ]]; then
        sed -i "s/${orig_version}/${version}/g" "$settings_file"
        log_success "版本已更新为: $version"
        return 0
    else
        log_warn "在 $settings_file 中未找到版本字符串"
        return 1
    fi
}

# 复制 Argon 主题背景图片
copy_argon_background() {
    local workspace
    workspace=$(get_workspace)
    local bg_file="$workspace/images/background.jpg"
    local target_dir="feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img"

    if [[ -f "$bg_file" ]] && [[ -d "$target_dir" ]]; then
        cp -f "$bg_file" "$target_dir/bg1.jpg"
        log_success "Argon 主题背景已更新"
    else
        log_warn "背景图片或 Argon 主题目录不存在"
    fi
}

# 打印脚本头信息
print_header() {
    local script_name="$1"
    echo "=========================================="
    echo "脚本: $script_name"
    echo "=========================================="
    echo "当前目录: $(pwd)"
    echo "环境变量:"
    echo "  SOURCE_TYPE='${SOURCE_TYPE:-未设置}'"
    echo "  SOURCE_REPO='${SOURCE_REPO:-未设置}'"
    echo "  GITHUB_WORKFLOW='${GITHUB_WORKFLOW:-未设置}'"
    echo "=========================================="
}

# 打印脚本尾信息
print_footer() {
    local script_name="$1"
    echo "=========================================="
    echo "脚本执行完成: $script_name"
    echo "=========================================="
}

# 导出所有函数供其他脚本使用
export -f log_info log_success log_warn log_error
export -f is_github_actions get_workspace detect_source_type
export -f git_sparse_clone update_version_string copy_argon_background
export -f print_header print_footer
