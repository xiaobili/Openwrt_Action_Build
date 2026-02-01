# 🚀 OpenWrt 自动化构建项目

<div align="center">

[![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/xiaobili/Openwrt_Action_Build/X86_64-Parallel-Immortal.yml?style=for-the-badge&logo=openwrt&label=workflow)](https://github.com/xiaobili/Openwrt_Action_Build/actions)
[![License](https://img.shields.io/github/license/mashape/apistatus.svg?style=for-the-badge&logo=github)](https://github.com/xiaobili/OpenWrt_Auto_Build/blob/master/LICENSE)
![GitHub Release](https://img.shields.io/github/v/release/xiaobili/Openwrt_Action_Build?display_name=release&style=for-the-badge&logo=github)

**一键编译 OpenWrt 固件** | **自动化构建流程** | **支持多版本源码**

</div>

---

## ✨ 项目特性

- 🔄 **持续集成** - 集成 GitHub Actions 实现自动化构建流程
- 📦 **多源码支持** - 支持 LEDE 和 ImmortalWrt 源码的自动编译
- 🎯 **双重版本** - 提供完整版和迷你版两种固件构建选项
- ⏰ **定时构建** - 支持定时构建和手动触发构建
- 🧩 **丰富插件** - 包含多种常用插件和优化配置
- 🎨 **主题美化** - 预装 Argon 主题并优化界面体验
- ⚡ **并行构建** - 支持并行构建多个版本固件，提高效率

---

## 📋 构建目标

项目提供了以下几种构建工作流：

| 类型                              | 描述                            | 特点                                              | 工作流文件                                                                     |
| --------------------------------- | ------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------ |
| 🖥️ **X86_64 Parallel LEDE**        | 基于 Lean's LEDE 源码的并行构建 | 同时构建完整版和精简版固件                        | [X86_64-Parallel-LEDE.yml](.github/workflows/X86_64-Parallel-LEDE.yml)         |
| 🌐 **X86_64 Parallel ImmortalWrt** | 基于 ImmortalWrt 源码的并行构建 | 同时构建完整版和精简版固件，支持官方 OpenWrt 分支 | [X86_64-Parallel-Immortal.yml](.github/workflows/X86_64-Parallel-Immortal.yml) |
| 🧹 **清理旧工作流**                | 定期清理过期的构建记录          | 自动清理过期的 GitHub Actions 记录                | [Delete-Old-Workflows.yml](.github/workflows/Delete-Old-Workflows.yml)         |

---

## 🧩 包含的插件和功能

### 🔧 系统插件
- **OpenAppFilter** - 应用过滤
- **Openlist** - 网盘挂载工具
- **NetSpeedTest** - 网络速度测试
- **PassWall** - 科学上网解决方案

### 🌐 网络工具
- **AdGuard Home** - 广告拦截
- **MosDNS** - DNS 解析
- **网速测试工具** - 网络速度检测

### 🎨 界面优化
- **Argon 主题** - 带自定义背景图片
- **Luci 界面优化** - 提升用户体验
- **版本号显示** - 显示为编译日期格式

### ⚡ 系统优化
- 自动设置默认 IP 地址
- 优化的系统默认设置
- 网络性能调优
- 首次启动自动应用默认设置

---

## ⚙️ 配置文件

| 配置文件                       | 用途                   | 链接                                           |
| ------------------------------ | ---------------------- | ---------------------------------------------- |
| x86_64.config                  | LEDE 完整版配置        | [查看](configs/x86_64.config)                  |
| x86_64-mini.config             | LEDE 迷你版配置        | [查看](configs/x86_64-mini.config)             |
| x86_64-immortalWrt.config      | ImmortalWrt 完整版配置 | [查看](configs/x86_64-immortalWrt.config)      |
| x86_64-immortalWrt-mini.config | ImmortalWrt 迷你配置   | [查看](configs/x86_64-immortalWrt-mini.config) |

---

## 🛠️ 自定义脚本

### [diy-feeds.sh](diy-feeds.sh)
用于添加额外的 feeds 源，如 PassWall 插件源。

### [diy-full.sh](diy-full.sh) 和 [diy-mini.sh](diy-mini.sh)
用于自定义固件配置，包括：
- 添加额外插件
- 更换主题背景
- 修改版本号显示
- 修复特定问题

### [init-settings.sh](patch/init-settings.sh)
在首次启动时应用默认设置，如主题配置。

### [retry-make.sh](scripts/retry-make.sh)
增强的编译脚本，提供失败重试功能。

---

## 🏗️ 构建流程

```mermaid
graph LR
A[环境准备] --> B[代码获取]
B --> C[依赖处理]
C --> D[编译配置]
D --> E[固件编译]
E --> F[成果整理]
F --> G[固件发布]

style A fill:#8bc34a
style E fill:#ff9800
style G fill:#2196f3
```

1. **环境准备** - 检查服务器性能、释放磁盘空间、安装必要软件包
2. **代码获取** - 从指定仓库和分支克隆 OpenWrt 源码
3. **依赖处理** - 安装 feeds、应用补丁、下载依赖包
4. **编译配置** - 应用自定义设置和配置
5. **固件编译** - 使用多线程进行编译
6. **成果整理** - 打包固件并上传到 Release 或作为构件保存

---

## 🚀 使用方法

### 手动触发构建
在 GitHub Actions 页面选择对应的工作流，点击 "Run workflow" 即可开始构建。

### 定时构建
项目设置了定时任务，会按照 cron 表达式定期执行构建。

### 自定义构建
修改配置文件或自定义脚本，然后提交更改即可触发新的构建。

---

## 🛡️ 环境要求

| 组件     | 要求         | 备注                 |
| -------- | ------------ | -------------------- |
| 操作系统 | Ubuntu 22.04 | GitHub Actions 环境  |
| CPU      | 至少 4 核    | 推荐 8 核或更多      |
| 内存     | 8GB 以上     | 编译过程需要大量内存 |
| 磁盘空间 | 20GB 以上    | 编译过程占用大量空间 |

---

## 📦 Docker 构建

项目还提供 Docker 镜像构建支持：
- 使用 [Dockerfile](docker/Dockerfile) 和 [buildImageX.sh](docker/buildImageX.sh) 脚本
- 支持 ARM64 架构的容器化运行
- 包含预配置的 OpenWrt 环境

---

## 📝 注意事项

⚠️ **编译过程中需要大量磁盘空间和计算资源**  
⚠️ **定期清理旧的构建记录以节省存储空间**  
⚠️ **根据实际需求选择完整版或迷你版构建**  
⚠️ **可通过修改配置文件自定义插件和功能**  
⚠️ **请遵守当地法律法规使用网络相关功能**  
⚠️ **项目支持 LEDE 和 ImmortalWrt 两个源码分支**  

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来帮助改进此项目！

---

## 📜 许可证

本项目遵循 [GPLv2 License](LICENSE)，仅供学习交流使用。