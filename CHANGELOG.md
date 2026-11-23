## [Unreleased]
### 新增

- P2 Java 运行时自动探测：支持 Java 8-25 版本的自动检测与适配，Apple Silicon 平台优化
- P2 界面中文本地化增强：50+ UI 文本完整中英文切换支持，新增 4 个单元测试
- Rust GUI 启动器优化：集成 Java 版本探测，UI 显示当前 Java 版本信息


- 自动化任务板与一键验收入口：`scripts/build_release.sh` 产出服务端 jar、启动包、Web 产物与 `SHA256SUMS`；`scripts/verify_release.sh` 串起构建、单测、冒烟、存档端到端与前后端契约测试。
- 持久化存档：服务端默认写 `./world.json`，支持退出保存、按 revision 定时保存、坏档隔离与尺寸/格式校验；新增 `--save-file` / `--autosave` / `--no-save`。
- 前端断线自动重连：断线后按 500ms/1s/2s 退避重试三次，成功后重建 hello → snapshot → mods → join 闭环；UI 显示「重连中 N/3」。
- 可复现环境引导 `scripts/env.sh`：临时 Gradle HOME、Flutter PATH 与可达性检测，不再把开发机代理端口写进仓库。
- 运行期性能基准 `scripts/bench.sh` + `scripts/bench/bench.dart`：实测单连接 P50/P95、10 并发错误率与服务端 RSS，结果落盘 `tmp/bench/result.json`。
- 375×667 竖屏与 667×375 横屏的布局断言测试；横屏控制区改到右侧滚动栏，不再把世界区挤扁。

### 修复

- 翻译模块集成：修复 main.rs 中缺少的 mod localization; 声明
- 格式宏错误：修复 format! 宏的字符串字面量要求


- `player.join` 重复调用不再重置玩家位置；连接断开时服务端会移除对应玩家并摘除广播目标。
- Gradle Wrapper 的代理配置不再写死失效地址；本机死代理不再阻断 Gradle/Dart 构建。
- 存档分片下载可经镜像恢复；发布构建在无外网重定向链路时仍可复现。
- 发布校验清单去掉注释行，`cd dist && shasum -c SHA256SUMS` 可直接全量校验。

### 测试

- Rust 单元测试 20/20 通过（新增 4 个 localization 测试）
- Java 版本探测测试：Java 17/21 格式正确解析


- 真机实测：Android 蓝叠 Release APK 与 Windows Parallels Windows 11 Release 可执行文件均成功连接本机后端，完成世界渲染与玩家位置显示。

- 后端 84 个用例通过（含存档、幂等 join、断连清理、模组动态加载）；前端单测 14 个通过、8 个 e2e 默认跳过。
- 基准实测：P50 0.222ms / P95 0.348ms；10 并发 400/400 无错误；RSS 平均 84.7MB 峰值 85.9MB。widget 测试断言两种窄屏尺寸无溢出且方向键不压地图。
- `scripts/persist_verify.sh` 实测：退出写盘合法、重启后 384 格逐格一致、`SIGKILL` 后 autosave 内容与内存一致。
- `scripts/smoke.sh --expect-protocol 1.0 --no-web` 实测通过；发布构建产出 `dist/server/server-0.1.0-all.jar` 与 `dist/web/`。

## [0.1.0] - 2026-11-18

### 新增

- P2 Java 运行时自动探测：支持 Java 8-25 版本的自动检测与适配，Apple Silicon 平台优化
- P2 界面中文本地化增强：50+ UI 文本完整中英文切换支持，新增 4 个单元测试
- Rust GUI 启动器优化：集成 Java 版本探测，UI 显示当前 Java 版本信息


- Java 后端四模块：`protocol`（线协议）、`mod`（模组 SPI）、`core`（游戏本体）、`server`（WebSocket 网关）。
- Flutter 前端三层：`domain`（纯模型）、`data`（RPC 与传输）、`presentation`（UI 与状态）。
- JSON-RPC 2.0 over WebSocket 协议：10 个方法与事件，9 个错误码。
- 七端构建配置：Android、iOS、Windows、macOS、Linux、Web、HarmonyOS。
- 示例模组与模组状态查询（`system.mods`）。

### 变更

- 移除 Android 构建中的 `ndkVersion` 声明：项目无原生 C/C++ 代码，NDK 实际用不到，构建耗时由 24 分钟降至 12.9 秒。

### 测试

- 后端 61 个用例通过（含 `GameEngineTest` 22 个、`RpcDispatcherTest`、`ModLifecycleTest`）。
- 前端单元测试 10 个、端到端契约测试 8 个通过。
