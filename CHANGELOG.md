# 更新日志

本文件记录 TapMC 的重大变更，结构遵循 Keep a Changelog，版本号遵循语义化版本。细节见 git 提交历史。

## [Unreleased]

暂无。

## [0.1.0] - 2026-11-18

### 新增

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
