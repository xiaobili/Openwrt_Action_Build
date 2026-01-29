#!/bin/bash

# 当执行make download失败时自动重试的脚本
# 用于解决OpenWrt编译过程中网络不稳定导致的下载失败问题

# 默认参数
MAX_RETRIES=${1:-3}           # 最大重试次数，默认3次
SLEEP_BETWEEN=${2:-5}         # 每次重试之间的等待时间（秒），默认5秒
COMMAND="make download -j8"   # 要执行的命令

echo "开始执行命令: $COMMAND"
echo "最大重试次数: $MAX_RETRIES"
echo "重试间隔: $SLEEP_BETWEEN 秒"

attempt=0

while true; do
    attempt=$((attempt + 1))
    echo
    echo "第 $attempt 次尝试... $(date)"

    # 执行命令并将输出同时保存到变量和显示到终端
    output=$(eval "$COMMAND" 2>&1)
    exit_code=$?
    
    # 显示输出
    echo "$output"
    
    # 检查输出中是否包含常见的下载错误信息
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
        echo "✅ 命令执行成功!"
        exit 0
    fi
done