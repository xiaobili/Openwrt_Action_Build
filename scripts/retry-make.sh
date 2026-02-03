#!/bin/bash

# OpenWrt编译过程中的重试脚本
# 支持两种模式：
#   - download: 用于处理 make download 失败的情况
#   - nproc: 用于处理 make -j$(nproc) 编译失败的情况

set -o pipefail

# 显示用法
usage() {
    echo "用法: $0 [mode] [max_retries] [sleep_between]"
    echo ""
    echo "参数说明:"
    echo "  mode           运行模式: 'download' 或 'nproc' (默认: nproc)"
    echo "  max_retries    最大重试次数 (默认: 3)"
    echo "  sleep_between  重试间隔时间(秒) (download默认: 5秒, nproc默认: 10秒)"
    echo ""
    echo "示例:"
    echo "  $0 download     # 使用默认设置执行 make download"
    echo "  $0 nproc 5      # 执行 make -j\$(nproc)，最多重试5次"
    echo "  $0 download 3 10 # 执行 make download，最多重试3次，每次间隔10秒"
    exit 1
}

# 设置默认值
MODE=${1:-"nproc"}
MAX_RETRIES=${2:-3}

# 根据模式设置默认等待时间
if [[ "$MODE" == "download" ]]; then
    SLEEP_BETWEEN=${3:-5}
    COMMAND="make download -j8"
    ACTION_NAME="下载源码包"
else
    SLEEP_BETWEEN=${3:-10}
    COMMAND="make -j\$(nproc)"
    ACTION_NAME="编译固件"
fi

echo "开始执行 $ACTION_NAME: $COMMAND"
echo "运行模式: $MODE"
echo "最大重试次数: $MAX_RETRIES"
echo "重试间隔: $SLEEP_BETWEEN 秒"

attempt=0

while true; do
    attempt=$((attempt + 1))
    echo
    echo "第 $attempt 次尝试... $(date)"

    # 执行命令并将输出同时保存到变量和显示到终端
    output=$(eval "$COMMAND" 2>&1 | tee /dev/stderr)
    exit_code=${PIPESTATUS[0]}

    # 根据模式决定如何处理错误
    if [[ "$MODE" == "download" ]]; then
        # 检查下载模式下的错误
        download_errors=0
        error_patterns=(
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
        
        echo "检查下载错误..."
        for pattern in "${error_patterns[@]}"; do
            if echo "$output" | grep -qi "$pattern"; then
                echo "检测到下载错误: $pattern"
                download_errors=1
            fi
        done
        
        # 如果命令本身失败或存在下载错误，则视为失败
        if [ $exit_code -ne 0 ] || [ $download_errors -eq 1 ]; then
            failure_detected=1
        else
            failure_detected=0
        fi
    else
        # nproc模式下只需要检查退出码
        if [ $exit_code -ne 0 ]; then
            failure_detected=1
        else
            failure_detected=0
        fi
    fi

    if [ $failure_detected -eq 1 ]; then
        echo
        echo "❌ 第 $attempt 次尝试失败，退出码: $exit_code"
        
        # 检查是否达到最大重试次数
        if [ $attempt -ge $MAX_RETRIES ]; then
            echo
            echo "达到最大重试次数 ($MAX_RETRIES)，放弃执行。"
            exit $exit_code
        fi
        
        echo "等待 $SLEEP_BETWEEN 秒后重试..."
        sleep $SLEEP_BETWEEN
    else
        echo
        echo "✅ $ACTION_NAME 成功完成!"
        exit 0
    fi
done