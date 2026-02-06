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

# 更新golang版本，修复xray编译错误
git_sparse_clone master https://github.com/openwrt/packages feeds packages/lang lang/golang
# 克隆rust，修复 rust 编译错误
# git_sparse_clone master https://github.com/openwrt/packages feeds packages/lang lang/rust
# 克隆mbedtls，修复 shadowsocks-libev 编译错误
# git_sparse_clone master https://github.com/coolsnowwolf/lede package libs package/libs/mbedtls