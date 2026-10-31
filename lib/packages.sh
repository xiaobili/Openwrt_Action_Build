#!/usr/bin/env bash
# =============================================================================
# lib/packages.sh —— 插件清单（DSL）解析与执行
#
# 清单文件位于 config/packages/*.list，每行一条指令：
#   clone  <仓库地址> <目标目录> [分支]
#   sparse <分支> <仓库地址> <目标目录> <仓库内路径...>
#   purge  <文件名通配>
#   run    <任意 shell 命令>
#
# 另外支持：
#   * " || " 连接多条指令 —— 前者失败才执行后者（用于仓库回退）
#   * # 注释、空行
#   * DRY_RUN=true 时只打印不执行
#
# 依赖：lib/common.sh
# =============================================================================

if [[ -n "${__LIB_PACKAGES_SH__:-}" ]]; then
  return 0
fi
__LIB_PACKAGES_SH__=1

# ------------------------------------------------------------ 单条指令 ----
# pkg_clone <url> <目标目录> [分支]
pkg_clone() {
  local url="${1:?clone 需要仓库地址}" dest="${2:?clone 需要目标目录}" branch="${3:-}"
  log_info "克隆: $url -> $dest${branch:+ (分支 $branch)}"
  git_clone_shallow "$url" "$dest" "$branch"
}

# pkg_sparse <分支> <url> <目标目录> <仓库内路径...>
pkg_sparse() {
  local branch="${1:?sparse 需要分支}" url="${2:?sparse 需要仓库地址}" dest="${3:?sparse 需要目标目录}"
  shift 3
  log_info "稀疏克隆: $url -> $dest (检出: $*)"
  git_sparse_clone "$branch" "$url" "$dest" "$@"
}

# pkg_purge <文件名通配> —— 删除源码树中匹配到的所有 Makefile
pkg_purge() {
  local pattern="${1:?purge 需要文件名通配}"

  if is_dry_run; then
    log_info "[dry-run] 删除源码树中匹配 '$pattern' 的 Makefile"
    return 0
  fi

  # 分两步做，避免依赖进程替换（部分精简环境没有 /dev/fd）
  local count
  count="$(find . -name "$pattern" -type f -name 'Makefile' 2>/dev/null | wc -l)"
  find . -name "$pattern" -type f -name 'Makefile' -delete 2>/dev/null || true

  log_info "清理 '$pattern' 相关 Makefile: ${count// /} 个"
}

# pkg_run <shell 命令...> —— 在 OpenWrt 源码根目录执行任意命令
pkg_run() {
  local cmd="$*"
  if is_dry_run; then
    log_info "[dry-run] $cmd"
    return 0
  fi
  log_info "执行: $cmd"
  bash -c "$cmd"
}

# -------------------------------------------------------- 指令解析执行 ----
# 执行单条指令（不含 || 备选）
run_package_command() {
  local line="$1"
  local -a words=()
  read -r -a words <<<"$line"

  local verb="${words[0]:-}"
  local argc=$(( ${#words[@]} - 1 ))

  case "$verb" in
    clone)
      [[ $argc -ge 2 ]] || { log_warn "clone 参数不足: $line"; return 1; }
      pkg_clone "${words[@]:1}"
      ;;
    sparse)
      [[ $argc -ge 4 ]] || { log_warn "sparse 参数不足: $line"; return 1; }
      pkg_sparse "${words[@]:1}"
      ;;
    purge)
      [[ $argc -ge 1 ]] || { log_warn "purge 参数不足: $line"; return 1; }
      pkg_purge "${words[@]:1}"
      ;;
    run)
      [[ $argc -ge 1 ]] || { log_warn "run 参数不足: $line"; return 1; }
      # run 之后的原始文本即命令，保留引号与空格
      pkg_run "${line#run }"
      ;;
    *)
      log_warn "未知指令 '$verb': $line"
      return 1
      ;;
  esac
}

# 执行一条清单指令，支持 " || " 分隔的备选方案（前者失败才执行后者）
run_package_spec() {
  local rest="$1" alt
  local failed=0

  while [[ -n "$rest" ]]; do
    if [[ "$rest" == *'||'* ]]; then
      alt="${rest%%||*}"
      rest="${rest#*||}"
    else
      alt="$rest"
      rest=""
    fi

    alt="$(trim "$alt")"
    if [[ -z "$alt" ]]; then
      continue
    fi

    if run_package_command "$alt"; then
      return 0
    fi

    failed=1
    if [[ -n "$rest" ]]; then
      log_warn "方案失败，改用备选"
    fi
  done

  return $failed
}

# ---------------------------------------------------------- 清单遍历 ----
# install_package_list <清单文件>
# 返回 1 表示有指令全部失败（调用方决定是否终止构建）
install_package_list() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  local rel="${file#"$REPO_ROOT"/}"
  log_step "插件清单: $rel"

  local line total=0 failed=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"          # 去注释
    line="$(trim "$line")"
    [[ -n "$line" ]] || continue

    total=$((total + 1))
    if ! run_package_spec "$line"; then
      failed=$((failed + 1))
      log_warn "指令执行失败（已跳过，不影响后续）: $line"
    fi
  done <"$file"

  if [[ $total -eq 0 ]]; then
    log_info "清单为空，跳过"
    return 0
  fi

  log_info "清单完成: 成功 $((total - failed)) / 共 $total"
  [[ $failed -eq 0 ]]
}

# install_profile_packages <源码类型> <档位>
#
# 四层叠加，后加载的清单在同一目标目录上会覆盖先前的克隆（rm -rf 后重新 clone）：
#   common.list -> <源码>.list -> <档位>.list -> <源码>-<档位>.list
install_profile_packages() {
  local source="$1" profile="$2"
  local name failed=0

  for name in common "$source" "$profile" "$source-$profile"; do
    install_package_list "$PACKAGE_LIST_DIR/$name.list" || failed=1
  done

  return $failed
}
