#!/bin/bash
# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
  branch="$1" repourl="$2" packfolder="$3" packpath="$4" && shift 4
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  mvdir=$(echo $@ | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  rm -rf ../$packfolder/$packpath/$mvdir
  mv -f $@ ../$packfolder/$packpath/$mvdir
  cd .. && rm -rf $repodir
  echo "clone $repodir done"
}

function fix_golang_version() {
  # 更新golang版本，修复xray编译错误
  # 检查feeds目录是否存在
  if [ ! -d "feeds/packages/lang/golang" ]; then
    echo "Warning: feeds/packages/lang/golang directory not found"
    echo "Skipping golang version fix"
    return 0
  fi

  # 获取xray-core的go版本
  go_version_url="https://raw.githubusercontent.com/XTLS/Xray-core/main/go.mod"
  echo "Fetching Go version from: $go_version_url"
  go_version=$(curl -sL $go_version_url | grep "^go" | awk '{print $2}')

  if [ -z "$go_version" ]; then
    echo "Error: Failed to fetch Go version from $go_version_url"
    return 1
  fi

  echo "Detected Go version: $go_version"

  # 替换 feeds/packages/lang/golang/Makefile中的GO_VERSION_MAJOR_MINOR 和 GO_VERSION_PATCH
  # 例如 go = 1.25.7 -> GO_VERSION_MAJOR_MINOR = 1.25 GO_VERSION_PATCH = 7
  major_minor=$(echo $go_version | awk -F '.' '{print $1"."$2}')
  patch=$(echo $go_version | awk -F '.' '{print $3}')

  makefile_path="feeds/packages/lang/golang/Makefile"
  if [ -f "$makefile_path" ]; then
    echo "Updating $makefile_path"
    # 备份原始文件
    cp "$makefile_path" "${makefile_path}.bak"

    # 更新版本号
    sed -i "s/GO_VERSION_MAJOR_MINOR:=.*/GO_VERSION_MAJOR_MINOR:=$major_minor/g" "$makefile_path"
    sed -i "s/GO_VERSION_PATCH:=.*/GO_VERSION_PATCH:=$patch/g" "$makefile_path"
    echo "Updated GO_VERSION_MAJOR_MINOR to $major_minor and GO_VERSION_PATCH to $patch"

    # 获取 go hash
    go_hash_url="https://dl.google.com/go/go${go_version}.src.tar.gz.sha256"
    echo "Fetching hash from: $go_hash_url"
    go_hash=$(curl -sL "$go_hash_url")

    if [ -n "$go_hash" ]; then
      echo "Go hash: $go_hash"

      # 尝试更新常见的哈希值变量名
      # OpenWrt中常见的哈希值变量名有：PKG_HASH, PKG_MD5SUM, PKG_SHA256SUM等
      # 我们先检查文件中现有的哈希值变量
      if grep -q "PKG_HASH:=" "$makefile_path"; then
        sed -i "s/PKG_HASH:=.*/PKG_HASH:=$go_hash/g" "$makefile_path"
        echo "Updated PKG_HASH"
      elif grep -q "PKG_MD5SUM:=" "$makefile_path"; then
        sed -i "s/PKG_MD5SUM:=.*/PKG_MD5SUM:=$go_hash/g" "$makefile_path"
        echo "Updated PKG_MD5SUM"
      elif grep -q "PKG_SHA256SUM:=" "$makefile_path"; then
        sed -i "s/PKG_SHA256SUM:=.*/PKG_SHA256SUM:=$go_hash/g" "$makefile_path"
        echo "Updated PKG_SHA256SUM"
      else
        echo "Warning: No common hash variable found in Makefile"
        echo "Hash variables found:"
      fi
    else
      echo "Warning: Failed to fetch Go hash from $go_hash_url"
    fi
  else
    echo "Error: Makefile not found at $makefile_path"
    return 1
  fi
}

function fix_rust_version() {
  # 克隆rust，修复 rust 编译错误
  # git_sparse_clone master https://github.com/openwrt/packages feeds packages/lang lang/rust
}

function fix_ss_libev_version() {
  # 克隆mbedtls，修复 shadowsocks-libev 编译错误
  # git_sparse_clone master https://github.com/coolsnowwolf/lede package libs package/libs/mbedtls
}

if [[ -n "${FIX_GOLANG:-}" ]]; then
  if [ ${FIX_GOLANG} = true ]; then 
    fix_golang_version
  fi
fi
if [[ -n "${FIX_RUST:-}" ]]; then
  if [ ${FIX_RUST} = true ]; then 
    fix_rust_version
  fi
fi
if [[ -n "${FIX_SS_LIBEV:-}" ]]; then
  if [ ${FIX_SS_LIBEV} = true ]; then 
    fix_ss_libev_version
  fi
fi