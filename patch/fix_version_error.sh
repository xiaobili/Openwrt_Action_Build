#!/bin/bash
set -euo pipefail

# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
  local branch="$1" repourl="$2" packfolder="$3" packpath="$4"
  shift 4

  git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repourl"
  local repodir mvdir
  repodir=$(basename "$repourl")
  mvdir=$(basename "$1")

  cd "$repodir" && git sparse-checkout set "$@"
  rm -rf "../$packfolder/$packpath/$mvdir"
  mv -f "$@" "../$packfolder/$packpath/$mvdir"
  cd .. && rm -rf "$repodir"
  echo "clone $repodir done"
}

function fix_golang_version() {
  # 更新golang版本，修复xray编译错误
  local makefile_path="$1"

  # 检查feeds目录是否存在
  if [[ ! -d "feeds/packages/lang/golang" ]]; then
    echo "Warning: feeds/packages/lang/golang directory not found"
    echo "Skipping golang version fix"
    return 0
  fi

  # 获取xray-core的go版本
  local go_version_url="https://raw.githubusercontent.com/XTLS/Xray-core/main/go.mod"
  echo "Fetching Go version from: $go_version_url"

  local go_version
  go_version=$(curl -sL "$go_version_url" | awk '/^go / {print $2}')

  if [[ -z "$go_version" ]]; then
    echo "Error: Failed to fetch Go version from $go_version_url"
    return 1
  fi

  # 如果 go_version 只有大版本号（如 1.26），则补全为 1.26.0
  if [[ "$go_version" != *.*.* ]]; then
    go_version="${go_version}.0"
  fi

  echo "Detected Go version: $go_version"

  # 解析版本号
  local major_minor patch
  major_minor="${go_version%.*}"
  patch="${go_version##*.}"

  if [[ ! -f "$makefile_path" ]]; then
    echo "Error: Makefile not found at $makefile_path"
    return 1
  fi

  echo "Updating $makefile_path"
  # 备份原始文件
  cp "$makefile_path" "${makefile_path}.bak"

  # 更新版本号
  sed -i "s/GO_VERSION_MAJOR_MINOR:=.*/GO_VERSION_MAJOR_MINOR:=$major_minor/g" "$makefile_path"
  sed -i "s/GO_VERSION_PATCH:=.*/GO_VERSION_PATCH:=$patch/g" "$makefile_path"
  echo "Updated GO_VERSION_MAJOR_MINOR to $major_minor and GO_VERSION_PATCH to $patch"

  # 获取 go hash
  local go_hash_url="https://dl.google.com/go/go${go_version}.src.tar.gz.sha256"
  echo "Fetching hash from: $go_hash_url"

  local go_hash
  go_hash=$(curl -sL "$go_hash_url")

  if [[ -z "$go_hash" ]]; then
    echo "Warning: Failed to fetch Go hash from $go_hash_url"
    return 0
  fi

  echo "Go hash: $go_hash"

  # 更新哈希值变量
  local hash_vars=("PKG_HASH" "PKG_MD5SUM" "PKG_SHA256SUM")
  local updated=0

  for var in "${hash_vars[@]}"; do
    if grep -q "^${var}:=" "$makefile_path"; then
      sed -i "s/^${var}:=.*/${var}:=$go_hash/g" "$makefile_path"
      echo "Updated $var"
      updated=1
      break
    fi
  done

  if [[ $updated -eq 0 ]]; then
    echo "Warning: No common hash variable found in Makefile"
  fi
}

function fix_rust_version() {
  echo "Fixing rust version..."
}

function fix_ss_libev_version() {
  echo "Fixing ss-libev version..."
}

# 主逻辑
main() {
  if [[ "${FIX_GOLANG:-}" == "true" ]]; then
    case "${SOURCE_REPO:-}" in
      *"lede"*|*"immortalwrt"*)
        # 克隆 golang 环境
        rm -rf feeds/packages/lang/golang
        git_sparse_clone "master" "https://github.com/openwrt/packages" "feeds" "packages/lang" "lang/golang"
        # 动态查找 golang 目录
        local golang_dir makefile_path
        golang_dir=$(find feeds/packages/lang/golang -maxdepth 1 -type d -name 'golang[0-9]*.[0-9]*' | head -n 1)
        if [[ -z "$golang_dir" ]]; then
          echo "Error: No golang directory found in feeds/packages/lang/golang/"
          exit 1
        fi
        makefile_path="$golang_dir/Makefile"
        echo "Found golang directory: $golang_dir"
        fix_golang_version "$makefile_path"
        ;;
      *)
        echo "Warning: Unable to determine source type"
        ;;
    esac
  fi

  if [[ "${FIX_RUST:-}" == "true" ]]; then
    fix_rust_version
  fi

  if [[ "${FIX_SS_LIBEV:-}" == "true" ]]; then
    fix_ss_libev_version
  fi
}

main "$@"
