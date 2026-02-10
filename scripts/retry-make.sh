#!/bin/bash
set -o pipefail

# OpenWrt编译过程中的重试脚本
# 支持两种模式：
#   - download: 用于处理 make download 失败的情况
#   - nproc: 用于处理 make -j$(nproc) 编译失败的情况

readonly DEFAULT_MAX_RETRIES=3
readonly DEFAULT_DOWNLOAD_SLEEP=5
readonly DEFAULT_NPROC_SLEEP=10

# 下载模式错误检测模式
readonly DOWNLOAD_ERROR_PATTERNS=(
  "download failed"
  "wget returned 8"
  "curl returned 7"
  "Hash mismatch"
  "download.*error"
  "failed to download source"
  "source archive.*not found"
  "connection timed out"
  "timeout"
  "certificate verify failed"
  "failed to build"
  "ERROR:"
)

# 显示用法
usage() {
  cat << EOF
用法: $0 [mode] [max_retries] [sleep_between]

参数说明:
  mode           运行模式: 'download' 或 'nproc' (默认: nproc)
  max_retries    最大重试次数 (默认: $DEFAULT_MAX_RETRIES)
  sleep_between  重试间隔时间(秒) (download默认: ${DEFAULT_DOWNLOAD_SLEEP}秒, nproc默认: ${DEFAULT_NPROC_SLEEP}秒)

示例:
  $0 download              # 使用默认设置执行 make download
  $0 nproc 5               # 执行 make -j\$(nproc)，最多重试5次
  $0 download 3 10         # 执行 make download，最多重试3次，每次间隔10秒
EOF
  exit 1
}

# 检测下载错误
check_download_errors() {
  local output="$1"
  local pattern

  for pattern in "${DOWNLOAD_ERROR_PATTERNS[@]}"; do
    if echo "$output" | grep -qi "$pattern"; then
      echo "检测到下载错误: $pattern"
      return 1
    fi
  done
  return 0
}

# 主函数
main() {
  local mode="${1:-nproc}"
  local max_retries="${2:-$DEFAULT_MAX_RETRIES}"
  local sleep_between
  local command
  local action_name

  # 根据模式设置参数
  case "$mode" in
    download)
      sleep_between="${3:-$DEFAULT_DOWNLOAD_SLEEP}"
      command="make download -j8"
      action_name="下载源码包"
      ;;
    nproc)
      sleep_between="${3:-$DEFAULT_NPROC_SLEEP}"
      command="make -j\$(nproc)"
      action_name="编译固件"
      ;;
    *)
      usage
      ;;
  esac

  echo "开始执行 $action_name: $command"
  echo "运行模式: $mode"
  echo "最大重试次数: $max_retries"
  echo "重试间隔: $sleep_between 秒"

  local attempt=0
  local output
  local exit_code

  while true; do
    attempt=$((attempt + 1))
    echo
    echo "第 $attempt 次尝试... $(date)"

    output=$(eval "$command" 2>&1 | tee /dev/stderr)
    exit_code=${PIPESTATUS[0]}

    local failure_detected=0

    if [[ "$mode" == "download" ]]; then
      echo "检查下载错误..."
      if [[ $exit_code -ne 0 ]] || ! check_download_errors "$output"; then
        failure_detected=1
      fi
    else
      [[ $exit_code -ne 0 ]] && failure_detected=1
    fi

    if [[ $failure_detected -eq 0 ]]; then
      echo
      echo "✅ $action_name 成功完成!"
      exit 0
    fi

    echo
    echo "❌ 第 $attempt 次尝试失败，退出码: $exit_code"

    if [[ $attempt -ge $max_retries ]]; then
      echo
      echo "达到最大重试次数 ($max_retries)，放弃执行。"
      exit $exit_code
    fi

    echo "等待 $sleep_between 秒后重试..."
    sleep "$sleep_between"
  done
}

main "$@"
