#!/bin/bash

# 当执行make -j$(nproc)失败时自动重试的脚本
# 用于解决OpenWrt编译过程中由于各种原因（如资源不足、网络波动等）导致的编译失败问题

# 默认参数
MAX_RETRIES=${1:-3}              # 最大重试次数，默认3次
SLEEP_BETWEEN=${2:-10}           # 每次重试之间的等待时间（秒），默认10秒
COMMAND="make -j\$(nproc)"       # 要执行的命令

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
    
    # 如果命令退出码不为0，则视为失败
    if [ $exit_code -ne 0 ]; then
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