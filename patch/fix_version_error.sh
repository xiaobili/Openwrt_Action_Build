#!/usr/bin/env bash
# =============================================================================
# patch/fix_version_error.sh —— 编译期版本修复入口
#
# 逻辑已移入 lib/fix.sh，本文件只负责解析参数/开关。
# 接口与历史版本保持一致：命令行 --golang/--rust/--ss-libev，或环境变量
# FIX_GOLANG / FIX_RUST / FIX_SS_LIBEV（workflow 的 matrix 会用它们）。
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
export REPO_ROOT

# shellcheck source=../lib/common.sh
. "$REPO_ROOT/lib/common.sh"
# shellcheck source=../lib/config.sh
. "$REPO_ROOT/lib/config.sh"
# shellcheck source=../lib/source.sh
. "$REPO_ROOT/lib/source.sh"
# shellcheck source=../lib/fix.sh
. "$REPO_ROOT/lib/fix.sh"

show_help() {
  cat >&2 <<'EOF'
用法: patch/fix_version_error.sh [选项]

修复 OpenWrt 软件包版本问题（golang / rust / ss-libev）。

选项:
  --golang        修复 golang 版本（用于 xray 编译失败）
  --rust          重建 rust feed
  --ss-libev      重建 mbedtls
  -h, --help      显示本帮助

环境变量（config/build.conf 中也有默认值）:
  FIX_GOLANG      true 时修复 golang
  FIX_RUST        true 时重建 rust
  FIX_SS_LIBEV    true 时重建 mbedtls
  GOLANG_FEED_URL / GOLANG_BRANCH   自定义 golang feed
  SOURCE_TYPE / SOURCE_REPO         源码类型（lede / immortalwrt）

示例:
  $0 --golang
  FIX_RUST=true SOURCE_TYPE=lede $0
EOF
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help) show_help; exit 0 ;;
      --golang) FIX_GOLANG=true; shift ;;
      --rust) FIX_RUST=true; shift ;;
      --ss-libev) FIX_SS_LIBEV=true; shift ;;
      *) log_error "未知选项: $1"; show_help; exit 1 ;;
    esac
  done

  load_config

  # 开关全关时直接退出，避免 workflow 空跑
  if ! is_true "${FIX_GOLANG:-false}" &&
    ! is_true "${FIX_RUST:-false}" &&
    ! is_true "${FIX_SS_LIBEV:-false}"; then
    log_info "所有修复开关均为 false，跳过版本修复"
    return 0
  fi

  local source=''
  if ! source="$(detect_source_type)"; then
    log_warn "无法识别源码类型，跳过版本修复"
    return 0
  fi
  log_info "源码类型: $source"

  run_fixes "$source"
}

main "$@"
