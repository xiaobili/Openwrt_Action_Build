#!/bin/bash
set -euo pipefail

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${GREEN}[信息]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[警告]${NC} $*"; }
log_error() { echo -e "${RED}[错误]${NC} $*"; }

# 检查命令是否存在
check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log_error "未找到必需的命令: '$cmd'"
        return 1
    fi
}

# 带重试的 curl 下载
curl_with_retry() {
    local url="$1"
    local max_retries="${2:-3}"
    local retry_delay="${3:-2}"
    local attempt=1
    local response

    while ((attempt <= max_retries)); do
        if response=$(curl -fsSL --max-time 30 "$url" 2>/dev/null); then
            echo "$response"
            return 0
        fi
        log_warn "下载失败 (尝试 $attempt/$max_retries): $url"
        ((attempt++))
        sleep "$retry_delay"
    done

    return 1
}

# Git 稀疏克隆，只克隆指定目录到本地
git_sparse_clone() {
    local branch="$1"
    local repourl="$2"
    local packfolder="$3"
    local packpath="$4"
    shift 4

    local repodir mvdir
    repodir=$(basename "$repourl" .git)

    # 清理已存在的目录
    rm -rf "$repodir"

    git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repourl"

    # 获取第一个要移动的目录名
    mvdir=$(basename "$1")

    (
        cd "$repodir" || exit 1
        git sparse-checkout set "$@"
        rm -rf "../$packfolder/$packpath/$mvdir"
        mv -f "$@" "../$packfolder/$packpath/$mvdir"
    )

    rm -rf "$repodir"
    log_info "克隆完成: $repodir"
}

# 解析版本号为 major_minor 和 patch
# 输入: 1.26 或 1.26.0
# 输出: major_minor=1.26, patch=0
parse_version() {
    local version="$1"
    local major_minor patch

    # 如果只有大版本号（如 1.26），补全为 1.26.0
    if [[ "$version" != *.*.* ]]; then
        version="${version}.0"
    fi

    major_minor="${version%.*}"
    patch="${version##*.}"

    echo "${major_minor}:${patch}"
}

# 修复 golang 版本，用于修复 xray 编译错误
fix_golang_version() {
    local makefile_path="$1"

    # 检查 feeds 目录是否存在
    if [[ ! -d "feeds/packages/lang/golang" ]]; then
        log_warn "未找到 feeds/packages/lang/golang 目录，跳过 golang 版本修复"
        return 0
    fi

    check_command curl || return 1

    # 获取 xray-core 的 go 版本
    local go_version_url="https://raw.githubusercontent.com/XTLS/Xray-core/main/go.mod"
    log_info "获取 Go 版本: $go_version_url"

    local go_version
    if ! go_version=$(curl_with_retry "$go_version_url"); then
        log_error "获取 Go 版本失败"
        return 1
    fi

    go_version=$(echo "$go_version" | awk '/^go / {print $2}')

    if [[ -z "$go_version" ]]; then
        log_error "无法从 go.mod 解析 Go 版本"
        return 1
    fi

    log_info "检测到 Go 版本: $go_version"

    # 解析版本号
    local version_parts major_minor patch
    version_parts=$(parse_version "$go_version")
    major_minor="${version_parts%:*}"
    patch="${version_parts#*:}"

    if [[ ! -f "$makefile_path" ]]; then
        log_error "未找到 Makefile: $makefile_path"
        return 1
    fi

    log_info "正在更新: $makefile_path"

    # 备份原始文件（如果不存在备份）
    local backup_path="${makefile_path}.bak"
    if [[ ! -f "$backup_path" ]]; then
        cp "$makefile_path" "$backup_path"
        log_info "已创建备份: $backup_path"
    fi

    # 更新版本号
    sed -i "s/GO_VERSION_MAJOR_MINOR:=.*/GO_VERSION_MAJOR_MINOR:=$major_minor/g" "$makefile_path"
    sed -i "s/GO_VERSION_PATCH:=.*/GO_VERSION_PATCH:=$patch/g" "$makefile_path"
    log_info "已更新 GO_VERSION_MAJOR_MINOR 为 $major_minor, GO_VERSION_PATCH 为 $patch"

    # 构建完整版本号用于下载（如 1.22.0）
    local full_version="${major_minor}.${patch}"

    # 获取 go hash
    local go_hash_url="https://dl.google.com/go/go${full_version}.src.tar.gz.sha256"
    log_info "获取哈希值: $go_hash_url"

    local go_hash
    if ! go_hash=$(curl_with_retry "$go_hash_url"); then
        log_warn "获取 Go 哈希值失败，跳过哈希更新"
        return 0
    fi

    log_info "Go 哈希值: $go_hash"

    # 更新哈希值变量
    local hash_vars=("PKG_HASH" "PKG_MD5SUM" "PKG_SHA256SUM")
    local updated=0

    for var in "${hash_vars[@]}"; do
        if grep -q "^${var}:=" "$makefile_path" 2>/dev/null; then
            sed -i "s/^${var}:=.*/${var}:=$go_hash/g" "$makefile_path"
            log_info "已更新 $var"
            updated=1
            break
        fi
    done

    if ((updated == 0)); then
        log_warn "Makefile 中未找到常见的哈希变量"
    fi
}

# 修复 rust 版本
fix_rust_version() {
    log_info "修复 rust 版本..."
    # TODO: 实现 rust 版本修复逻辑
}

# 修复 ss-libev 版本
fix_ss_libev_version() {
    log_info "修复 ss-libev 版本..."
    # TODO: 实现 ss-libev 版本修复逻辑
}

# 克隆 golang 环境
clone_golang_feed() {
    local golang_feed_url="${GOLANG_FEED_URL:-https://github.com/kenzok8/golang}"
    local golang_branch="${GOLANG_BRANCH:-1.26}"
    local target_dir="feeds/packages/lang/golang"

    log_info "正在克隆 golang: $golang_feed_url (分支: $golang_branch)"

    rm -rf "$target_dir"
    git clone --depth=1 -b "$golang_branch" "$golang_feed_url" "$target_dir"

    # 查找 golang Makefile
    local golang_dir makefile_path
    # golang_dir=$(find "$target_dir" -maxdepth 2 -type d -name 'golang*' | head -n 1)
    golang_dir=feeds/packages/lang/golang/golang
    # if [[ -z "$golang_dir" ]]; then
    #     # 尝试默认路径
    #     golang_dir="$target_dir/golang"
    # fi

    makefile_path="$golang_dir/Makefile"

    if [[ ! -f "$makefile_path" ]]; then
        log_error "在 $golang_dir 中未找到 golang Makefile"
        return 1
    fi

    log_info "找到 golang 目录: $golang_dir"
    fix_golang_version "$makefile_path"
}

# 显示帮助信息
show_help() {
    cat <<EOF
用法: $0 [选项]

修复 OpenWrt 软件包版本问题。

环境变量:
  FIX_GOLANG      设置为 "true" 修复 golang 版本 (默认: false)
  FIX_RUST        设置为 "true" 修复 rust 版本 (默认: false)
  FIX_SS_LIBEV    设置为 "true" 修复 ss-libev 版本 (默认: false)
  SOURCE_REPO     源码仓库类型 (例如: "lede", "immortalwrt")
  GOLANG_FEED_URL 自定义 golang feed URL (默认: https://github.com/kenzok8/golang)
  GOLANG_BRANCH   自定义 golang 分支 (默认: 1.26)

选项:
  -h, --help      显示此帮助信息
  --golang        修复 golang 版本
  --rust          修复 rust 版本
  --ss-libev      修复 ss-libev 版本

示例:
  FIX_GOLANG=true SOURCE_REPO=lede $0
  $0 --golang
EOF
}

# 主逻辑
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -h | --help)
            show_help
            exit 0
            ;;
        --golang)
            FIX_GOLANG="true"
            shift
            ;;
        --rust)
            FIX_RUST="true"
            shift
            ;;
        --ss-libev)
            FIX_SS_LIBEV="true"
            shift
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
        esac
    done

    local has_error=0

    # 修复 golang 版本
    if [[ "${FIX_GOLANG:-}" == "true" ]]; then
        case "${SOURCE_REPO:-}" in
        *"lede"* | *"immortalwrt"*)
            if ! clone_golang_feed; then
                has_error=1
            fi
            ;;
        *)
            log_warn "无法从 SOURCE_REPO='${SOURCE_REPO:-}' 识别源码类型"
            log_warn "支持的类型: lede, immortalwrt"
            ;;
        esac
    fi

    # 修复 rust 版本
    if [[ "${FIX_RUST:-}" == "true" ]]; then
        fix_rust_version
    fi

    # 修复 ss-libev 版本
    if [[ "${FIX_SS_LIBEV:-}" == "true" ]]; then
        fix_ss_libev_version
    fi

    if ((has_error == 0)); then
        log_info "所有修复已完成"
    else
        log_error "部分修复失败"
        exit 1
    fi
}

main "$@"
