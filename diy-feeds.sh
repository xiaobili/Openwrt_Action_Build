#!/usr/bin/env bash
# =============================================================================
# diy-feeds.sh —— 注入额外 feed 源
#
# 数据源：config/feeds.list（格式与 feeds.conf.default 一致）
# 行为：把清单里的行按顺序前置到 feeds.conf.default；已存在的行跳过，
#       因此重复执行是幂等的（历史实现用 sed '1i' / '2i'，不幂等且顺序脆弱）。
#
# 用法：在 OpenWrt 源码根目录执行
#   /path/to/repo/diy-feeds.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$SCRIPT_DIR}"
export REPO_ROOT

# shellcheck source=lib/common.sh
. "$REPO_ROOT/lib/common.sh"

FEEDS_CONF="${FEEDS_CONF:-feeds.conf.default}"
FEEDS_LIST="$REPO_ROOT/config/feeds.list"

main() {
  if [[ ! -f "$FEEDS_CONF" ]]; then
    die "未找到 $FEEDS_CONF，请确认当前目录是 OpenWrt 源码根目录"
  fi

  if [[ ! -f "$FEEDS_LIST" ]]; then
    log_warn "未找到 $FEEDS_LIST，跳过 feed 注入"
    return 0
  fi

  local -a pending=()
  local line item

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(trim "$line")"
    [[ -n "$line" ]] || continue

    # 已存在于 feeds.conf.default 就跳过
    if grep -qxF -- "$line" "$FEEDS_CONF"; then
      log_debug "已存在，跳过: $line"
      continue
    fi

    # 清单内部去重
    local dup=0
    for item in ${pending[@]+"${pending[@]}"}; do
      [[ "$item" == "$line" ]] && dup=1
    done
    [[ $dup -eq 1 ]] && continue

    pending+=("$line")
  done <"$FEEDS_LIST"

  if [[ ${#pending[@]} -eq 0 ]]; then
    log_info "$FEEDS_CONF 已包含全部额外 feed，无需改动"
    return 0
  fi

  if is_dry_run; then
    log_info "[dry-run] 将向 $FEEDS_CONF 前置 ${#pending[@]} 行:"
    printf '  %s\n' "${pending[@]}" >&2
    return 0
  fi

  # 同目录建临时文件，避免跨文件系统 mv 丢权限
  local tmp
  tmp="$(mktemp ./.feeds.conf.XXXXXX)"
  {
    printf '%s\n' "${pending[@]}"
    cat "$FEEDS_CONF"
  } >"$tmp"
  mv -f "$tmp" "$FEEDS_CONF"

  log_info "已向 $FEEDS_CONF 注入 ${#pending[@]} 条额外 feed"
}

main "$@"
