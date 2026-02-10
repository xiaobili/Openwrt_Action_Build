#!/bin/bash
#
# 更新 ImmortalWrt 版本信息
# 将版本设置为编译日期格式: R{YY.MM.DD}
#

set -euo pipefail

readonly TARGET_FILE="package/emortal/default-settings/files/99-default-settings"
readonly BACKUP_SUFFIX=".backup"

# 检查目标文件是否存在
check_file() {
    if [[ ! -f "$TARGET_FILE" ]]; then
        echo "错误: 目标文件不存在 - $TARGET_FILE" >&2
        exit 1
    fi
}

# 创建原始文件备份
backup_file() {
    if [[ ! -f "${TARGET_FILE}${BACKUP_SUFFIX}" ]]; then
        cp "$TARGET_FILE" "${TARGET_FILE}${BACKUP_SUFFIX}"
        echo "已创建备份: ${TARGET_FILE}${BACKUP_SUFFIX}"
    fi
}

# 生成新版本内容
generate_version_content() {
    local date_version
    date_version=$(date +"%y.%m.%d")

    cat << EOF

# 更新版本信息
sed -i '/DISTRIB_REVISION/d' /etc/openwrt_release
echo "DISTRIB_REVISION='R${date_version} by billyJR'" >> /etc/openwrt_release

sed -i '/DISTRIB_DESCRIPTION/d' /etc/openwrt_release
echo "DISTRIB_DESCRIPTION='ImmortalWrt '" >> /etc/openwrt_release

sed -i '/OPENWRT_RELEASE/d' /usr/lib/os-release
echo 'OPENWRT_RELEASE="ImmortalWrt ${date_version}"' >> /usr/lib/os-release

EOF
}

# 更新目标文件
update_file() {
    local temp_file
    temp_file=$(mktemp)

    # 复制除最后一行外的所有内容到临时文件
    head -n -1 "$TARGET_FILE" > "$temp_file"

    # 添加版本内容
    generate_version_content >> "$temp_file"

    # 添加原始文件的最后一行
    tail -n 1 "$TARGET_FILE" >> "$temp_file"

    # 替换原始文件
    mv "$temp_file" "$TARGET_FILE"

    local date_version
    date_version=$(date +"%y.%m.%d")
    echo "版本已成功更新为: R${date_version}"
}

# 主执行流程
main() {
    echo "正在更新 ImmortalWrt 版本信息..."

    check_file
    backup_file
    update_file

    echo "版本更新完成。"
}

main "$@"
