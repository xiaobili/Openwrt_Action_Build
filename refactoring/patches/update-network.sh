#!/bin/sh
#
# 更新网络接口配置
# 将默认网络设置替换为自定义的 LAN/WAN 配置
#

set -eu

readonly TARGET="package/base-files/files/etc/board.d/99-default_network"
readonly REPLACEMENT='ucidef_set_interfaces_lan_wan "eth1 eth2 eth3" "eth0"'

# 检查目标文件是否存在
if [ ! -f "$TARGET" ]; then
    echo "错误: 目标文件不存在: $TARGET" >&2
    exit 1
fi

# 如果已配置则跳过
if grep -q '^[[:space:]]*ucidef_set_interfaces_lan_wan' "$TARGET"; then
    echo "网络配置已应用"
    exit 0
fi

# 使用 awk 应用配置
awk -v repl="$REPLACEMENT" '
    BEGIN { done = 0 }
    {
        if (!done && $0 ~ /^[[:space:]]*ucidef_set_interface_lan[[:space:]]/) {
            if (getline nxt) {
                if (nxt ~ /^[[:space:]]*\[ -d[[:space:]]+\/sys\/class\/net\/eth1/ && nxt ~ /ucidef_set_interface_wan/) {
                    # 跳过这两行
                } else {
                    print nxt
                }
            }
            print repl
            done = 1
        } else {
            print
        }
    }
    END {
        if (!done) print repl
    }
' "$TARGET" > "$TARGET.tmp" && mv "$TARGET.tmp" "$TARGET"

echo "网络配置更新成功"
