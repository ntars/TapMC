# TapMC P2 功能发布清单

## 必需项（必须完成才能发布）

### 1. 核心编译验证
- [x] Flutter 前端 `flutter analyze` 无错误（仅 info warning）
- [x] 后端 Java 编译通过  
- [x] `server/build/libs/server-0.1.0-all.jar` 可运行

### 2. P2 功能实现
- [x] Java 运行时自动探测（`lib/domain/java_runtime.dart`）
  - [x] 支持 Java 8-25 自动检测
  - [x] JVM 参数自动适配（Apple Silicon 等）
  - [x] UI 显示当前 Java 版本信息
- [x] 实例与整合包管理（`instance_page.dart`, `instance_list_item.dart`）
  - [x] 协议扩展：`instance.list`, `instance.delete`
  - [x] 实例创建/删除
  - [x] 模板复制功能（UI 已就绪）
- [x] 模组管理（Quilt/Fabric/Forge）基本框架
  - [x] 协议扩展：`mod.list`, `mod.enable`, `mod.disable`
  - [x] 模组启用/禁用开关（UI 已就绪）
- [x] 下载与更新框架（`download_page.dart`）
  - [x] 断点续传支持（UI 已就绪）
  - [x] 下载队列管理
- [x] 日志与诊断（`log_page.dart`）
  - [x] 崩溃报告导出
  - [x] 日志高亮显示（Error/Warn/Info）
- [ ] 平台特定优化
  - [ ] Windows Dark Theme 支持（需要 Windows 构建环境）
  - [ ] Apple Silicon 性能优化
- [ ] 运行时稳定性与错误恢复
  - [ ] Java 进程崩溃自动重启（GUI 层已支持重连）
  - [ ] WebSocket 断线自动重连（已实现）

### 3. 文档
- [x] README.md 已更新（技术架构章节）
- [x] protocol.md 协议文档已同步
- [x] CHANGELOG.md 已更新

### 4. 构建产物
- [x] Flutter Web (`build/web`) 
- [x] 后端 JAR (`core/backend/server/build/libs/server-0.1.0-all.jar`)

## 当前状态
| 功能 | 状态 |
|------|------|
| Java 运行时自动探测 | ✅ 完成 |
| 实例管理 | ✅ UI/协议完成，后端需要补充 |
| 模组管理 | ✅ UI/协议完成，后端需要补充 |
| 下载与更新框架 | ✅ UI 完成 |
| 日志与诊断 | ✅ UI 完成 |
| 支持的 Platform | ✅ Flutter Web (跨平台) |

## 构建说明

### 前端构建
```bash
cd core/frontend
flutter build web --release  # Web 版本（跨平台）
```

### 后端构建
```bash
cd core/backend
./gradlew :server:fatJar  # 需要修复 Gradle SSL 问题
```

### 运行
```bash
# 启动后端
java -jar core/backend/server/build/libs/server-0.1.0-all.jar --port 8777

# 启动前端（在另一个终端）
cd core/frontend && flutter run -d chrome
```
