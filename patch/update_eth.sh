#!/bin/sh
# =============================================================================
# patch/update_eth.sh —— 把网口初始化改写为「多 LAN + 单 WAN」
#
# 目标文件与网口定义都来自 config/build.conf（LAN_PORTS / WAN_PORT），
# 也可用同名环境变量临时覆盖：
#   LAN_PORTS="eth1 eth2" WAN_PORT=eth0 ./patch/update_eth.sh
#
# 该脚本以 POSIX sh 编写，因为它会被复制进固件侧流程的同名上下文使用。
# =============================================================================

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=${REPO_ROOT:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}

# 记下调用者显式传入的值，读取配置后再还原，保证「环境变量 > 配置文件」
ENV_LAN_PORTS=${LAN_PORTS-}
ENV_WAN_PORT=${WAN_PORT-}
ENV_TARGET=${TARGET-}

if [ -f "$REPO_ROOT/config/build.conf" ]; then
  # shellcheck source=../config/build.conf
  . "$REPO_ROOT/config/build.conf"
fi

if [ -n "$ENV_LAN_PORTS" ]; then LAN_PORTS=$ENV_LAN_PORTS; fi
if [ -n "$ENV_WAN_PORT" ]; then WAN_PORT=$ENV_WAN_PORT; fi
if [ -n "$ENV_TARGET" ]; then TARGET=$ENV_TARGET; fi

LAN_PORTS=${LAN_PORTS:-eth1 eth2 eth3}
WAN_PORT=${WAN_PORT:-eth0}
TARGET=${TARGET:-package/base-files/files/etc/board.d/99-default_network}

# 取第一个 LAN 口：原逻辑用它判断「已按真实网卡条件初始化 WAN」的分支
LAN_FIRST=${LAN_PORTS%% *}
REPL="ucidef_set_interfaces_lan_wan \"$LAN_PORTS\" \"$WAN_PORT\""

if [ ! -f "$TARGET" ]; then
  echo "目标文件不存在: $TARGET" >&2
  exit 1
fi

# 已经改写过则跳过（幂等）
if grep -q '^[[:space:]]*ucidef_set_interfaces_lan_wan' "$TARGET"; then
  exit 0
fi

awk -v repl="$REPL" -v lan_first="$LAN_FIRST" '
  BEGIN { done = 0 }
  {
    if (!done && $0 ~ /^[[:space:]]*ucidef_set_interface_lan[[:space:]]/) {
      # 跳过当前行，检查下一行
      if (getline nxt) {
        pattern = "^[[:space:]]*\\[ -d[[:space:]]+/sys/class/net/" lan_first
        if (!(nxt ~ pattern && nxt ~ /ucidef_set_interface_wan/)) {
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

echo "已更新网口配置: LAN=[$LAN_PORTS] WAN=[$WAN_PORT]"
