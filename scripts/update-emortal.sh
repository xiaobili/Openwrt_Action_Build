#!/bin/bash

#=================================================
# Description: Update ImmortalWrt version info
# Author: billyJR
#=================================================

# 设置错误退出和调试选项
set -euo pipefail

# 定义版本格式 (YY.MM.DD)
date_version=$(date +"%y.%m.%d")

# 定义目标文件路径
readonly TARGET_FILE="package/emortal/default-settings/files/99-default-settings"

# 检查目标文件是否存在
if [[ ! -f "$TARGET_FILE" ]]; then
    echo "错误: 目标文件不存在 - $TARGET_FILE" >&2
    exit 1
fi

# 创建临时文件
temp_file=$(mktemp)

# 从原文件中提取除最后一行外的所有内容
head -n -1 "$TARGET_FILE" > "$temp_file"

# 追加新版本信息
cat >> "$temp_file" << EOF

# 更新版本信息
sed -i '/DISTRIB_REVISION/d' /etc/openwrt_release
echo "DISTRIB_REVISION='R${date_version} by billyJR'" >> /etc/openwrt_release

sed -i '/DISTRIB_DESCRIPTION/d' /etc/openwrt_release
echo "DISTRIB_DESCRIPTION='ImmortalWrt '" >> /etc/openwrt_release

sed -i '/OPENWRT_RELEASE/d' /usr/lib/os-release
echo 'OPENWRT_RELEASE="ImmortalWrt ${date_version}"' >> /usr/lib/os-release

EOF

# 添加原文件的最后一行
tail -n 1 "$TARGET_FILE" >> "$temp_file"

# 安全地替换原文件
mv "$temp_file" "$TARGET_FILE"

echo "成功更新版本信息为: R${date_version}"