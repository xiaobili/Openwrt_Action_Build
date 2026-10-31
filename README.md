# <img src="https://cdn.jsdelivr.net/npm/simple-icons@16/icons/rocket.svg" alt="" width="16" height="16"> OpenWrt 自动化构建项目

<div align="center">

[![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/xiaobili/Openwrt_Action_Build/X86_64-Parallel-Immortal.yml?style=for-the-badge&logo=openwrt&label=workflow)](https://github.com/xiaobili/OpenWrt_Action_Build/actions)
[![License](https://img.shields.io/github/license/mashape/apistatus.svg?style=for-the-badge&logo=github)](https://github.com/xiaobili/OpenWrt_Action_Build/blob/master/LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/xiaobili/OpenWrt_Action_Build?display_name=release&style=for-the-badge&logo=github)](https://github.com/xiaobili/OpenWrt_Action_Build/releases/latest)

**一键编译 OpenWrt 固件** | **自动化构建流程** | **支持多版本源码**

</div>

---

## 项目特性

- **持续集成** - GitHub Actions 全自动构建
- **多源码支持** - LEDE 与 ImmortalWrt 两条源码线
- **单一固件版本** - 只构建 Full 完整版
- **配置驱动** - 插件清单、网口、主题、版本号全部在 `config/` 里改，不动脚本
- **无重复逻辑** - 构建流程收敛到一份可复用工作流 + 一套 shell 库
- **定时构建** - 支持 cron 与手动触发

---

## 构建目标

| 工作流 | 说明 | 文件 |
| --- | --- | --- |
| **X86_64 Parallel LEDE** | LEDE 源码，仅 Full | [X86_64-Parallel-LEDE.yml](.github/workflows/X86_64-Parallel-LEDE.yml) |
| **X86_64 Parallel ImmortalWrt** | ImmortalWrt 源码，仅 Full，默认接在 LEDE 之后执行 | [X86_64-Parallel-Immortal.yml](.github/workflows/X86_64-Parallel-Immortal.yml) |
| **X86_64 Combined FULL** | 双源码 FULL 版，每日定时，合并成一个 Release | [X86_64-Parallel-Combined-FULL.yml](.github/workflows/X86_64-Parallel-Combined-FULL.yml) |
| **清理旧记录** | 定期清理过期构建与 Release | [Delete-Old-Workflows.yml](.github/workflows/Delete-Old-Workflows.yml) |
| **静态检查** | shell 语法与 shellcheck | [Lint.yml](.github/workflows/Lint.yml) |

三个构建工作流都只是 `.github/workflows/build.yml`（可复用工作流）的调用壳，
差异仅在「跑哪几个目标」和「用哪份发布说明模板」。

---

## 项目结构

```
config/          构建配置（唯一改动入口）
  build.conf       源码、分支、版本号格式、作者、网口、主题、修复开关
  feeds.list       额外 feed 源
  packages/        插件清单（common / 源码 / 档位 / 组合 四层叠加）
lib/             可复用的 shell 库（日志、配置、源码检测、插件、主题、版本、修复）
scripts/         主流程与工具脚本
patch/           作用于 OpenWrt 源码树的小补丁
.github/         工作流与 Release 说明模板
docs/            架构说明
```

---

## 配置方式

| 想改什么 | 改哪里 |
| --- | --- |
| 加插件 | `config/packages/*.list`（通用 / 源码专用 / 档位专用 / 组合专用） |
| 加 feed 源 | `config/feeds.list` |
| 换源码分支 | `config/build.conf` 的 `SOURCE_*_BRANCH` + workflow `targets.repo_branch` |
| 改版本号样式 / 作者 | `config/build.conf` 的 `VERSION_*` |
| 改默认网口 | `config/build.conf` 的 `LAN_PORTS` / `WAN_PORT` |
| 换主题背景图 | 替换 `images/background.jpg` |
| 加档位（如 micro） | 新建 `config/packages/micro.list` + workflow 加一条 target |

插件清单语法（四类指令，支持 ` || ` 回退链）：

```
clone  https://github.com/sbwml/luci-app-openlist2.git package/openlist
sparse main https://github.com/kenzok8/small-package package/luci-app-adguardhome luci-app-adguardhome
purge  *mosdns*
run    sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=main/g' package/feeds/xxx/Makefile
```

优先级：**环境变量 > `config/build.conf` > 脚本默认值**，临时覆盖直接前缀赋值即可：

```bash
FIX_RUST=true ./diy-full.sh --dry-run
```

---

## 本地使用

在 OpenWrt 源码根目录执行（脚本会自己定位仓库）：

```bash
# 预览将要做什么，不改动任何文件
/path/to/repo/scripts/diy.sh --profile full --source immortalwrt --dry-run

# 真正执行
/path/to/repo/scripts/diy.sh --profile full --source lede

# 兼容入口（等价）
/path/to/repo/diy-full.sh

# 其它工具
/path/to/repo/scripts/diy.sh --list-profiles     # 列出可用档位
/path/to/repo/scripts/lint.sh                    # 本地自检
/path/to/repo/scripts/retry-make.sh nproc 3 10   # 带重试的编译
```

`--source` 省略时按 `SOURCE_TYPE` → `SOURCE_REPO` → `REPO_URL` → `GITHUB_WORKFLOW` 自动判断。

---

## 包含的插件和功能

**科学上网**：PassWall（`passwall_packages` + `passwall_luci` feed）
**网盘挂载**：Openlist
**界面优化**：Argon 主题（自定义背景）、LuCI 优化、版本号显示为编译日期
**系统优化**：默认 IP、默认设置、网络调优、首启自动应用设置

> 具体清单见 `config/packages/`：`common.list`（通用插件，指令格式说明也在这里）、
> `lede.list` / `immortalwrt.list`（源码专用）、`full.list`（档位专用，当前为空）。
> 追加插件只需往对应清单里写一行 `clone`，不用改脚本。

---

## 构建流程

1. **环境准备** - 合并磁盘、释放空间、安装依赖
2. **克隆源码** - 写入 `SOURCE_TYPE` / `DEVICE_TARGET` 等编译变量
3. **注入配置** - 网口改写 → 额外 feed → `feeds update` → 版本修复 → `feeds install`
4. **固件定制** - `scripts/diy.sh`：插件 → 主题 → 版本号
5. **编译** - `retry-make.sh`（下载与编译均带重试和日志错误识别）
6. **发布** - 统一命名、上传 artifact、渲染说明、发布 Release

---

## 环境要求

| 组件 | 要求 | 备注 |
| --- | --- | --- |
| 操作系统 | Ubuntu 22.04 | GitHub Actions 环境 |
| CPU | 至少 4 核 | 推荐 8 核以上 |
| 内存 | 8GB 以上 | 编译过程需要大量内存 |
| 磁盘空间 | 20GB 以上 | 编译过程占用大量空间 |

---

## 注意事项

- 编译过程需要大量磁盘与计算资源
- 定时任务会持续产出 Release，建议保留「清理旧工作流」以节省空间
- 插件安装失败只告警不中断：如果发现插件缺失，请回看构建日志中的 `[警告]` 行
- 请遵守当地法律法规使用网络相关功能

---

## 文档

- [架构说明](docs/ARCHITECTURE.md) - 执行时序、配置优先级、插件 DSL 规格、扩展指南、与旧版行为差异
- [贡献](#贡献) - 欢迎 Issue 与 Pull Request

---

## 许可证

本项目遵循 [MIT License](LICENSE)，仅供学习交流使用。
