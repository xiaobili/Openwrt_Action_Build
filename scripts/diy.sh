#!/usr/bin/env bash
# =============================================================================
# scripts/diy.sh —— 固件定制主流程（唯一实现）
#
# 档位差异全部落在 config/packages/，脚本本身不含任何档位分支。
#
# 用法：
#   scripts/diy.sh --profile full [--source lede|immortalwrt] [--dry-run]
#   scripts/diy.sh --list-profiles
#
# 执行前提：当前工作目录是 OpenWrt 源码根目录（workflow 已 cd 进去）。
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export REPO_ROOT

# shellcheck source=../lib/common.sh
. "$REPO_ROOT/lib/common.sh"
# shellcheck source=../lib/config.sh
. "$REPO_ROOT/lib/config.sh"
# shellcheck source=../lib/source.sh
. "$REPO_ROOT/lib/source.sh"
# shellcheck source=../lib/packages.sh
. "$REPO_ROOT/lib/packages.sh"
# shellcheck source=../lib/theme.sh
. "$REPO_ROOT/lib/theme.sh"
# shellcheck source=../lib/version.sh
. "$REPO_ROOT/lib/version.sh"

usage() {
  cat >&2 <<'EOF'
用法: scripts/diy.sh [选项]

选项:
  --profile <名称>    固件档位，对应 config/packages/<名称>.list（当前为 full）
  --source <类型>     源码类型，默认自动检测（lede / immortalwrt）
  --dry-run           只打印将要执行的动作，不真正改动源码树
  --list-profiles     列出可用的档位
  -h, --help          显示本帮助

环境变量:
  SOURCE_TYPE / SOURCE_REPO / REPO_URL   源码类型自动检测的依据
  DRY_RUN=true                           等同于 --dry-run
EOF
}

# 可用档位 = 不含 "-" 且不是 common / 源码名的清单文件名
list_profiles() {
  local file name
  for file in "$PACKAGE_LIST_DIR"/*.list; do
    [[ -f "$file" ]] || continue
    name="$(basename "$file" .list)"
    case "$name" in
      common | lede | immortalwrt | *-*) continue ;;
    esac
    printf '%s\n' "$name"
  done
}

profile_exists() {
  [[ -f "$PACKAGE_LIST_DIR/$1.list" ]]
}

# 提示当前目录不像 OpenWrt 源码根目录（不致命，方便本地 dry-run）
warn_if_not_openwrt() {
  # OpenWrt 源码根目录一定有 rules.mk 与 include/，用它们而不是 scripts/ 判断
  # （本仓库自己也有 scripts/，会误判）
  if [[ ! -f rules.mk && ! -d include ]]; then
    log_warn "当前目录不像 OpenWrt 源码根目录: $PWD"
    log_warn "请在 OpenWrt 源码根目录执行；只想预览动作请加 --dry-run"
  fi
}

main() {
  local profile='' source_override='' dry_run=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile) profile="${2:-}"; shift 2 ;;
      --profile=*) profile="${1#*=}"; shift ;;
      --source) source_override="${2:-}"; shift 2 ;;
      --source=*) source_override="${1#*=}"; shift ;;
      --dry-run) dry_run=true; shift ;;
      --list-profiles) list_profiles; exit 0 ;;
      -h | --help) usage; exit 0 ;;
      *) log_error "未知参数: $1"; usage; exit 1 ;;
    esac
  done

  if [[ -z "$profile" ]]; then
    log_error "必须指定 --profile（可用: $(list_profiles | tr '\n' ' ')）"
    usage
    exit 1
  fi

  if ! profile_exists "$profile"; then
    log_error "档位不存在: $profile（缺少 $PACKAGE_LIST_DIR/$profile.list）"
    log_error "可用档位: $(list_profiles | tr '\n' ' ')"
    exit 1
  fi

  if is_true "$dry_run"; then
    export DRY_RUN=true
  fi

  load_config

  local source
  if [[ -n "$source_override" ]]; then
    source="$(_normalize_source_type "$source_override")" || {
      log_error "无法识别的 --source: $source_override"
      exit 1
    }
  else
    if ! source="$(detect_source_type)"; then
      log_error "源码类型检测失败，可用 --source 显式指定"
      exit 1
    fi
  fi

  log_step "diy 定制开始 (档位: $profile, 源码: $source)"
  config_summary
  is_dry_run && log_warn "dry-run 模式：不会真正修改源码树"
  warn_if_not_openwrt

  # ---------------------------------------------------------------- 插件 ----
  log_step "阶段 1/3：安装插件"
  if ! install_profile_packages "$source" "$profile"; then
    log_warn "有插件安装失败，构建继续（与历史行为一致）"
  fi

  # ---------------------------------------------------------------- 主题 ----
  log_step "阶段 2/3：界面资源"
  apply_theme_background

  # -------------------------------------------------------------- 版本号 ----
  log_step "阶段 3/3：版本号"
  stamp_version "$source"

  log_step "diy 定制完成"
}

main "$@"
