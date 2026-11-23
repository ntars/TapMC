# TapMC 与成熟启动器差距分析

对比 PCL/HMCL/Prism Launcher 等成熟启动器，TapMC 在实例管理、账号支持、下载框架等方面存在以下差距：

| 优先级 | 类别 | 差距描述 | 完成度 |
|---|---|---|---|
| P2 | Java 运行时 | PCL/HMCL/Prism 支持自动探测 Java 版本，TapMC 后端依赖系统 PATH 中的 `java` 命令 | 已计划 |
| P0 | 账号与登录 | PCL/HMCL 支持 Yggdrasil 离线模式，TapMC 当前仅支持 Microsoft 账号 | 已计划 |
| P2 | 实例与整合包 | PCL 支持整合包导入导出、模板复制，TapMC 实例管理功能尚未实现 | 已计划 |
| P2 | 模组管理 | PCL/HMCL 支持 Quilt/Fabric/Forge 自动加载器识别，TapMC 需手动指定 | 已计划 |
| P2 | 下载与更新 | PCL/HMCL 支持断点续传和 Modrinth/CurseForge 镜像，TapMC 缺少下载框架 | 已计划 |
| P2 | 日志与诊断 | PCL/HMCL 支持崩溃报告导出和日志高亮，TapMC 日志查看器尚未实现 | 已计划 |
| P2 | 界面与体验 | PCL 支持深浅主题、HiDPI 缩放和中文，TapMC Rust 壳暂未适配中文 | 已计划 |
| P2 | 平台与兼容 | PCL 支持 Windows Dark Theme 和 macOS Apple Silicon，TapMC 缺少平台特定优化 | 已计划 |
| P2 | 运行时稳定性 | PCL/HMCL 支持进程监控和启动失败诊断，TapMC 缺少完善的错误恢复机制 | 已计划 |
