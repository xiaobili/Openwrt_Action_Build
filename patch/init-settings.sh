#!/bin/bash
set -euo pipefail

# 设置默认主题为 luci-theme-argon
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci
