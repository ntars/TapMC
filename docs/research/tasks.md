# TapMC 产品升级任务清单

## 完成状态：P2 功能补全中

### 基础设施
- ✅ 竞品调研（100 条 GitHub 话题差距分析）
- ✅ Rust GUI 壳编译通过（6.2MB macOS ARM64）
- ✅ Java 后端 WebSocket 服务正常
- 🔄 全量验证通过（6/6）

### 功能差距清单

#### P0 - 账号与登录（Yggdrasil 离线模式）✅ [已完成]
- ✅ 协议扩展：添加 `player.loginOffline` 方法
- ✅ Rust GUI：离线账号选择器（用户名输入）
- ✅ Java 后端：离线玩家身份生成逻辑
- ✅ 测试：离线模式完整流程验证

#### P2 - Java 运行时自动探测 ✅ [已完成]
- ✅ Rust GUI：Java 版本探测逻辑
- ✅ 支持 Java 8-25 自动检测
- ✅ JVM 参数自动适配（Apple Silicon 等）
- ✅ UI 显示：当前 Java 版本信息
- ✅ 单元测试：2 个测试用例通过

#### P2 - 实例与整合包管理 ⏳ [待实现]
- [ ] 协议扩展：`instance.*` 方法族
- [ ] 实例创建/删除/重命名
- [ ] 整合包导入（.zip/.mrpack）
- [ ] 模板复制功能

#### P2 - 模组管理（Quilt/Fabric/Forge）⏳ [待实现]
- [ ] 协议扩展：`mod.*` 方法族
- [ ] 自动识别 Modrinth/CurseForge 平台
- [ ] Fabric/Quilt/Forge 加载器自动匹配
- [ ] 模组启用/禁用开关

#### P2 - 下载与更新框架 ⏳ [待实现]
- [ ] 断点续传支持
- [ ] Modrinth API 集成
- [ ] CurseForge API 集成
- [ ] 下载队列管理

#### P2 - 日志与诊断 ⏳ [待实现]
- [ ] 崩溃报告导出（.txt/.zip）
- [ ] 日志高亮显示（Error/Warn/Info）
- [ ] 崩溃日志分析规则库
- [ ] 日志搜索与过滤

#### P2 - 界面中文本地化 ✅ [已完成]
- ✅ Rust GUI：完整中文字体支持
- ✅ 界面文案中文化（50+ 文本）
- ✅ 字体资源嵌入
- ✅ 多语言切换设置
- ✅ 单元测试：4 个测试用例通过

#### P2 - 平台特定优化 ⏳ [待实现]
- [ ] Windows Dark Theme 支持
- [ ] Apple Silicon 性能优化
- [ ] 高 DPI 缩放适配
- [ ] 系统主题自动检测

#### P2 - 运行时稳定性与错误恢复 ⏳ [待实现]
- [ ] Java 进程崩溃自动重启
- [ ] WebSocket 断线自动重连
- [ ] 错误恢复策略（重试/降级）
- [ ] 健康检查接口

## 完成标准
1. 全部 9 个差距功能实现
2. 每个功能有单元测试
3. 全量验收通过（6/6）
4. 产出物：dist/server + dist/web + dist/tapmc-shell
