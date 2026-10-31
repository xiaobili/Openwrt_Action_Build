#!/usr/bin/env bash
# =============================================================================
# diy-full.sh —— 完整版定制入口（兼容壳）
#
# 真正的逻辑在 scripts/diy.sh，档位差异在 config/packages/*.list。
# 保留本文件是为了让旧 workflow、旧文档和本地习惯继续可用。
# =============================================================================

set -euo pipefail

echo "提示: diy-full.sh 已改为 scripts/diy.sh 的兼容入口，建议直接用 scripts/diy.sh --profile full" >&2
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/diy.sh" --profile full "$@"
