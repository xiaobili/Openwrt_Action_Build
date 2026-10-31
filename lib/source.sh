#!/usr/bin/env bash
# =============================================================================
# lib/source.sh —— 源码类型检测
#
# 早期脚本用 log_info 输出检测结果，ANSI 颜色码混进了返回值，导致 case 永远
# 匹配不上（版本号修补因此形同空跑）。这里统一为一处实现，并保证
# 「stdout 只有返回值，日志走 stderr」。
#
# 检测顺序（先命中者优先）：
#   1. SOURCE_TYPE      显式声明，workflow 会设置
#   2. SOURCE_REPO      仓库名，如 lede / immortalwrt
#   3. REPO_URL         仓库地址
#   4. GITHUB_WORKFLOW  workflow 名称
# =============================================================================

if [[ -n "${__LIB_SOURCE_SH__:-}" ]]; then
  return 0
fi
__LIB_SOURCE_SH__=1

# 把任意来源字符串归一化为内部标识：lede / immortalwrt
_normalize_source_type() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    '') return 1 ;;
    *immortal*) printf 'immortalwrt' ;;
    *lede* | *lean*) printf 'lede' ;;
    *) return 1 ;;
  esac
}

# detect_source_type —— 输出 lede / immortalwrt；无法识别时返回 1
detect_source_type() {
  local candidate result
  for candidate in "${SOURCE_TYPE:-}" "${SOURCE_REPO:-}" "${REPO_URL:-}" "${GITHUB_WORKFLOW:-}"; do
    [[ -n "$candidate" ]] || continue
    if result="$(_normalize_source_type "$candidate")"; then
      log_debug "源码类型由 '$candidate' 判定为: $result"
      printf '%s\n' "$result"
      return 0
    fi
  done

  log_warn "无法识别源码类型；请设置 SOURCE_TYPE（lede / immortalwrt）或 SOURCE_REPO"
  log_warn "当前值: SOURCE_TYPE='${SOURCE_TYPE:-}' SOURCE_REPO='${SOURCE_REPO:-}' GITHUB_WORKFLOW='${GITHUB_WORKFLOW:-}'"
  return 1
}
