#!/bin/bash

# 修改默认IP
# sed -i 's/192.168.1.1/10.0.0.1/g' package/base-files/files/bin/config_generate

# 更改默认 Shell 为 zsh
# sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

# TTYD 免登录
# sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

# 移除要替换的包
# rm -rf package/OpenAppFilter
# rm -rf package/openlist

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
git clone --depth=1 https://github.com/destan19/OpenAppFilter package/OpenAppFilter
## Openlist
git clone --depth=1 https://github.com/sbwml/luci-app-openlist2 package/openlist

# 如果当前action 名称包含 Official
if [[ $GITHUB_WORKFLOW == *"Official"* ]]; then
  git clone --depth=1 https://github.com/sirpdboy/luci-app-adguardhome.git package/adguardhome
  git clone --depth=1 https://github.com/sirpdboy/luci-app-netdata package/luci-app-netdata
  git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
  git clone --depth=1 https://github.com/sirpdboy/luci-app-netspeedtest package/netspeedtest
  git clone --depth=1 https://github.com/sbwml/luci-app-mosdns -b v5 package/mosdns
  # 更改 Argon 主题背景
  cp -f $GITHUB_WORKSPACE/images/background.jpg package/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg
fi

# 如果当前action 名称不包含 Official
if [[ $GITHUB_WORKFLOW != *"Official"* ]]; then
  # 更改Argon 主题背景
  cp -f $GITHUB_WORKSPACE/images/background.jpg feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg
fi

# x86 型号只显示 CPU 型号
# sed -i 's/${g}.*/${a}${b}${c}${d}${e}${f}${hydrid}/g' package/lean/autocore/files/x86/autocore

# 修改本地时间格式
# sed -i 's/os.date()/os.date("%a %Y-%m-%d %H:%M:%S")/g' package/lean/autocore/files/*/index.htm

# 修改版本为编译日期
date_version=$(date +"%y.%m.%d")
orig_version=$(cat "package/lean/default-settings/files/zzz-default-settings" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}')
sed -i "s/${orig_version}/R${date_version} by billyJR/g" package/lean/default-settings/files/zzz-default-settings

# 修复 hostapd 报错
# cp -f $GITHUB_WORKSPACE/scripts/011-fix-mbo-modules-build.patch package/network/services/hostapd/patches/011-fix-mbo-modules-build.patch

# 修复 armv8 设备 xfsprogs 报错
# sed -i 's/TARGET_CFLAGS.*/TARGET_CFLAGS += -DHAVE_MAP_SYNC -D_LARGEFILE64_SOURCE/g' feeds/packages/utils/xfsprogs/Makefile

# 调整 Docker 到 服务 菜单
# sed -i 's/"admin"/"admin", "services"/g' feeds/luci/applications/luci-app-dockerman/luasrc/controller/*.lua
# sed -i 's/"admin"/"admin", "services"/g; s/admin\//admin\/services\//g' feeds/luci/applications/luci-app-dockerman/luasrc/model/cbi/dockerman/*.lua
# sed -i 's/admin\//admin\/services\//g' feeds/luci/applications/luci-app-dockerman/luasrc/view/dockerman/*.htm
# sed -i 's|admin\\|admin\\/services\\|g' feeds/luci/applications/luci-app-dockerman/luasrc/view/dockerman/container.htm