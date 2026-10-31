#!/usr/bin/env bash
# =============================================================================
# scripts/render-template.sh —— 用环境变量渲染模板
#
# 只替换模板中出现的 ${VAR} 占位符，其余内容（含 $ 的其他用法）原样保留，
# 因此可以安全地渲染 Release 说明、脚本片段等。
#
# 用法:
#   VERSION=1.2 scripts/render-template.sh template.md out.md
# =============================================================================

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "用法: $0 <模板文件> <输出文件>" >&2
  exit 1
fi

template="$1"
output="$2"

if [[ ! -f "$template" ]]; then
  echo "[错误] 模板不存在: $template" >&2
  exit 1
fi

# 收集模板里用到的变量名，交给 envsubst 精确替换。
# 只认全大写占位符（${FOO_BAR}），小写/混合大小写的 ${...} 原样保留，
# 这样模板里可以安全地写 shell 片段。
keys="$(grep -o '\${[A-Z][A-Z0-9_]*}' "$template" | sort -u | tr '\n' ' ' || true)"

if [[ -z "${keys// /}" ]]; then
  cp "$template" "$output"
else
  # shellcheck disable=SC2086  # keys 是空格分隔的变量名列表，需要分词
  envsubst "$keys" <"$template" >"$output"
fi

echo "已渲染: $template -> $output" >&2
