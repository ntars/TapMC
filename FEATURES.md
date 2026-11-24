# TapMC 功能验证清单

## 已完成的功能

### Flutter 前端
- ✅ Flutter Web 构建成功 (2.5MB main.dart.js)
- ✅ 无 Tauri/Rust 依赖，纯 Flutter 实现
- ✅ WebSocket 连接后端
- ✅ 模组管理页面 (mod_page.dart)
- ✅ 实例管理页面 (instance_page.dart)
- ✅ 日志与诊断页面 (log_page.dart)
- ✅ 下载管理器 (download_manager.dart)
- ✅ 游戏启动器 (game_launcher.dart)
- ✅ 启动设置对话框 (launch_settings.dart)
- ✅ Java 版本管理器 (java_version_manager.dart)
- ✅ Modrinth API 集成
- ✅ CurseForge API 集成

### Java 后端
- ✅ Gradle 多模块构建 (core, protocol, mod, server)
- ✅ WebSocket 服务端
- ✅ 实例管理器 (InstanceManager.java)
- ✅ 存档系统 (WorldStore.java, JsonWorldStore.java)
- ✅ 模组加载器 (ModLoader.java, DirectoryModLoader.java)
- ✅ RPC 分发器 (RpcDispatcher.java)
- ✅ 事件广播系统 (EventBroadcaster.java)

### 构建配置
- ✅ flutter pubspec.yaml
- ✅ gradle settings.gradle.kts
- ✅ gradle build.gradle.kts

## 待验证功能（需要运行时测试）

### 游戏启动
- ⏳ Java 运行时检测
- ⏳ JAR 文件加载
- ⏳ JVM 参数配置
- ⏳ 游戏进程管理

### 模组功能
- ⏳ Modrinth 模组搜索
- ⏳ CurseForge 模组搜索
- ⏳ 模组启用/禁用
- ⏳ 模组版本管理

### 实例功能
- ⏳ 创建新实例
- ⏳ 删除实例
- ⏳ 实例配置

### 日志系统
- ⏳ 实时日志显示
- ⏳ 日志导出
- ⏳ 日志过滤

## 构建产物位置

### Flutter Web
- `core/frontend/build/web/` (2.5MB)
  - main.dart.js (2.5MB)
  - flutter_bootstrap.js
  - index.html

### Java 后端
- `core/backend/server/build/libs/`
  - server-0.1.0.jar (32KB)
  - server-0.1.0-all.jar (602KB)

## 部署脚本
- `scripts/deploy.sh` - 构建部署脚本
- `scripts/start.sh` - 启动脚本
