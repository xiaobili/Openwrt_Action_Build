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
# git_sparse_clone master https://github.com/openwrt/packages feeds packages/lang lang/golang
  # 获取xray-core的go版本
  go_version_url="https://raw.githubusercontent.com/XTLS/Xray-core/main/go.mod"
  go_version=$(curl -sL $go_version_url | grep "^go" | awk '{print $2}')
  echo $go_version
  # 替换 feeds/packages/lang/golang/Makefile中的GO_VERSION_MAJOR_MINOR 和 GO_VERSION_PATCH
  # 例如 go = 1.25.7 -> GO_VERSION_MAJOR_MINOR = 1.25 GO_VERSION_PATCH = 7
  sed -i "s/GO_VERSION_MAJOR_MINOR:=.*/GO_VERSION_MAJOR_MINOR:=$(echo $go_version | awk -F '.' '{print $1"."$2}')/g" feeds/packages/lang/golang/Makefile
  sed -i "s/GO_VERSION_PATCH:=.*/GO_VERSION_PATCH:=$(echo $go_version | awk -F '.' '{print $3}')/g" feeds/packages/lang/golang/Makefile
  # 获取 go hash
  go_hash_url=""
}

function fix_rust_version() {
  # 克隆rust，修复 rust 编译错误
  # git_sparse_clone master https://github.com/openwrt/packages feeds packages/lang lang/rust
}

function fix_ss_libev_version() {
  # 克隆mbedtls，修复 shadowsocks-libev 编译错误
  # git_sparse_clone master https://github.com/coolsnowwolf/lede package libs package/libs/mbedtls
}

if [[ -n "${FIX_VERSION:-}" ]]; then
  if [ ${FIX_VERSION} = true ]; then 
    fix_golang_version
    fix_rust_version
    fix_ss_libev_version
  fi
fi