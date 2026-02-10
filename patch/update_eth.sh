#!/bin/sh
set -eu

# update_eth.sh - 替换网络初始化配置为 ucidef_set_interfaces_lan_wan

readonly TARGET="package/base-files/files/etc/board.d/99-default_network"
readonly REPL='ucidef_set_interfaces_lan_wan "eth1 eth2 eth3" "eth0"'

if [ ! -f "$TARGET" ]; then
  echo "目标文件不存在: $TARGET" >&2
  exit 1
fi

# 如果已存在则跳过
grep -q '^[[:space:]]*ucidef_set_interfaces_lan_wan' "$TARGET" && exit 0

awk -v repl="$REPL" '
  BEGIN { done = 0 }
  {
    if (!done && $0 ~ /^[[:space:]]*ucidef_set_interface_lan[[:space:]]/) {
      # 跳过当前行，检查下一行
      if (getline nxt) {
        if (!(nxt ~ /^[[:space:]]*\[ -d[[:space:]]+\/sys\/class\/net\/eth1/ && nxt ~ /ucidef_set_interface_wan/)) {
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
