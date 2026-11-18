# TapMC 前端

Flutter 应用，一套代码覆盖 **Android / iOS / Windows / macOS / Linux / Web /
HarmonyOS** 七端。它是后端的客户端：世界状态由后端决定，这里只负责呈现与收集输入。

## 三层结构

```
lib/
├── domain/          纯数据模型与常量，零 IO、零 Flutter UI 依赖
│   ├── protocol.dart      JSON-RPC 版本号、错误码、方法名（与 Java 逐条对齐）
│   ├── geometry.dart      BlockPos、MoveDirection
│   ├── block_type.dart    方块枚举 + 线名 + 可通行性
│   └── models.dart        ServerInfo / WorldSnapshot / PlayerState / WorldChange / ModInfo
│
├── data/            与后端打交道
│   ├── transport/
│   │   ├── transport.dart              抽象接口 + TransportException
│   │   └── web_socket_transport.dart   唯一实现
│   ├── rpc/rpc_client.dart             请求配对、超时、事件流
│   └── game_repository.dart            把 RPC 包成领域方法
│
├── presentation/    UI 与状态
│   ├── game_session.dart    ChangeNotifier，单向数据流的中心
│   ├── pages/home_page.dart 响应式主界面
│   └── widgets/             world_grid.dart、direction_pad.dart
│
├── core/            主题与启动配置
└── main.dart        依赖装配
```

**依赖只能向下**：`presentation → data → domain`。`domain` 不 import 任何下层之外的
东西，所以模型能脱离 UI 单独测试。

## 快速开始

```bash
flutter pub get
flutter run -d chrome          # 最快，无需额外 SDK
flutter run -d macos           # 需要完整 Xcode
flutter run -d windows         # 需要 Windows 宿主 + VS C++ 工具链
flutter run -d linux           # 需要 Linux 宿主 + cmake/ninja/GTK
```

启动前先让后端跑起来：

```bash
cd ../backend && ./gradlew :server:run
```

### 连到别的机器

默认地址按平台自动选：Android 用 `10.0.2.2`（模拟器映射宿主机），其余用
`127.0.0.1`。真机联调时服务端要绑 `0.0.0.0`，前端指定开发机 IP：

```bash
# 后端
./gradlew :server:run --args="--host 0.0.0.0"

# 前端
flutter run --dart-define=TAPMC_SERVER_HOST=192.168.1.10
```

`AppConfig.serverHost` 读的就是这个编译期常量。没做运行时配置界面是刻意的——
骨架阶段先让「能连上」成立，配置 UI 属于后续功能。

## 测试

```bash
flutter test                                          # 10 个单元测试
TAPMC_E2E=1 flutter test test/e2e_contract_test.dart  # 8 个端到端契约测试
```

| 文件 | 覆盖 | 需要后端 |
|---|---|---|
| `rpc_client_test.dart` | 报文形状、id 配对、超时、事件分流、断连处理 | 否（`FakeTransport`） |
| `e2e_contract_test.dart` | 与真后端逐方法对齐字段名与错误码 | 是 |

端到端测试**默认跳过**，必须显式设 `TAPMC_E2E=1`。不用 `--dart-define` 是因为
`dart-define` 只注入 `String.fromEnvironment` 常量，测试里的运行时判断读不到它；
`Platform.environment` 才能在运行时拿到。

后者存在的意义：它是唯一能发现「Java 改了字段名、Dart 没跟上」的地方。
单元测试用假数据传输，两边各自都自洽，只有真连一次才会暴露不一致。

## 关键实现说明

### `Transport` 是接口

因为测试需要 `FakeTransport`。10 个单元测试全跑在假传输上，不起端口，一秒内跑完。
如果传输层写死成 `WebSocket`，这些用例就得改成集成测试——慢且不稳。

### 请求超时 10 秒

没有超时的话，一个丢失的响应会让 `Future` 永远悬挂，UI 上表现为「按钮一直转圈」。
超时后迟到的响应会被丢弃（`_pending` 里没有对应 id，直接 return）。

### 断连时立即失败所有等待者

`_failAllPending()` 在 `onDone` 里被调用。不这么做的话，连接断了之后每个请求都要
各自等满 10 秒才报错，用户看到的是界面卡住十秒。

### 装配放在 `State` 里

```dart
void initState() {
  _rpc = RpcClient(WebSocketTransport(AppConfig.endpoint));
  _session = GameSession(GameRepository(_rpc), _rpc);
}
void dispose() { _session.dispose(); _rpc.dispose(); }
```

全局单例在热重载时会留下旧连接——旧的没关、新的又开，端口上挂一堆僵尸。放在
`State` 里，`dispose` 保证连接跟着 widget 一起释放。

### 为什么没有 `material_ui`

`material_ui` 要求 Flutter ≥3.47，而鸿蒙社区分叉最高稳定线是 `3.41.10-ohos-1.0.0`。
两者不能共存，选择保鸿蒙端可构建。代价是 `analysis_options.yaml` 里要忽略
`deprecated_member_use`，理由写在配置注释里，不是静默忽略。

## 各端配置

| 平台 | 已配 | 说明 |
|---|---|---|
| Android | `INTERNET`、`ACCESS_NETWORK_STATE`、`usesCleartextTraffic="true"` | 明文 `ws://` 不加最后一项会被系统拦掉 |
| iOS | ATS `NSAllowsLocalNetworking`、`NSLocalNetworkUsageDescription` | 本地网络访问需声明 |
| macOS | `network.client` entitlement（Debug + Release 都有） | 沙箱默认禁止出站连接 |
| Web | `index.html` / `manifest.json` 标题与主题色 | — |
| Windows | `runner/main.cpp`、`Runner.rc` 应用名 | — |
| Linux | `runner/my_application.cc` 窗口标题 | — |
| HarmonyOS | 见 [docs/harmonyos.md](docs/harmonyos.md) | `ohos/` 目录本地生成，不入库 |

统一标识：应用名 `TapMC`，包名 `cn.ntars.tapmc`。

## 已知边界

| 边界 | 现状 |
|---|---|
| 只有一个页面 | 无房间、无设置、无服务器列表 |
| 无本地状态持久化 | 重启即重新连接 |
| 无断线自动重连 | 断了显示错误与重试按钮，需手动点 |
| 无输入预测 | 每次移动等后端确认，网络差时手感有延迟 |
| 无国际化 | 中文硬编码在代码里 |

前两条是骨架阶段的取舍；「无断线重连」是显式选择——自动重连要处理重连期间的
操作队列、身份恢复、状态重同步三件事，半成品比没有更糟，所以先留手动重试。
