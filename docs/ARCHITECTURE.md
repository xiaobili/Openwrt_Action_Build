# 架构说明

本文解释「构建是怎么跑起来的」和「改动应该改哪里」。日常使用看 [README](../README.md) 即可。

---

## 1. 目录与职责

```
config/
  build.conf               全局配置：源码、分支、版本号格式、作者、网口、主题、修复开关
  feeds.list               额外 feed 源（原 feeds.conf.default 的追加行）
  packages/
    common.list            所有源码 / 所有档位通用插件
    <source>.list          某源码的所有档位：lede.list / immortalwrt.list
    <profile>.list         某档位的所有源码：full.list（当前唯一档位）
    <source>-<profile>.list 源码×档位组合专用（当前无实例，属扩展点）

lib/
  common.sh                日志、断言、is_true、git_clone_shallow、git_sparse_clone、curl_retry
  config.sh                配置加载、环境变量覆盖、派生值（版本串）、config_summary
  source.sh                源码类型检测（lede / immortalwrt）
  packages.sh              插件清单 DSL 的解析与执行
  theme.sh                 Argon 主题背景替换
  version.sh               版本号注入（LEDE / ImmortalWrt 两条路径）
  fix.sh                   golang / rust / mbedtls 版本修复

scripts/
  diy.sh                   固件定制主流程（唯一实现）
  retry-make.sh            带重试与日志错误识别的 make 包装
  update-emortal.sh        ImmortalWrt 版本号注入
  render-template.sh       ${VAR} 模板渲染（Release 说明）
  lint.sh                  本地自检

diy-full.sh                兼容入口，3 行，等价于 scripts/diy.sh --profile full
diy-feeds.sh               把 config/feeds.list 注入 feeds.conf.default

patch/
  update_eth.sh            网口初始化改写（读 build.conf 的 LAN_PORTS / WAN_PORT）
  fix_version_error.sh     版本修复入口（逻辑在 lib/fix.sh）
  init-settings.sh         首次启动应用的默认设置（随固件运行）

.github/
  workflows/build.yml            可复用工作流（workflow_call），承载全部构建与发布
  workflows/X86_64-Parallel-*.yml  对外入口，只声明触发条件 + 目标矩阵
  release-notes/*.md             Release 说明模板
```

一句话原则：**能配置的不要写脚本，能复用的不要复制**。

---

## 2. 执行时序

```
workflow 入口（X86_64-Parallel-*.yml）
  └─ uses: ./.github/workflows/build.yml
       ├─ job Build（matrix = inputs.targets）
       │   1. 合并磁盘 / 释放空间 / 安装依赖
       │   2. 克隆源码 → $GITHUB_ENV 写入 SOURCE_TYPE / SOURCE_REPO / DEVICE_*
       │   3. 缓存工具链（按 source-branch-target-subtarget-type 组成 mixkey）
       │   4. patch/update_eth.sh         ← 读 config/build.conf 的网口
       │   5. diy-feeds.sh                ← 读 config/feeds.list
       │   6. feeds update -a
       │   7. patch/fix_version_error.sh  ← 读 matrix 的 fix_* 开关
       │   8. feeds install -a
       │   9. diy-full.sh                  ← 转 scripts/diy.sh --profile full
       │        ├─ 阶段 1 插件：common → <source> → <profile> → <source>-<profile>
       │        ├─ 阶段 2 主题：images/background.jpg → Argon
       │        └─ 阶段 3 版本：LEDE 改 zzz-default-settings / Immortal 调 update-emortal.sh
       │  10. retry-make.sh download / retry-make.sh nproc
       │  11. 整理 bin/ → 统一改名为 <firmware_prefix>_<文件名> → 上传 artifact
       └─ job Release
           1. 下载全部 firmware-* artifact（pattern + merge-multiple）
           2. 解析各版本 profiles.json / manifest 得到内核与固件版本
           3. 浅克隆各源码取最后一次提交信息
           4. 渲染 .github/release-notes/<模板> → release-body.md
           5. softprops/action-gh-release 发布
```

`Prepare` 这一步在重构中被去掉了：原实现为了拿提交信息完整克隆了两份源码，
现在改在 Release 阶段用 `git clone --depth=1 --filter=blob:none --no-checkout` 现取，
省一个 runner 和两次全量克隆。

---

## 3. 配置优先级

```
环境变量  >  config/build.conf  >  脚本内默认值
```

实现方式（`lib/config.sh:load_config`）：先记录调用者已设置的同名变量，
`source` 配置文件后再把它们写回，所以 workflow 的 matrix、命令行前缀赋值都能覆盖配置文件。

```bash
# 覆盖配置文件里的默认值
FIX_RUST=true VERSION_AUTHOR="Alice" ./diy-full.sh --dry-run
```

可被覆盖的键列在 `CONFIG_OVERRIDABLE_KEYS` 里（`lib/config.sh`），
新增配置项时记得同步加入该数组，否则它无法被环境变量覆盖。

`config/build.conf` 必须是纯 POSIX 赋值（`KEY=VALUE`），因为 `patch/update_eth.sh`
是 `sh` 脚本、也会读它。

---

## 4. 插件清单 DSL

`config/packages/*.list` 每行一条指令，`#` 之后为注释：

| 指令 | 签名 | 说明 |
| --- | --- | --- |
| `clone` | `clone <url> <目标目录> [分支]` | `git clone --depth=1`，目标目录存在时先删除 |
| `sparse` | `sparse <分支> <url> <目标目录> <仓库内路径...>` | 只检出指定路径；多路径时目标目录作为容器 |
| `purge` | `purge <文件名通配>` | 删除源码树中匹配到的所有 `Makefile` |
| `run` | `run <任意命令>` | 在 OpenWrt 源码根目录执行 |

规则：

- **失败不致命**：任一指令失败只告警，构建继续（与历史行为一致，避免一次网络抖动毁掉整次编译）。
- **` || ` 即回退链**：`a || b` 表示 a 失败才执行 b，用于同一插件在两个仓库间回退（前一个仓库不可用时自动换成备用源）。
- **`run` 抢占整行**：`run` 之后的原始文本都会交给 `bash -c`，所以 `run` 里不要再写 `||`。
- **加载顺序决定覆盖**：四层清单依次执行，后一层用同名目标目录会覆盖前一层。

`scripts/lint.sh` 会校验动词与参数个数，改完清单先跑一遍。

---

## 5. 源码类型检测

`lib/source.sh:detect_source_type` 依次尝试：

1. `SOURCE_TYPE`（workflow 显式设置，推荐）
2. `SOURCE_REPO`（仓库名）
3. `REPO_URL`
4. `GITHUB_WORKFLOW`（workflow 名称）

命中规则：包含 `immortal` → `immortalwrt`；包含 `lede` 或 `lean` → `lede`。
**返回值只走 stdout，日志走 stderr**，避免颜色码污染 `$(...)` 捕获。

> 历史 bug：早期脚本用 `log_info "lede"` 作为返回值，`case "$source_type"`
> 拿到的是带 ANSI 转义码的字符串，永远匹配不上，于是版本号修补形同空跑。
> 该问题随本次重构一并修复。

---

## 6. 版本号注入的两条路径

| 源码 | 落点 | 机制 |
| --- | --- | --- |
| LEDE | `package/*/default-settings/files/zzz-default-settings` | 构建期直接改写 `DISTRIB_REVISION=` 整行 |
| ImmortalWrt | `package/emortal/default-settings/files/99-default-settings` | 构建期在 `exit 0` 前追加一段首启脚本，由路由器首次启动时写入 `/etc/openwrt_release` 与 `/usr/lib/os-release` |

版本串由 `VERSION_PREFIX + VERSION_DATE_FORMAT + VERSION_AUTHOR` 组成（默认 `R26.10.31 by billyJR`）。
两处查找路径分别在 `LEDE_SETTINGS_CANDIDATES`、`IMMORTAL_SETTINGS_FILE` 中配置。

注入是幂等的：`update-emortal.sh` 检测到文件里已有「更新版本信息」段落就直接退出。

---

## 7. 可复用工作流

> **当前只构建 Full 档位**。LEDE 与 ImmortalWrt 两个入口 workflow 各只有一个 target，
> 插件清单相应只剩 `config/packages/full.list`（档位层）与 `common.list` / `<source>.list`。
> `--profile` 参数保留，新增档位时只要放一份 `<档位>.list` 并在 workflow 的 `targets` 加一条即可。

`build.yml` 的 `workflow_call` 入参：

| 入参 | 必填 | 说明 |
| --- | --- | --- |
| `targets` | ✓ | 构建矩阵 JSON 数组，每个元素是一个 target |
| `release_notes` | ✓ | `.github/release-notes/` 下的模板文件名 |
| `release_suffix` | ✓ | Release 名称/tag 后缀，最终 tag = `R<构建日期><后缀>` |
| `cache_action` | | `higarfield`（默认）或 `xiaobili`，选择工具链缓存 action |

target 字段：

| 字段 | 说明 |
| --- | --- |
| `source` | 源码标识（`LEDE` / `ImmortalWrt`），用于 job 名与目录名 |
| `slug` | 环境变量键前缀（`LEDE` / `IMMORTAL`），Release 模板里用 `${COMMIT_<slug>_AUTHOR}` |
| `repo_url` / `repo_branch` | 源码仓库与分支 |
| `build_type` | 档位名（`Full` / `FULL`），用于 job 名与 artifact 名 |
| `firmware_prefix` | 固件文件名前缀，同时决定 `${KERNEL_<大写>}` 变量名 |
| `config` | buildroot `.config` 路径 |
| `diy_script` | `diy-full.sh` |
| `fix_golang` / `fix_rust` / `fix_ss_libev` | 传给 `patch/fix_version_error.sh` 的开关 |

`uses:` 不允许表达式，所以两种缓存 action 写成两个带 `if` 的步骤。

---

## 8. Release 说明渲染

`build.yml` 在 Release 阶段导出的环境变量：

| 变量 | 来源 |
| --- | --- |
| `DEFAULT_LAN_IP` | `config/build.conf` |
| `KERNEL_<PREFIX>` / `FIRMWARE_<PREFIX>` | 各版本 `profiles.json`（缺内核版本时退化为解析 manifest） |
| `COMMIT_<SLUG>_{AUTHOR,DATE,MESSAGE,HASH,BRANCH}` | `git show -s` |

`scripts/render-template.sh` 用 `envsubst` 只替换**全大写**的 `${VAR}` 占位符，
小写/混合大小写的 `${...}` 原样保留，因此模板里可以安全地写 shell 片段。

新增占位符时：先在 `build.yml` 里 `echo "VAR=..." >> $GITHUB_ENV`，再在模板里引用。

---

## 9. 常见改动

**加一个插件**

1. 选择清单：通用 → `common.list`；某源码专用 → `<source>.list`；某档位专用 → `<profile>.list`；组合专用 → `<source>-<profile>.list`
2. 写一行 `clone https://github.com/作者/仓库.git package/插件名`
3. `scripts/lint.sh` 自检

**加一个档位（例如 `micro`）**

1. 新建 `config/packages/micro.list`
2. 需要组合差异时再加 `lede-micro.list` / `immortalwrt-micro.list`
3. 在 workflow 的 `targets` 里加一条，`build_type` / `firmware_prefix` 用 `Micro`，`config` 指向对应的 `.config`
4. `scripts/diy.sh --list-profiles` 可确认档位已生效

**换源码分支**

改 `config/build.conf` 的 `SOURCE_*_BRANCH`，并同步 workflow `targets` 里的 `repo_branch`
（后者决定实际克隆，前者用于文档与本地脚本默认值）。

**加一个额外 feed**

往 `config/feeds.list` 加一行 `src-git 名称 url;分支`，其余不用管（幂等注入）。

**加一种源码类型（例如 `openwrt`）**

1. `config/build.conf` 加 `SOURCE_OPENWRT_URL` / `SOURCE_OPENWRT_BRANCH`
2. `lib/source.sh` 的 `_normalize_source_type` 加匹配规则
3. 新建 `config/packages/openwrt.list`
4. `lib/version.sh` 的 `stamp_version` 加分支
5. workflow `targets` 加条目

---

## 10. 与重构前的行为差异

| 项 | 变化 | 原因 |
| --- | --- | --- |
| 版本号注入 | 现在真正会执行 | 旧实现用 `log_info` 当返回值，ANSI 颜色码污染 `case` 判断，等于空跑 |
| `files/` 自定义目录 | 现在会被真正拷进源码树 | 旧逻辑先 `rm -rf $GITHUB_WORKSPACE/files` 再从同一路径拷贝 |
| LEDE workflow 的 `$GITHUB_ENV` | 由 `>` 改为 `>>` | 旧逻辑每个变量都覆盖整个文件，只有最后一个生效 |
| `diy-feeds.sh` | 幂等，且按清单顺序前置 | 旧实现用 `sed '1i'`/`'2i'`，重复执行会重复插入 |
| 版本号改写 | 整行替换而非全局字符串替换 | 旧实现的 `sed "s/${orig_version}/..."` 会把原值里的 `.` 当通配符 |
| `patch/fix_version_backup.sh` | 删除 | 已被 `fix_version_error.sh` 取代的死代码 |
| 固件 artifact 名 | `firmware-<source>-<build_type>` | 统一命名，Release 用 `pattern: firmware-*` 一次拉全 |
| Release 说明 | 抽成模板文件 | 三个 workflow 里各写一份 30 行 YAML 内联文本 |
| `UPLOAD_BIN_DIR` | 删除 | 从未被任何步骤读取 |
| 新增 `Lint` workflow | shellcheck + bash -n | 保证后续改脚本不再静默坏掉 |
