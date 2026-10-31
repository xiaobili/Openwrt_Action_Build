#!/usr/bin/env bash
# =============================================================================
# lib/config.sh —— 配置加载
#
# 职责：
#   1. 定位仓库根目录与配置目录；
#   2. 加载 config/build.conf；
#   3. 实现「环境变量 > 配置文件」的覆盖优先级；
#   4. 计算派生值（构建日期、版本串等）。
#
# 依赖：lib/common.sh
# =============================================================================

if [[ -n "${__LIB_CONFIG_SH__:-}" ]]; then
  return 0
fi
__LIB_CONFIG_SH__=1

# 仓库根目录：优先用环境变量（CI 里通常是 $GITHUB_WORKSPACE），否则由本文件位置推算
: "${REPO_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export REPO_ROOT

: "${CONFIG_DIR:=$REPO_ROOT/config}"
export CONFIG_DIR

: "${PACKAGE_LIST_DIR:=$CONFIG_DIR/packages}"
export PACKAGE_LIST_DIR

# 允许被环境变量覆盖的配置项。
# 只有列在这里的键才享受「环境变量优先」，避免误伤内部变量。
CONFIG_OVERRIDABLE_KEYS=(
  SOURCE_LEDE_URL SOURCE_LEDE_BRANCH SOURCE_IMMORTAL_URL SOURCE_IMMORTAL_BRANCH
  VERSION_PREFIX VERSION_DATE_FORMAT VERSION_AUTHOR VERSION_DISPLAY_NAME
  LEDE_SETTINGS_CANDIDATES IMMORTAL_SETTINGS_FILE
  LAN_PORTS WAN_PORT DEFAULT_LAN_IP
  THEME_DIR THEME_BG_SOURCE THEME_BG_TARGET THEME_UCI_MEDIAURL
  FIX_GOLANG FIX_RUST FIX_SS_LIBEV GOLANG_FEED_URL GOLANG_BRANCH
  MAKE_DOWNLOAD_JOBS MAKE_RETRIES
)

# load_config
#
# 幂等：多次调用只会加载一次。
# 返回值非 0 表示配置文件缺失或损坏，调用方应终止。
load_config() {
  if [[ -n "${__CONFIG_LOADED__:-}" ]]; then
    return 0
  fi

  local config_file="$CONFIG_DIR/build.conf"
  if [[ ! -f "$config_file" ]]; then
    log_error "缺少配置文件: $config_file"
    return 1
  fi

  # 先把调用者已经 export 的同名变量快照下来（%q 保证空格、特殊字符安全）
  local snapshot
  snapshot="$(mktemp)"
  local key
  for key in "${CONFIG_OVERRIDABLE_KEYS[@]}"; do
    if [[ -n "${!key-}" ]]; then
      printf '%s=%q\n' "$key" "${!key}" >>"$snapshot"
    fi
  done

  # shellcheck source=/dev/null
  . "$config_file"

  # 再把快照倒回去，实现「环境变量 > 配置文件」
  if [[ -s "$snapshot" ]]; then
    # shellcheck source=/dev/null
    . "$snapshot"
  fi
  rm -f "$snapshot"

  # ------------------------------------------------------------ 派生值 ----
  VERSION_DATE="$(date "$VERSION_DATE_FORMAT")"
  VERSION_STRING="${VERSION_PREFIX}${VERSION_DATE} by ${VERSION_AUTHOR}"
  export VERSION_DATE VERSION_STRING

  __CONFIG_LOADED__=1
  return 0
}

# config_summary —— 打印当前生效的配置，便于排查 CI 上的问题
config_summary() {
  cat >&2 <<EOF
仓库根目录 : $REPO_ROOT
配置目录   : $CONFIG_DIR
工作目录   : $PWD
环境变量   : SOURCE_TYPE=${SOURCE_TYPE:-未设置} SOURCE_REPO=${SOURCE_REPO:-未设置}
             REPO_URL=${REPO_URL:-未设置} DEVICE_TARGET=${DEVICE_TARGET:-未设置}
             DEVICE_SUBTARGET=${DEVICE_SUBTARGET:-未设置}
版本串     : $VERSION_STRING
EOF
}
