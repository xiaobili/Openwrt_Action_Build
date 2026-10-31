#!/usr/bin/env bash
# =============================================================================
# lib/version.sh —— 版本号注入
#
# 两套源码的版本号落点不同，各自一个函数，由 stamp_version 统一分发：
#   LEDE        : 改写 package/*/default-settings/files/zzz-default-settings
#   ImmortalWrt : 调用 scripts/update-emortal.sh 注入首启脚本
#
# 依赖：lib/common.sh, lib/config.sh
# =============================================================================

if [[ -n "${__LIB_VERSION_SH__:-}" ]]; then
  return 0
fi
__LIB_VERSION_SH__=1

# stamp_lede_version —— 把 DISTRIB_REVISION 改写为 VERSION_STRING
#
# 历史实现是先 grep 出原值再全局 sed 替换，原值里的 "." 会被当成正则通配符；
# 这里改为整行改写，结果一致但不受原值内容影响。
stamp_lede_version() {
  local -a candidates=()
  read -r -a candidates <<<"${LEDE_SETTINGS_CANDIDATES:-}"
  [[ ${#candidates[@]} -gt 0 ]] || { log_warn "未配置 LEDE_SETTINGS_CANDIDATES，跳过版本号更新"; return 0; }

  local file
  for file in "${candidates[@]}"; do
    [[ -f "$file" ]] || continue
    if ! grep -q '^DISTRIB_REVISION=' "$file"; then
      log_debug "$file 中没有 DISTRIB_REVISION，继续查找"
      continue
    fi

    log_info "更新版本号: $file -> $VERSION_STRING"
    if is_dry_run; then
      log_info "[dry-run] sed -i \"s|^\\\\(DISTRIB_REVISION=\\\\).*|\\\\1'$VERSION_STRING'|\" $file"
      return 0
    fi
    sed -i "s|^\(DISTRIB_REVISION=\).*|\1'${VERSION_STRING}'|" "$file"
    return 0
  done

  log_warn "未找到含 DISTRIB_REVISION 的 LEDE 默认设置文件，跳过版本号更新"
  log_warn "查找过的路径: ${candidates[*]}"
  return 0
}

# stamp_immortal_version —— 调用 scripts/update-emortal.sh
stamp_immortal_version() {
  local script="$REPO_ROOT/scripts/update-emortal.sh"

  if [[ ! -f "$script" ]]; then
    log_warn "未找到版本号脚本，跳过: scripts/update-emortal.sh"
    return 0
  fi

  if is_dry_run; then
    log_info "[dry-run] bash $script"
    return 0
  fi

  log_info "执行版本号注入: scripts/update-emortal.sh"
  REPO_ROOT="$REPO_ROOT" bash "$script"
}

# stamp_version <源码类型>
stamp_version() {
  case "$1" in
    lede) stamp_lede_version ;;
    immortalwrt) stamp_immortal_version ;;
    *)
      log_warn "未知源码类型 '$1'，跳过版本号更新"
      return 0
      ;;
  esac
}
