#!/bin/bash

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${GREEN}[信息]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[警告]${NC} $*"; }
log_error() { echo -e "${RED}[错误]${NC} $*"; }

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

# 检测源码类型 - 适配并行编译工作流
function detect_source_type() {
  # 方法1: 使用 SOURCE_TYPE 环境变量（新工作流设置，优先级最高）
  if [[ -n "${SOURCE_TYPE:-}" ]]; then
    case "${SOURCE_TYPE}" in
      "LEDE"|"lede")
        log_info "lede"
        return 0
        ;;
      "ImmortalWrt"|"immortalwrt")
        log_info "immortalwrt"
        return 0
        ;;
    esac
  fi

  # 方法2: 使用 SOURCE_REPO 环境变量
  if [[ -n "${SOURCE_REPO:-}" ]]; then
    if [[ "${SOURCE_REPO}" == *"lede"* ]]; then
      log_info "lede"
      return 0
    elif [[ "${SOURCE_REPO}" == *"immortalwrt"* ]]; then
      log_info "immortalwrt"
      return 0
    fi
  fi

  # 方法3: 检查 GITHUB_WORKFLOW 变量
  if [[ -n "${GITHUB_WORKFLOW:-}" ]]; then
    if [[ "${GITHUB_WORKFLOW}" == *"LEDE"* ]]; then
      log_info "lede"
      return 0
    elif [[ "${GITHUB_WORKFLOW}" == *"ImmortalWrt"* ]]; then
      log_info "immortalwrt"
      return 0
    fi
  fi

  # 无法检测
  log_error "unknown"
  return 1
}

log_info "开始修改 xray-plugin"
# 将 package/feeds/passwall_packages/xray-plugin/Makefile 中 PKG_VERSION 修改为 main 
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=main/g' package/feeds/passwall_packages/xray-plugin/Makefile
# 将 PKG_SOURCE_URL 修改为 https://codeload.github.com/teddysun/xray-plugin/tar.gz/main?
sed -i 's|PKG_SOURCE_URL:=https://codeload.github.com/teddysun/xray-plugin/tar.gz/v.*|PKG_SOURCE_URL:=https://codeload.github.com/teddysun/xray-plugin/tar.gz/main?|g' package/feeds/passwall_packages/xray-plugin/Makefile
# 将 PKG_HASH修改为 main 版本的 HASH
sed -i 's/PKG_HASH:=.*/PKG_HASH:=dbc147d64fa816fad4b02da5528db28b4894327928445a49c39458b23c89e5cb/g' package/feeds/passwall_packages/xray-plugin/Makefile


# 添加额外插件（两个源码通用）
## OAF - OpenAppFilter
log_info "添加 OpenAppFilter 插件..."
git clone --depth=1 https://github.com/destan19/OpenAppFilter.git package/OpenAppFilter

## Openlist - 域名列表管理
log_info "添加 Openlist 插件..."
git clone --depth=1 https://github.com/sbwml/luci-app-openlist2.git package/openlist

## netspeedtest - 网络速度测试
log_info "添加 netspeedtest 插件..."
git clone --depth=1 https://github.com/sirpdboy/luci-app-netspeedtest.git package/netspeedtest

# 更改Argon 主题背景
if [[ -f "$GITHUB_WORKSPACE/images/background.jpg" ]] && [[ -d "feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img" ]]; then
  log_info "更新 Argon 主题背景..."
  cp -f $GITHUB_WORKSPACE/images/background.jpg feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg
else
  log_warn "警告: 背景图片或Argon主题目录不存在，跳过背景更新"
fi

echo "=========================================="
echo "diy-full.sh 脚本开始执行"
echo "=========================================="
echo "当前工作流: ${GITHUB_WORKFLOW:-未设置}"
echo "当前目录: $(pwd)"
echo "环境变量:"
echo "  SOURCE_TYPE='${SOURCE_TYPE:-未设置}'"
echo "  SOURCE_REPO='${SOURCE_REPO:-未设置}'"
echo "  REPO_URL='${REPO_URL:-未设置}'"
echo "  DEVICE_TARGET='${DEVICE_TARGET:-未设置}'"
echo "  DEVICE_SUBTARGET='${DEVICE_SUBTARGET:-未设置}'"
echo "  BUILD_TYPE='${BUILD_TYPE:-未设置}'"
echo "=========================================="

# 检测源码类型
source_type=$(detect_source_type)
log_info "检测到的源码类型: $source_type"

# 根据源码类型执行相应操作
case "$source_type" in
  "lede")
    log_info "=== 执行 LEDE 源码特定配置 ==="
    # LEDE 源码
    # 修改版本为编译日期
    date_version=$(date +"%y.%m.%d")

    # 尝试多个可能的默认设置文件路径
    default_settings_files=(
      "package/lean/default-settings/files/zzz-default-settings"
      "package/default-settings/files/zzz-default-settings"
      "files/etc/zzz-default-settings"
    )

    settings_updated=false
    for settings_file in "${default_settings_files[@]}"; do
      if [[ -f "$settings_file" ]]; then
        log_info "找到默认设置文件: $settings_file"
        orig_version=$(grep DISTRIB_REVISION= "$settings_file" | awk -F "'" '{print $2}' 2>/dev/null || echo "")
        if [[ -n "$orig_version" ]]; then
          sed -i "s/${orig_version}/R${date_version} by billyJR/g" "$settings_file"
          log_info "成功更新版本信息为: R${date_version}"
          settings_updated=true
          break
        fi
      fi
    done

    if [[ "$settings_updated" == false ]]; then
      log_warn "警告: 未找到 LEDE 默认设置文件，跳过版本更新"
    fi

    # LEDE 特定插件
    log_info "添加 LEDE 特定插件..."
    ## 添加一些LEDE常用的插件
    # git clone --depth=1 https://github.com/jerrykuku/luci-app-ttnode.git package/luci-app-ttnode 2>/dev/null || true

    log_info "=== LEDE 配置完成 ==="
    ;;

  "immortalwrt")
    log_info "=== 执行 ImmortalWrt 源码特定配置 ==="
    # ImmortalWrt 源码
    # 执行 scripts/update-emortal.sh 脚本
    if [[ -f "$GITHUB_WORKSPACE/scripts/update-emortal.sh" ]]; then
      log_info "执行 update-emortal.sh 脚本..."
      $GITHUB_WORKSPACE/scripts/update-emortal.sh
    else
      log_info "警告: 未找到 update-emortal.sh 脚本"
    fi

    ## AdGuardHome
    log_info "正在添加 AdGuardHome..."
    git_sparse_clone main https://github.com/kenzok8/small-package luci-app-adguardhome 2>/dev/null || {
      log_info "警告: git_sparse_clone 失败，尝试直接克隆..."
      git_sparse_clone openwrt-23.05 https://github.com/coolsnowwolf/luci applications/luci-app-adguardhome 2>/dev/null || true
    }

    ## mosdns
    log_info "清理旧的 mosdns 文件..."
    find ./ -name "*mosdns*" -type f -name "Makefile" -delete 2>/dev/null || true
    log_info "添加 mosdns 插件..."
    git clone --depth=1 https://github.com/sbwml/luci-app-mosdns -b v5 package/mosdns 2>/dev/null || true

    # ImmortalWrt 特定配置
    log_info "应用 ImmortalWrt 特定配置..."
    # 可以在这里添加ImmortalWrt特定的配置

    log_info "=== ImmortalWrt 配置完成 ==="
    ;;

  *)
    log_warn "警告: 无法确定源码类型，执行通用配置"
    log_warn "提示: 请确保设置了正确的环境变量 (SOURCE_TYPE 或 SOURCE_REPO)"
    log_warn "当前环境:"
    log_warn "  SOURCE_TYPE='${SOURCE_TYPE:-}'"
    log_warn "  SOURCE_REPO='${SOURCE_REPO:-}'"
    log_warn "  GITHUB_WORKFLOW='${GITHUB_WORKFLOW:-}'"

    # 执行通用配置
    date_version=$(date +"%y.%m.%d")
    log_info "通用版本信息: R${date_version}"
    ;;
esac

log_info "=========================================="
log_info "diy-full.sh 脚本执行完成"
log_info "=========================================="