#!/bin/bash

# 修改默认IP
# sed -i 's/192.168.1.1/10.0.0.1/g' package/base-files/files/bin/config_generate

# 更改默认 Shell 为 zsh
# sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

# TTYD 免登录
# sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config


# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
}

# 添加额外插件
## OAF
git clone --depth=1 https://github.com/destan19/OpenAppFilter.git package/OpenAppFilter
## Openlist
git clone --depth=1 https://github.com/sbwml/luci-app-openlist2.git package/openlist
## netspeedtest
git clone --depth=1 https://github.com/sirpdboy/luci-app-netspeedtest.git package/netspeedtest
# 更改Argon 主题背景
cp -f $GITHUB_WORKSPACE/images/background.jpg feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg

echo "当前工作流: $GITHUB_WORKFLOW"

# 如果当前 action 为 LEDE
if [[ $GITHUB_WORKFLOW == *"LEDE"* ]]; then
  # 修改版本为编译日期
  date_version=$(date +"%y.%m.%d")
  orig_version=$(cat "package/lean/default-settings/files/zzz-default-settings" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}')
  sed -i "s/${orig_version}/R${date_version} by billyJR/g" package/lean/default-settings/files/zzz-default-settings
fi

# 如果当前 action 为 immortalwrt
if [[ $GITHUB_WORKFLOW == *"immortalWrt"* ]]; then
  # 执行 scripts/update-default.sh 脚本
  $GITHUB_WORKSPACE/scripts/update-emortal.sh
  ## AdGuardHome
  git clone --depth=1 https://github.com/rufengsuixing/luci-app-adguardhome.git package/adguardhome
  ## mosdns
  find ./ | grep Makefile | grep mosdns | xargs rm -f
  git clone https://github.com/sbwml/luci-app-mosdns -b v5 package/mosdns
fi