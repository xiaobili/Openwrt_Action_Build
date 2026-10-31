#!/usr/bin/env bash
# =============================================================================
# scripts/lint.sh —— 本地自检
#
# 覆盖四件事（缺工具时自动跳过对应项，不会误报失败）：
#   1. 所有 .sh 的 bash 语法
#   2. shellcheck（若已安装）
#   3. 插件清单 DSL 的指令合法性
#   4. 各 workflow 里 targets JSON 的必填字段（需 jq）
#
# 用法: scripts/lint.sh
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT" || exit 1

# shellcheck source=../lib/common.sh
. "$REPO_ROOT/lib/common.sh"

fail=0
skip() { printf '%s[跳过]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }

# ------------------------------------------------------------ 1) 语法 ----
log_step "1/4 bash 语法检查"
shopt -s globstar
checked=0
for file in **/*.sh; do
  checked=$((checked + 1))
  if bash -n "$file"; then
    printf '  ok   %s\n' "$file" >&2
  else
    printf '%s  FAIL %s%s\n' "$C_RED" "$file" "$C_RESET" >&2
    fail=1
  fi
done
if [[ $checked -eq 0 ]]; then
  log_error "没有找到任何 .sh 文件，检查工作目录"
  fail=1
fi

# -------------------------------------------------------- 2) shellcheck ----
log_step "2/4 shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
  # shellcheck disable=SC2046  # 仓库内没有带空格的路径
  if ! shellcheck --severity=error $(git ls-files '*.sh'); then
    fail=1
  fi
else
  skip "未安装 shellcheck（apt install shellcheck）"
fi

# ------------------------------------------------------------- 3) DSL ----
log_step "3/4 插件清单 DSL"
for list in config/packages/*.list; do
  [ -e "$list" ] || continue
  line_no=0
  list_err=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    line="${line%%#*}"
    line="$(trim "$line")"
    [[ -n "$line" ]] || continue

    # || 备选逐段校验
    rest="$line"
    while [[ -n "$rest" ]]; do
      if [[ "$rest" == *'||'* ]]; then
        seg="${rest%%||*}"
        rest="${rest#*||}"
      else
        seg="$rest"
        rest=""
      fi
      seg="$(trim "$seg")"
      [[ -n "$seg" ]] || continue

      read -r -a words <<<"$seg"
      verb="${words[0]}"
      argc=$(( ${#words[@]} - 1 ))
      case "$verb:$argc" in
        clone:2 | clone:3 | sparse:4* | purge:1 | run:*) ;;
        *)
          printf '%s  %s:%s 非法指令: %s%s\n' "$C_RED" "$list" "$line_no" "$seg" "$C_RESET" >&2
          list_err=1
          fail=1
          ;;
      esac
    done
  done <"$list"

  if [[ $list_err -eq 0 ]]; then
    printf '  ok   %s\n' "$list" >&2
  else
    printf '%s  FAIL %s%s\n' "$C_RED" "$list" "$C_RESET" >&2
  fi
done

# --------------------------------------------------- 4) workflow targets ----
log_step "4/4 workflow targets JSON"
if command -v jq >/dev/null 2>&1; then
  for wf in .github/workflows/*.yml; do
    grep -q 'fromJSON(inputs.targets)' "$wf" && continue # 复用工作流本身不声明 targets
    # 提取 targets: | 块（到文件末尾即为其内容）
    json="$(awk '/^ *targets: \|/{flag=1; next} flag' "$wf")"
    [[ -n "$json" ]] || continue
    if ! printf '%s' "$json" | jq -e '.' >/dev/null 2>&1; then
      printf '%s  FAIL %s 的 targets 不是合法 JSON%s\n' "$C_RED" "$wf" "$C_RESET" >&2
      fail=1
      continue
    fi
    missing="$(printf '%s' "$json" | jq -r '
      ["source","slug","repo_url","repo_branch","build_type","firmware_prefix",
       "config","diy_script","fix_golang","fix_rust","fix_ss_libev"] as $k
      | .[] | . as $t | $k[] | select($t[.] == null) | "\($t.source)/\($t.build_type) 缺 \(.)"')"
    if [[ -n "$missing" ]]; then
      printf '%s  FAIL %s:%s%s\n' "$C_RED" "$wf" "$missing" "$C_RESET" >&2
      fail=1
    else
      printf '  ok   %s\n' "$wf" >&2
    fi
  done
else
  skip "未安装 jq"
fi

echo
if [[ $fail -eq 0 ]]; then
  log_info "自检通过"
else
  log_error "自检失败"
fi
exit $fail
