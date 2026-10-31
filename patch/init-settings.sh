#!/bin/sh
# =============================================================================
# patch/init-settings.sh —— 首次启动时应用的默认设置
#
# 该脚本会被复制到固件的 /etc/uci-defaults/99-init-settings，在路由器首次
# 启动时执行，因此【不能】依赖仓库里的配置文件（路径不存在）。
# 默认值与 config/build.conf 的 THEME_DIR 保持一致，改动主题时请两处同步。
# =============================================================================

set -eu

# 默认主题为 luci-theme-argon
uci set "luci.main.mediaurlbase=${THEME_UCI_MEDIAURL:-/luci-static/argon}"
uci commit luci
