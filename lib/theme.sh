#!/usr/bin/env bash
# =============================================================================
# lib/theme.sh —— 界面资源定制
# =============================================================================

if [[ -n "${__LIB_THEME_SH__:-}" ]]; then
  return 0
fi
__LIB_THEME_SH__=1

# apply_theme_background —— 替换 Argon 主题背景图
#
# 源文件取自仓库的 images/background.jpg，目标路径由 config/build.conf 的
# THEME_BG_TARGET 决定。任一前提不满足时只告警、不中断构建。
apply_theme_background() {
  local src="$REPO_ROOT/$THEME_BG_SOURCE"
  local dest="$THEME_BG_TARGET"
  local dest_dir
  dest_dir="$(dirname "$dest")"

  if [[ ! -f "$src" ]]; then
    log_warn "主题背景源文件不存在，跳过: $THEME_BG_SOURCE"
    return 0
  fi

  if [[ ! -d "$dest_dir" ]]; then
    log_warn "主题目录不存在（feeds 未就绪？），跳过: $dest_dir"
    return 0
  fi

  if is_dry_run; then
    log_info "[dry-run] cp -f $src $dest"
    return 0
  fi

  cp -f "$src" "$dest"
  log_info "已更新 Argon 主题背景: $dest"
}
