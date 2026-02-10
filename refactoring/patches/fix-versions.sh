#!/bin/bash
#
# 修复各种软件包的版本信息
# 包括 golang、rust 和 ss-libev 版本修复
#

set -euo pipefail

# Git 稀疏克隆辅助函数
git_sparse_clone() {
    local branch="$1"
    local repo_url="$2"
    local packfolder="$3"
    local packpath="$4"
    shift 4

    git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repo_url"
    local repo_dir
    repo_dir=$(echo "$repo_url" | awk -F '/' '{print $NF}')
    local mv_dir
    mv_dir=$(echo "$@" | awk -F '/' '{print $NF}')

    cd "$repo_dir" && git sparse-checkout set "$@"
    rm -rf "../$packfolder/$packpath/$mv_dir"
    mv -f "$@" "../$packfolder/$packpath/$mv_dir"
    cd .. && rm -rf "$repo_dir"
    echo "克隆 $repo_dir 完成"
}

# 修复 golang 版本以兼容 xray-core
fix_golang_version() {
    local makefile_path="${1:-feeds/packages/lang/golang/golang/Makefile}"

    if [[ ! -d "feeds/packages/lang/golang" ]]; then
        echo "警告: 未找到 golang 目录，跳过修复"
        return 0
    fi

    rm -rf feeds/packages/lang/golang
    git clone https://github.com/kenzok8/golang -b 1.25 feeds/packages/lang/golang

    # 从 xray-core 获取 Go 版本
    local go_version_url="https://raw.githubusercontent.com/XTLS/Xray-core/main/go.mod"
    echo "正在从 $go_version_url 获取 Go 版本..."

    local go_version
    go_version=$(curl -sL "$go_version_url" | grep "^go" | awk '{print $2}')

    if [[ -z "$go_version" ]]; then
        echo "错误: 获取 Go 版本失败"
        return 1
    fi

    echo "检测到 Go 版本: $go_version"

    local major_minor
    major_minor=$(echo "$go_version" | awk -F '.' '{print $1"."$2}')
    local patch
    patch=$(echo "$go_version" | awk -F '.' '{print $3}')

    if [[ ! -f "$makefile_path" ]]; then
        echo "错误: 在 $makefile_path 未找到 Makefile"
        return 1
    fi

    echo "正在更新 $makefile_path"
    cp "$makefile_path" "${makefile_path}.bak"

    sed -i "s/GO_VERSION_MAJOR_MINOR:=.*/GO_VERSION_MAJOR_MINOR:=$major_minor/g" "$makefile_path"
    sed -i "s/GO_VERSION_PATCH:=.*/GO_VERSION_PATCH:=$patch/g" "$makefile_path"
    echo "已更新 GO_VERSION_MAJOR_MINOR 为 $major_minor，GO_VERSION_PATCH 为 $patch"

    # 更新哈希值
    local go_hash_url="https://dl.google.com/go/go${go_version}.src.tar.gz.sha256"
    echo "正在从 $go_hash_url 获取哈希值..."

    local go_hash
    go_hash=$(curl -sL "$go_hash_url")

    if [[ -n "$go_hash" ]]; then
        echo "Go 哈希值: $go_hash"

        if grep -q "PKG_HASH:=" "$makefile_path"; then
            sed -i "s/PKG_HASH:=.*/PKG_HASH:=$go_hash/g" "$makefile_path"
        elif grep -q "PKG_SHA256SUM:=" "$makefile_path"; then
            sed -i "s/PKG_SHA256SUM:=.*/PKG_SHA256SUM:=$go_hash/g" "$makefile_path"
        fi
    fi
}

# 修复 rust 版本
fix_rust_version() {
    echo "修复 rust 版本...（占位符）"
}

# 修复 ss-libev 版本
fix_ss_libev_version() {
    echo "修复 ss-libev 版本...（占位符）"
}

# 主执行流程
main() {
    # 如果启用则修复 golang
    if [[ "${FIX_GOLANG:-}" == "true" ]]; then
        if [[ -n "${SOURCE_REPO:-}" ]]; then
            fix_golang_version
        fi
    fi

    # 如果启用则修复 rust
    if [[ "${FIX_RUST:-}" == "true" ]]; then
        fix_rust_version
    fi

    # 如果启用则修复 ss-libev
    if [[ "${FIX_SS_LIBEV:-}" == "true" ]]; then
        fix_ss_libev_version
    fi
}

main "$@"
