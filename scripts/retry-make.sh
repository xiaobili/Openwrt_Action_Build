#!/usr/bin/env bash
# =============================================================================
# scripts/retry-make.sh —— 带重试的 make 包装
#
# 两种模式：
#   download  执行 make download，除了退出码还会扫描日志里的下载错误
#             （OpenWrt 的下载失败经常以 exit 0 返回，只能靠日志判断）
#   nproc     执行 make -j$(nproc)
#
# 用法:
#   scripts/retry-make.sh download [最大重试] [间隔秒]
#   scripts/retry-make.sh nproc    [最大重试] [间隔秒]
#
# 默认值可用 config/build.conf 的 MAKE_RETRIES / MAKE_DOWNLOAD_JOBS 调整。
# =============================================================================

# 这里不能用 set -e：本脚本的职责就是「失败后重试」
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
export REPO_ROOT

# shellcheck source=../lib/common.sh
. "$REPO_ROOT/lib/common.sh"
# shellcheck source=../lib/config.sh
. "$REPO_ROOT/lib/config.sh"

DEFAULT_DOWNLOAD_SLEEP=5
DEFAULT_NPROC_SLEEP=10

# 下载失败的特征（只用足够具体的模式，避免误判）
DOWNLOAD_ERROR_PATTERNS=(
  'download failed'
  'wget returned [1-9]'
  'curl: \([0-9]+\).*(7|18|28|35|56)\)'
  'Hash mismatch'
  'failed to download source'
  'source archive .* not found'
  'connection timed out'
  'Operation timed out'
  'certificate verify failed'
)

usage() {
  cat >&2 <<EOF
用法: $0 [模式] [最大重试次数] [重试间隔秒]

模式:
  download   执行 make download -j${MAKE_DOWNLOAD_JOBS:-8}
  nproc      执行 make -j\$(nproc)   (默认)

示例:
  $0 download
  $0 nproc 5
  $0 download 3 10
EOF
  exit 1
}

# 扫描日志文件中的下载错误；命中返回 1
check_download_errors() {
  local log_file="$1" pattern
  for pattern in "${DOWNLOAD_ERROR_PATTERNS[@]}"; do
    if grep -qiE -- "$pattern" "$log_file"; then
      log_warn "检测到下载错误: $pattern"
      return 1
    fi
  done
  return 0
}

main() {
  load_config

  local mode="${1:-nproc}"
  local max_retries="${2:-${MAKE_RETRIES:-3}}"
  local sleep_between action_name
  local -a cmd=()

  case "$mode" in
    download)
      sleep_between="${3:-$DEFAULT_DOWNLOAD_SLEEP}"
      cmd=(make download -j"${MAKE_DOWNLOAD_JOBS:-8}")
      action_name="下载源码包"
      ;;
    nproc)
      sleep_between="${3:-$DEFAULT_NPROC_SLEEP}"
      cmd=(make -j"$(nproc)")
      action_name="编译固件"
      ;;
    *) usage ;;
  esac

  log_info "开始执行 $action_name: ${cmd[*]}"
  log_info "最大重试次数: $max_retries，重试间隔: ${sleep_between}s"

  local attempt=1 rc=0 failure log_file
  log_file="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$log_file'" EXIT

  while :; do
    log_info "第 $attempt 次尝试 $(date '+%F %T')"

    failure=0
    # 始终把 make 的输出同时打到控制台（CI 实时日志）和本地文件（供错误扫描）
    "${cmd[@]}" 2>&1 | tee "$log_file"
    rc=${PIPESTATUS[0]}

    if [[ $rc -ne 0 ]]; then
      failure=1
    elif [[ "$mode" == "download" ]]; then
      # 下载失败常见以 exit 0 返回，只能靠日志判断
      check_download_errors "$log_file" || failure=1
    fi

    if [[ $failure -eq 0 ]]; then
      log_info "$action_name 成功完成"
      return 0
    fi

    # 日志判定失败但退出码为 0 时，补一个非 0 退出码
    [[ $rc -eq 0 ]] && rc=1

    log_error "第 $attempt 次尝试失败 (退出码: $rc)"
    if [[ $attempt -ge $max_retries ]]; then
      log_error "达到最大重试次数 ($max_retries)，放弃"
      return "$rc"
    fi

    log_info "等待 ${sleep_between}s 后重试"
    sleep "$sleep_between"
    attempt=$((attempt + 1))
  done
}

main "$@"
