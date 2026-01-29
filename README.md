# OpenWrt 自动化构建项目

这是一个用于自动化编译和构建 OpenWrt 固件的项目，支持多个版本的 OpenWrt 源码（包括 LEDE 和官方版本），并提供完整的 CI/CD 流程。

## 项目特性

- 支持 LEDE 和官方 OpenWrt 源码的自动编译
- 提供完整版和迷你版两种固件构建选项
- 集成 GitHub Actions 实现自动化构建流程
- 支持定时构建和手动触发构建
- 包含多种常用插件和主题
- 可自定义网络配置和系统设置

## 构建目标

项目提供了以下几种构建工作流：

### 1. X86_64 Full LEDE
- 基于 Lean's LEDE 源码的完整版固件
- 包含所有常用功能和插件
- 工作流文件：[X86_64-LEDE.yml](.github/workflows/X86_64-LEDE.yml)

### 2. X86_64 Mini LEDE
- 基于 Lean's LEDE 源码的精简版固件
- 只保留基本功能，体积更小
- 工作流文件：[X86_64-Mini-LEDE.yml](.github/workflows/X86_64-Mini-LEDE.yml)

### 3. X86_64 Combined LEDE
- 将完整版和迷你版合并的构建
- 一次构建获得两个版本的固件
- 工作流文件：[X86_64-Combined-LEDE.yml](.github/workflows/X86_64-Combined-LEDE.yml)

### 4. X86_64 Combined Official
- 基于官方 OpenWrt 源码的构建
- 支持官方 OpenWrt 25.12 分支
- 工作流文件：[X86_64-Combined-Official.yml](.github/workflows/X86_64-Combined-Official.yml)

### 5. 清理旧工作流
- 定期清理过期的 GitHub Actions 工作流记录
- 工作流文件：[Delete-Old-Workflows.yml](.github/workflows/Delete-Old-Workflows.yml)

## 包含的插件和功能

### 插件列表
- OpenAppFilter (应用过滤)
- Openlist (网盘挂载工具)
- AdGuard Home (广告拦截)
- NetData (系统监控)
- MosDNS (DNS 解析)
- PassWall (科学上网)
- 网速测试工具

### 主题和界面
- Argon 主题 (带自定义背景图片)
- Luci 界面优化

### 系统优化
- 自动设置默认 IP 地址
- 版本号显示为编译日期
- 优化的系统默认设置

## 配置文件

项目包含四种不同的配置文件：
- [x86_64.config](configs/x86_64.config) - LEDE 完整版配置
- [x86_64-mini.config](configs/x86_64-mini.config) - LEDE 迷你版配置
- [x86_64-official.config](configs/x86_64-official.config) - 官方版完整配置
- [x86_64-official-mini.config](configs/x86_64-official-mini.config) - 官方版迷你配置

## 自定义脚本

### diy-feeds.sh
用于添加额外的 feeds 源，如 PassWall 插件源。

### diy-full.sh 和 diy-mini.sh
用于自定义固件配置，包括：
- 添加额外插件
- 更换主题背景
- 修改版本号显示
- 修复特定问题

### init-settings.sh
在首次启动时应用默认设置，如主题配置。

## 构建流程

1. **环境准备**：检查服务器性能、释放磁盘空间、安装必要软件包
2. **代码获取**：从指定仓库和分支克隆 OpenWrt 源码
3. **依赖处理**：安装 feeds、应用补丁、下载依赖包
4. **编译配置**：应用自定义设置和配置
5. **固件编译**：使用多线程进行编译
6. **成果整理**：打包固件并上传到 Release 或作为构件保存

## 使用方法

### 手动触发构建
在 GitHub Actions 页面选择对应的工作流，点击 "Run workflow" 即可开始构建。

### 定时构建
项目设置了定时任务，会按照 cron 表达式定期执行构建。

### 自定义构建
修改配置文件或自定义脚本，然后提交更改即可触发新的构建。

## 环境要求

- Ubuntu 22.04 (GitHub Actions 环境)
- 至少 4 核 CPU，推荐 8GB 以上内存
- 足够的磁盘空间用于编译过程

## 注意事项

- 编译过程中需要大量磁盘空间和计算资源
- 定期清理旧的构建记录以节省存储空间
- 根据实际需求选择完整版或迷你版构建
- 可通过修改配置文件自定义插件和功能

## 许可证

本项目遵循 [LICENSE 文件](LICENSE) 的条款。