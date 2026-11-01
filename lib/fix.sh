#!/usr/bin/env bash
# =============================================================================
# lib/fix.sh —— 编译期版本修复
#
# 上游 feed 里的 rust / ss-libev 版本经常与待编译的插件不匹配（典型症状：
# rust 组件报错、mbedtls 版本过旧）。这里把它们收在一处。
#
# 两类调用入口：
#   * patch/fix_version_error.sh —— 按 --rust/--ss-libev 开关执行（旧路径）
#   * scripts/diy.sh            —— feeds install 之后无条件调用 pin_xray_go_version
#                                  （多版本 golang 下唯一有效的钉版本方式，见其注释）
#
# 依赖：lib/common.sh, lib/config.sh
# =============================================================================

if [[ -n "${__LIB_FIX_SH__:-}" ]]; then
  return 0
fi
__LIB_FIX_SH__=1

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
