#!/usr/bin/env bash
# =============================================================================
# lib/common.sh —— 日志、断言与通用工具
#
# 约定：
#   1. 所有 log_* 一律输出到 stderr，stdout 只用于「返回值」，
#      这样 $(detect_source_type) 之类的捕获不会被日志污染。
#   2. 本文件可被重复 source，内部有防重入保护。
#   3. 本文件不产生任何副作用，只定义函数与颜色常量。
# =============================================================================

if [[ -n "${__LIB_COMMON_SH__:-}" ]]; then
  return 0
fi
__LIB_COMMON_SH__=1

# ------------------------------------------------------------------ 颜色 ----
# NO_COLOR=1 可关闭颜色（https://no-color.org）
if [[ -n "${NO_COLOR:-}" ]]; then
  C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_CYAN=''; C_RESET=''
else
  C_RED=$'\033[0;31m'; C_GREEN=$'\033[0;32m'; C_YELLOW=$'\033[1;33m'
  C_BLUE=$'\033[0;34m'; C_CYAN=$'\033[0;36m'; C_RESET=$'\033[0m'
fi

# ------------------------------------------------------------------ 日志 ----
log_info() { printf '%s[信息]%s %s\n' "$C_GREEN" "$C_RESET" "$*" >&2; }
log_warn() { printf '%s[警告]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
log_error() { printf '%s[错误]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }

log_debug() {
  if [[ -n "${DEBUG:-}" ]]; then
    printf '%s[调试]%s %s\n' "$C_BLUE" "$C_RESET" "$*" >&2
  fi
}

# 分节标题，用于把一长串日志切成可读的阶段
log_step() {
  printf '%s%s%s\n' "$C_CYAN" "----------------------------------------------------------------" "$C_RESET" >&2
  printf '%s>> %s%s\n' "$C_CYAN" "$*" "$C_RESET" >&2
  printf '%s%s%s\n' "$C_CYAN" "----------------------------------------------------------------" "$C_RESET" >&2
}

# ---------------------------------------------------------------- 断言 ----
# die <消息> [退出码]
die() {
  log_error "$1"
  exit "${2:-1}"
}

# 校验外部命令是否存在，缺一个就整体失败
need_cmd() {
  local cmd missing=0
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      log_error "缺少必需命令: $cmd"
      missing=1
    fi
  done
  [[ $missing -eq 0 ]]
}

# 布尔判断：true/1/yes/on 视为真（大小写不敏感）
is_true() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    true | 1 | yes | on) return 0 ;;
    *) return 1 ;;
  esac
}

# dry-run 开关：设置 DRY_RUN=true 时只打印、不执行破坏性操作
is_dry_run() { is_true "${DRY_RUN:-false}"; }

# 去掉字符串首尾空白
trim() {
  local s="${1:-}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# ------------------------------------------------------------ git 工具 ----
# git_clone_shallow <url> <目标目录> [分支]
git_clone_shallow() {
  local url="$1" dest="$2" branch="${3:-}"
  if is_dry_run; then
    log_info "[dry-run] git clone --depth=1 ${branch:+-b $branch }$url $dest"
    return 0
  fi
  rm -rf "$dest"
  if [[ -n "$branch" ]]; then
    git clone --depth=1 -b "$branch" --single-branch "$url" "$dest"
  else
    git clone --depth=1 --single-branch "$url" "$dest"
  fi
}

# git_sparse_clone <分支> <url> <目标目录> <仓库内路径...>
#
# 只检出仓库内指定路径，把它们（重命名）移动到 <目标目录>。
# 这是历史上三份签名各异的 git_sparse_clone 的统一实现：
#   - diy-*.sh 版本：branch url <paths>            -> package/<path>
#   - patch/fix_version_error.sh 版本：branch url packfolder packpath <paths>
# 现在统一成「显式目标目录」，调用方自己拼出完整路径，语义更直白。
git_sparse_clone() {
  local branch="$1" url="$2" dest="$3"
  shift 3
  local -a paths=("$@")

  if [[ ${#paths[@]} -eq 0 ]]; then
    log_error "git_sparse_clone 至少需要一个仓库内路径: $url"
    return 1
  fi

  if is_dry_run; then
    log_info "[dry-run] sparse clone $url (${paths[*]}) -> $dest"
    return 0
  fi

  local tmp
  tmp="$(mktemp -d)"
  local ok=1

  if git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse \
    "$url" "$tmp/src" &&
    (cd "$tmp/src" && git sparse-checkout set "${paths[@]}"); then

    mkdir -p "$(dirname "$dest")"
    rm -rf "$dest"

    if [[ ${#paths[@]} -eq 1 ]]; then
      mv -f "$tmp/src/${paths[0]}" "$dest" || ok=0
    else
      # 多个路径时，目标目录作为容器
      mkdir -p "$dest"
      local p
      for p in "${paths[@]}"; do
        mv -f "$tmp/src/$p" "$dest/" || ok=0
      done
    fi
  else
    ok=0
  fi

  rm -rf "$tmp"
  [[ $ok -eq 1 ]]
}

# ----------------------------------------------------------- curl 工具 ----
# curl_retry <url> [重试次数] [间隔秒]
# 成功时把内容打到 stdout，失败返回非 0
curl_retry() {
  local url="$1" retries="${2:-3}" delay="${3:-2}"
  local attempt=1 out

  while [[ $attempt -le $retries ]]; do
    if out="$(curl -fsSL --max-time 30 "$url" 2>/dev/null)"; then
      printf '%s\n' "$out"
      return 0
    fi
    log_warn "下载失败 (${attempt}/${retries}): $url"
    attempt=$((attempt + 1))
    [[ $attempt -le $retries ]] && sleep "$delay"
  done

  return 1
}
