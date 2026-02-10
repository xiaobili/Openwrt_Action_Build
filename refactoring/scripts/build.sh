#!/bin/bash
#
# OpenWrt 编译脚本（带重试逻辑）
# 支持下载和编译两种模式
#

set -o pipefail

# 默认值
readonly DEFAULT_MAX_RETRIES=3
readonly DEFAULT_DOWNLOAD_SLEEP=5
readonly DEFAULT_COMPILE_SLEEP=10

# 下载失败的错误模式
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

# 显示使用说明
usage() {
    cat << EOF
用法: $0 <命令> [最大重试次数] [等待秒数]

命令:
  download    执行 'make download'（带重试逻辑）
  compile     执行 'make -j\$(nproc)'（带重试逻辑）

选项:
  最大重试次数    最大重试次数（默认: $DEFAULT_MAX_RETRIES）
  等待秒数        重试间隔秒数（下载默认: ${DEFAULT_DOWNLOAD_SLEEP}秒, 编译默认: ${DEFAULT_COMPILE_SLEEP}秒）

示例:
  $0 download              # 使用默认设置下载
  $0 compile 5             # 编译，最多重试5次
  $0 download 3 10         # 下载，最多重试3次，每次间隔10秒
EOF
    exit 1
}

# 日志函数
log_info() {
    echo "[信息] $*"
}

log_error() {
    echo "[错误] $*" >&2
}

log_success() {
    echo "[成功] $*"
}

# 检查下载错误
check_download_errors() {
    local output="$1"
    local has_error=0

    for pattern in "${DOWNLOAD_ERROR_PATTERNS[@]}"; do
        if echo "$output" | grep -qi "$pattern"; then
            log_error "检测到下载错误: $pattern"
            has_error=1
        fi
    done

    return $has_error
}

# 带重试逻辑的命令执行
execute_with_retry() {
    local command="$1"
    local action_name="$2"
    local max_retries="$3"
    local sleep_seconds="$4"
    local check_errors_fn="${5:-}"

    local attempt=0

    log_info "开始执行 $action_name"
    log_info "命令: $command"
    log_info "最大重试次数: $max_retries, 等待时间: ${sleep_seconds}秒"

    while true; do
        attempt=$((attempt + 1))
        echo
        log_info "第 $attempt 次尝试... ($(date '+%Y-%m-%d %H:%M:%S'))"

        local output_file
        output_file=$(mktemp)
        local exit_code

        # 执行命令并捕获输出到临时文件，同时输出到终端
        eval "$command" 2>&1 | tee "$output_file"
        exit_code=${PIPESTATUS[0]}

        local output
        output=$(cat "$output_file")
        rm -f "$output_file"

        # 检查失败
        local failure_detected=0
        if [[ $exit_code -ne 0 ]]; then
            failure_detected=1
        elif [[ -n "$check_errors_fn" ]]; then
            if $check_errors_fn "$output"; then
                failure_detected=1
            fi
        fi

        if [[ $failure_detected -eq 0 ]]; then
            echo
            log_success "$action_name 执行成功！"
            return 0
        fi

        echo
        log_error "第 $attempt 次尝试失败（退出码: $exit_code）"

        # 检查是否达到最大重试次数
        if [[ $attempt -ge $max_retries ]]; then
            log_error "已达到最大重试次数 ($max_retries)，放弃执行。"
            return "$exit_code"
        fi

        log_info "等待 $sleep_seconds 秒后重试..."
        sleep "$sleep_seconds"
    done
}

# 主函数
main() {
    local command="${1:-}"

    # 验证命令
    case "$command" in
        download)
            local max_retries="${2:-$DEFAULT_MAX_RETRIES}"
            local sleep_seconds="${3:-$DEFAULT_DOWNLOAD_SLEEP}"
            execute_with_retry "make download -j8" "下载" "$max_retries" "$sleep_seconds" check_download_errors
            ;;
        compile)
            local max_retries="${2:-$DEFAULT_MAX_RETRIES}"
            local sleep_seconds="${3:-$DEFAULT_COMPILE_SLEEP}"
            execute_with_retry "make -j\$(nproc)" "编译" "$max_retries" "$sleep_seconds" ""
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"
