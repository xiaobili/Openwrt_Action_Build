#!/bin/bash
#
# 首次启动初始化脚本
# 应用于 /etc/uci-defaults/99-init-settings
#

# 设置默认主题为 Argon
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

exit 0
