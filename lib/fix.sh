#!/usr/bin/env bash
# =============================================================================
# lib/fix.sh —— 编译期版本修复
#
# 上游 feed 里的 golang / rust / ss-libev 版本经常与待编译的插件不匹配
# （典型症状：xray 编译失败、rust 组件报错）。这里把它们收在一处。
#
# 两类调用入口：
#   * patch/fix_version_error.sh —— 按 --golang/--rust/--ss-libev 开关执行（旧路径）
#   * scripts/diy.sh            —— feeds install 之后无条件调用 pin_xray_go_version
#                                  （多版本 golang 下唯一有效的钉版本方式，见其注释）
#
# 依赖：lib/common.sh, lib/config.sh
# =============================================================================

if [[ -n "${__LIB_FIX_SH__:-}" ]]; then
  return 0
fi
__LIB_FIX_SH__=1

# 解析 "1.26" / "1.26.0" 为 "major_minor:patch"
_parse_go_version() {
  local version="$1"
  [[ "$version" == *.*.* ]] || version="${version}.0"
  printf '%s:%s\n' "${version%.*}" "${version##*.}"
}

# fix_golang_version <Makefile 路径>
fix_golang_version() {
  local makefile_path="$1"

  if [[ ! -d "feeds/packages/lang/golang" ]]; then
    log_warn "未找到 feeds/packages/lang/golang，跳过 golang 版本修复"
    return 0
  fi

  need_cmd curl || return 1

  # 以 Xray-core 的 go.mod 作为「应该用哪个 Go」的权威来源
  local go_version_url="https://raw.githubusercontent.com/XTLS/Xray-core/main/go.mod"
  log_info "获取 Go 版本: $go_version_url"

  local go_mod go_version
  if ! go_mod="$(curl_retry "$go_version_url")"; then
    log_error "获取 Go 版本失败"
    return 1
  fi
  go_version="$(printf '%s\n' "$go_mod" | awk '/^go / {print $2; exit}')"

  if [[ -z "$go_version" ]]; then
    log_error "无法从 go.mod 解析 Go 版本"
    return 1
  fi
  log_info "检测到 Go 版本: $go_version"

  local parts major_minor patch
  parts="$(_parse_go_version "$go_version")"
  major_minor="${parts%:*}"
  patch="${parts#*:}"

  if [[ ! -f "$makefile_path" ]]; then
    log_error "未找到 Makefile: $makefile_path"
    return 1
  fi

  local backup_path="${makefile_path}.bak"
  if [[ ! -f "$backup_path" ]]; then
    cp "$makefile_path" "$backup_path"
    log_info "已备份: $backup_path"
  fi

  sed -i "s/GO_VERSION_MAJOR_MINOR:=.*/GO_VERSION_MAJOR_MINOR:=$major_minor/g" "$makefile_path"
  sed -i "s/GO_VERSION_PATCH:=.*/GO_VERSION_PATCH:=$patch/g" "$makefile_path"
  log_info "已更新 Go 版本: $major_minor.$patch"

  # 同步下载包哈希，否则 make 会因 hash 不匹配失败
  local full_version="${major_minor}.${patch}"
  local go_hash_url="https://dl.google.com/go/go${full_version}.src.tar.gz.sha256"
  local go_hash
  if ! go_hash="$(curl_retry "$go_hash_url")"; then
    log_warn "获取 Go 哈希值失败，跳过哈希更新"
    return 0
  fi
  log_info "Go 哈希值: $go_hash"

  local var updated=0
  for var in PKG_HASH PKG_MD5SUM PKG_SHA256SUM; do
    if grep -q "^${var}:=" "$makefile_path" 2>/dev/null; then
      sed -i "s/^${var}:=.*/${var}:=$go_hash/g" "$makefile_path"
      log_info "已更新 $var"
      updated=1
      break
    fi
  done

  [[ $updated -eq 1 ]] || log_warn "Makefile 中未找到常见的哈希变量"
}

# clone_golang_feed —— 换上较新的 golang feed 并修正版本
clone_golang_feed() {
  local target_dir="feeds/packages/lang/golang"
  local makefile_path="$target_dir/golang/Makefile"

  log_info "克隆 golang feed: $GOLANG_FEED_URL (分支 $GOLANG_BRANCH)"
  rm -rf "$target_dir"
  if ! git_clone_shallow "$GOLANG_FEED_URL" "$target_dir" "$GOLANG_BRANCH"; then
    log_error "克隆 golang feed 失败"
    return 1
  fi

  if [[ ! -f "$makefile_path" ]]; then
    log_error "未找到 golang Makefile: $makefile_path"
    return 1
  fi

  fix_golang_version "$makefile_path"
}

# fix_rust_version <源码类型>
fix_rust_version() {
  local source="${1:-}"
  log_info "重建 rust feed (源码类型: ${source:-未指定})"
  rm -rf feeds/packages/lang/rust
  git_sparse_clone master https://github.com/openwrt/packages feeds/packages/lang/rust lang/rust
}

# fix_ss_libev_version <源码类型>
fix_ss_libev_version() {
  local source="${1:-}"
  local repo="https://github.com/immortalwrt/immortalWrt"

  if [[ "$source" == "lede" ]]; then
    repo="https://github.com/coolsnowwolf/lede"
  fi

  log_info "重建 mbedtls (源码: $repo)"
  git_sparse_clone master "$repo" package/libs/mbedtls package/libs/mbedtls
}

# go_xray_required_version —— 从 xray Makefile 的 PKG_VERSION 反查上游 go.mod 里的 go 指令
#
# 只在 DIY 阶段（feeds 已 install）调用：那时 feeds/passwall_packages/xray-core/Makefile
# 才存在。网络失败返回 1，由调用方降级处理。
go_xray_required_version() {
  local mk="feeds/passwall_packages/xray-core/Makefile"
  [[ -f "$mk" ]] || return 1

  local ver
  ver="$(sed -n 's/^PKG_VERSION:=//p' "$mk" | head -n1)"
  [[ -n "$ver" ]] || return 1

  local mod
  mod="$(curl_retry "https://raw.githubusercontent.com/XTLS/Xray-core/v${ver}/go.mod")" || return 1
  printf '%s\n' "$mod" | awk '/^go / {print $2; exit}'
}

# pin_xray_go_version —— 给 xray-core 钉上它真正需要的 Go 版本
#
# 背景：ImmortalWrt 25.12 的 golang 是多版本结构（golang1.26 / golang1.27 并存，
# golang/ 只是 dummy 别名包，指向 GO_DEFAULT_VERSION := 1.26）。xray-core 用
# PKG_BUILD_DEPENDS:=golang/host 时会被解析成 1.26，而 go.mod 要求 1.27、
# GOTOOLCHAIN=local 又不许自动升级，于是报
#   go: ../../go.mod requires go >= 1.27 (running go 1.26.10; GOTOOLCHAIN=local)
# 这里把它整行替换成 golangX.Y/host（不能用追加：filter/patsubst 会得到 " 1.27"
# 这种脏值，PATH 会被拼坏）。
#
# 幂等、失败不中断构建；LEDE 侧因没有 golangX.Y 目录会自动跳过。
pin_xray_go_version() {
  local mk="feeds/passwall_packages/xray-core/Makefile"

  if [[ ! -f "$mk" ]]; then
    log_info "未选中 xray-core，跳过 Go 版本钉定"
    return 0
  fi

  if ! grep -q 'golang/host' "$mk"; then
    log_info "xray-core 已钉定 Go 版本，跳过: $(grep -o 'golang[0-9.]*/host' "$mk" | head -n1)"
    return 0
  fi

  local need
  if ! need="$(go_xray_required_version)"; then
    log_warn "取不到上游 go.mod，跳过 Go 版本钉定"
    return 0
  fi
  if [[ ! "$need" =~ ^1\.[0-9]+$ ]]; then
    log_warn "无法解析 go 指令: $need"
    return 0
  fi

  if [[ ! -d "feeds/packages/lang/golang/golang${need}" ]]; then
    log_warn "feed 中没有 golang${need}，保持默认 Go 版本"
    return 0
  fi

  log_info "xray-core 需要 Go ${need}，切换 PKG_BUILD_DEPENDS := golang${need}/host"
  if is_dry_run; then
    log_info "[dry-run] 未改动 $mk"
    return 0
  fi

  sed -i -E "s|^(PKG_BUILD_DEPENDS[[:space:]]*:=.*[[:space:]])golang/host|\1golang${need}/host|; \
s|^(PKG_BUILD_DEPENDS[[:space:]]*:=)golang/host|\1golang${need}/host|" "$mk"
  # 调用方是 set -e，grep 无匹配会返回 1 从而中断整个 DIY，这里兜底
  grep -n '^PKG_BUILD_DEPENDS' "$mk" || true
}

# run_fixes —— 按 config/build.conf 与环境变量里的开关依次执行
#
# 返回 1 表示有修复失败
run_fixes() {
  local source="${1:-}"
  local failed=0

  if is_true "${FIX_GOLANG:-false}"; then
    case "$source" in
      lede | immortalwrt) clone_golang_feed || failed=1 ;;
      *) log_warn "无法识别源码类型，跳过 golang 修复" ;;
    esac
  fi

  if is_true "${FIX_RUST:-false}"; then
    fix_rust_version "$source" || failed=1
  fi

  if is_true "${FIX_SS_LIBEV:-false}"; then
    fix_ss_libev_version "$source" || failed=1
  fi

  if [[ $failed -ne 0 ]]; then
    log_error "部分修复失败"
    return 1
  fi

  log_info "版本修复流程结束"
  return 0
}
