#!/usr/bin/env bash
# =============================================================================
# scripts/update-emortal.sh —— 注入 ImmortalWrt 版本号
#
# 原理：在 99-default-settings 的结尾（exit 之前）追加一段脚本，让路由器
# 首次启动时重写 /etc/openwrt_release 与 /usr/lib/os-release 里的版本字段。
#
# 版本串、发行版名称均来自 config/build.conf，也可用同名环境变量覆盖。
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
export REPO_ROOT

# shellcheck source=../lib/common.sh
. "$REPO_ROOT/lib/common.sh"
# shellcheck source=../lib/config.sh
. "$REPO_ROOT/lib/config.sh"

main() {
  load_config

  local target="${IMMORTAL_SETTINGS_FILE:-package/emortal/default-settings/files/99-default-settings}"

  if [[ ! -f "$target" ]]; then
    log_error "目标文件不存在: $target"
    return 1
  fi

  # 幂等：已经注入过就直接退出，避免本地重复执行时叠加多段
  if grep -q '更新版本信息' "$target"; then
    log_warn "$target 已包含版本注入段落，跳过"
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" EXIT

  # 保留除最后一行外的全部内容，稍后再把最后一行接回去
  head -n -1 "$target" >"$tmp"

  cat >>"$tmp" <<EOF

# 更新版本信息
sed -i '/DISTRIB_REVISION/d' /etc/openwrt_release
echo "DISTRIB_REVISION='${VERSION_STRING}'" >> /etc/openwrt_release

sed -i '/DISTRIB_DESCRIPTION/d' /etc/openwrt_release
echo "DISTRIB_DESCRIPTION='${VERSION_DISPLAY_NAME} '" >> /etc/openwrt_release

sed -i '/OPENWRT_RELEASE/d' /usr/lib/os-release
echo 'OPENWRT_RELEASE="${VERSION_DISPLAY_NAME} ${VERSION_DATE}"' >> /usr/lib/os-release

EOF

  tail -n 1 "$target" >>"$tmp"

  mv "$tmp" "$target"
  trap - EXIT

  log_info "已注入版本信息: $VERSION_STRING"
}

main "$@"
