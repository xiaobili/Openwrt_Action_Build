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

# 检测源码类型
function detect_source_type() {
  # 方法1: 使用 SOURCE_REPO 环境变量（优先级最高）
  if [[ -n "${SOURCE_REPO:-}" ]]; then
    if [[ "${SOURCE_REPO}" == *"lede"* ]]; then
      echo "lede"
      return 0
    elif [[ "${SOURCE_REPO}" == *"immortalwrt"* ]]; then
      echo "immortalwrt"
      return 0
    fi
  fi

  # # 方法2: 检查 GITHUB_WORKFLOW 变量
  # if [[ -n "${GITHUB_WORKFLOW:-}" ]]; then
  #   if [[ "${GITHUB_WORKFLOW}" == *"LEDE"* ]]; then
  #     echo "lede"
  #     return 0
  #   elif [[ "${GITHUB_WORKFLOW}" == *"ImmortalWrt"* ]]; then
  #     echo "immortalwrt"
  #     return 0
  #   fi
  # fi

  # # 方法3: 检查文件系统特征
  # if [[ -d "package/lean" ]]; then
  #   echo "lede"
  #   return 0
  # fi

  # if [[ -d "package/emortal" ]]; then
  #   echo "immortalwrt"
  #   return 0
  # fi

  # 无法检测
  echo "unknown"
  return 1
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
echo "源码仓库: ${SOURCE_REPO:-未设置}"
echo "当前目录: $(pwd)"
echo "环境变量:"
echo "  SOURCE_REPO='${SOURCE_REPO:-}'"
echo "  REPO_URL='${REPO_URL:-}'"

# 检测源码类型
source_type=$(detect_source_type)
echo "检测到的源码类型: $source_type"

# 根据源码类型执行相应操作
case "$source_type" in
  "lede")
    # LEDE 源码
    # 修改版本为编译日期
    date_version=$(date +"%y.%m.%d")
    if [[ -f "package/lean/default-settings/files/zzz-default-settings" ]]; then
      orig_version=$(cat "package/lean/default-settings/files/zzz-default-settings" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}')
      sed -i "s/${orig_version}/R${date_version} by billyJR/g" package/lean/default-settings/files/zzz-default-settings
      echo "成功更新版本信息为: R${date_version}"
    else
      echo "警告: 未找到 LEDE 默认设置文件，跳过版本更新"
    fi
    ;;
  "immortalwrt")
    # ImmortalWrt 源码
    # 执行 scripts/update-emortal.sh 脚本
    if [[ -f "$GITHUB_WORKSPACE/scripts/update-emortal.sh" ]]; then
      $GITHUB_WORKSPACE/scripts/update-emortal.sh
    else
      echo "警告: 未找到 update-emortal.sh 脚本"
    fi

    ## AdGuardHome
    echo "正在添加 AdGuardHome..."
    git_sparse_clone openwrt-23.05 https://github.com/coolsnowwolf/luci applications/luci-app-adguardhome

    ## mosdns
    find ./ | grep Makefile | grep mosdns | xargs rm -f
    git clone https://github.com/sbwml/luci-app-mosdns -b v5 package/mosdns
    ;;
  *)
    echo "错误: 无法确定源码类型，跳过特定操作"
    echo "提示: 检查是否设置了 SOURCE_REPO 环境变量"
    ;;
esac