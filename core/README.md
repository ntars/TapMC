# TapMC

一个可模组化的多人沙盒游戏骨架。**技术栈只有两部分**：Flutter 做全部前端，
Java 做全部后端——不引入第三样东西。

```
core/
├── backend/        Java 游戏服务进程（四模块）
├── frontend/       Flutter 多端应用（七端）
└── docs/
    ├── architecture.md   分层设计与取舍
    └── protocol.md       前后端通信契约
```

## 一句话说清架构

**后端是唯一的真相来源，前端只负责呈现与输入。**

世界状态、规则判定、模组钩子全部在 Java 侧；Flutter 拿到的是「当前该画什么」，
它自己不做任何游戏规则判断。这条分工决定了：改规则只需动后端，改界面只需动前端，
两端唯一的耦合面就是 [docs/protocol.md](docs/protocol.md) 里那份协议。

```
┌───────────────────────────────────────────┐
│  Flutter（Android/iOS/Win/mac/Linux/Web/鸿蒙）│
│  presentation → data → domain              │
└──────────────────┬────────────────────────┘
                   │  JSON-RPC 2.0 over WebSocket
                   │  ws://127.0.0.1:8777
┌──────────────────┴────────────────────────┐
│  Java 服务进程                              │
│  server → core → mod                       │
│         ↘ protocol ↙                       │
└───────────────────────────────────────────┘
```

## 快速的十分钟跑通

两条命令，两个终端。

```bash
# 终端 1：起服务（需要 JDK 21+）
cd backend && ./gradlew :server:run

# 终端 2：起前端（需要 Flutter 3.32+）
cd frontend && flutter run -d chrome
```

浏览器里出现 24×16 的网格，能看到地形、能用方向键走动、能挖方块和放方块。
关掉终端 2 的进程再重连，会看到状态条从「已连接」变成「连接失败」并在几秒后重试。

想跑原生端就把 `-d chrome` 换成 `-d macos` / `-d windows` / `-d linux`。
真机联调时服务端要绑 `0.0.0.0`，前端要指定主机：

```bash
cd backend && ./gradlew :server:run --args="--host 0.0.0.0"
cd frontend && flutter run --dart-define=TAPMC_SERVER_HOST=192.168.1.10
```

## 目录导航

| 想了解 | 去哪看 |
|---|---|
| 后端怎么分层、模块边界在哪 | [backend/README.md](backend/README.md) |
| 前端三层怎么分、依赖怎么装 | [frontend/README.md](frontend/README.md) |
| 协议有哪些方法、字段什么意思 | [docs/protocol.md](docs/protocol.md) |
| 为什么这么设计、否决了哪些方案 | [docs/architecture.md](docs/architecture.md) |
| 鸿蒙端怎么接、卡在哪个版本 | [frontend/docs/harmonyos.md](frontend/docs/harmonyos.md) |

## 各端状态

**这份表是实测结果，不是愿望清单。** 骨架阶段的诚实边界比覆盖率更重要。

| 平台 | 编译 | 运行 | 说明 |
|---|---|---|---|
| Web | ✅ 通过 | ✅ 通过 | `flutter build web --release` 实测 13.2s 完成 |
| Android | ✅ 通过 | ⏳ 待验 | `flutter build apk --debug` 实测产出 142MB APK，包名与权限已校验 |
| macOS | ⏳ 待验 | ⏳ 待验 | entitlements 已配 `network.client`，本机无 Xcode |
| iOS | ⏳ 待验 | ⏳ 待验 | ATS 已配本地网络，本机无 Xcode |
| Linux | ⏳ 待验 | ⏳ 待验 | 需在 Linux 宿主上构建，macOS 交叉编译不支持 |
| Windows | ⏳ 待验 | ⏳ 待验 | 需在 Windows 宿主上构建 |
| HarmonyOS | ⏳ 待验 | ⏳ 待验 | 需鸿蒙版 Flutter SDK，见 [接入文档](frontend/docs/harmonyos.md) |

「待验」的含义是：**代码和平台配置都已就位，缺的是构建环境，不是缺实现。**
换成有对应 SDK 的机器，预期能直接编过；但也确实没有亲手验证过，所以不写成通过。

Android 端的实测细节值得记一笔，它同时暴露了 Flutter 模板的一个无用开销：

```
Package: cn.ntars.tapmc    App label: TapMC    compileSdk: 36
Permissions: INTERNET, ACCESS_NETWORK_STATE
Output: app-debug.apk (142 MB, debug 未裁剪)
```

首次构建耗时 24 分钟，其中绝大部分花在下载 **NDK r28c（约 2.8GB）** 上。
本项目没有任何原生 C/C++ 代码，`web_socket_channel` 是纯 Dart 包——NDK 实际用不到，
它是被模板里 `ndkVersion = flutter.ndkVersion` 这一行拉下来的。

已从 `android/app/build.gradle.kts` 移除该声明，实测重新构建仍然通过，
耗时从 24 分钟降到 **12.9 秒**。将来引入带原生代码的插件时再加回来。

后端侧不受影响：

| 项 | 结果 |
|---|---|
| 后端编译 | ✅ 通过 |
| 后端测试 | ✅ 61 个全通过 |
| 前后端联通 | ✅ 真实 WebSocket 握手，hello/snapshot/getBlock/breakBlock/事件推送全部收到 |
| 前端单元测试 | ✅ 10 个全通过 |
| 前端端到端契约测试 | ✅ 8 个全通过 |

## 后端模块

依赖方向单向向下，不允许反向引用。

```
server ──→ core ──→ mod
  └────────┴──────→ protocol
```

| 模块 | 一句话 | 关键约束 |
|---|---|---|
| `protocol` | 线协议：报文、错误码、方法名、DTO | 不含任何业务判断 |
| `mod` | 模组 SPI：`TapMcMod`、`ModContext`、事件 | 不依赖 core |
| `core` | 游戏本体：世界、玩家、规则、模组加载 | 零网络、零 JSON |
| `server` | 网关：WebSocket、RPC 分发、广播 | 零游戏规则 |

`core` 没有网络依赖这件事值得强调：它意味着整局游戏的逻辑可以不起端口跑单元测试，
`GameEngineTest` 的 22 个用例就是这么跑的。

## 前端分层

```
presentation  ←  UI、状态（ChangeNotifier）
     ↓
   data       ←  RPC 客户端、传输层、仓储
     ↓
  domain      ←  纯数据模型与常量，不含 IO
```

`domain` 在最底下且不依赖任何 Flutter 之外的东西，所以模型可以脱离 UI 单独测试；
`data` 里 `transport.dart` 是抽象接口，`web_socket_transport.dart` 是唯一实现——
换传输方式时上层代码不用动，测试里换成 `FakeTransport` 就能跑（`rpc_client_test.dart` 的做法）。

## 一些刻意的决定

| 决定 | 理由 |
|---|---|
| 用 JSON-RPC 2.0 而非 gRPC / REST | 浏览器不能直接用 gRPC；REST 无双向推送；JSON-RPC 一套搞定又能肉眼调试 |
| 世界是二维网格 | 加高度要同时改协议、渲染、寻路。骨架阶段先把链路跑通 |
| 一个连接一个玩家身份 | 身份存在 `RpcDispatcher` 里，所以 `handleStateless()` 会明确报错而不是静默串号 |
| 不引入 `material_ui` | 它要求 Flutter ≥3.47，而鸿蒙社区分叉最高稳定线是 3.41.10-ohos，二选一 |
| 模组拿不到 `WorldGrid` | 只能走 `ModContext`，把「模组不能绕过规则」变成编译期约束 |

前两条在 [docs/architecture.md](docs/architecture.md) 里有完整的否决方案对比。

## 已知边界

骨架阶段的取舍，不是遗漏：

| 边界 | 现状 |
|---|---|
| 无持久化 | 重启即重置地图 |
| 无鉴权 | 连上即分配玩家 id |
| 单线程串行 | `onMessage` 对引擎加锁，并发低但正确性明确 |
| 模组不能动态加载 | 只能在代码里注册，动态加载需要类加载器隔离 |
| 玩家只有坐标 | 无生命值、背包、朝向 |
| 二维世界 | 无高度、无区块、无光照 |

## 环境要求

| 项 | 要求 | 用途 |
|---|---|---|
| JDK | 21+ | 后端编译与运行 |
| Flutter | 3.32+（推荐 3.41.x 以兼顾鸿蒙） | 前端构建 |
| Android SDK | cmdline-tools + platform 34+ | 仅 Android 端构建需要 |
| Xcode | 完整安装 + CocoaPods | 仅 iOS / macOS 端构建需要 |

Gradle 用仓库自带 wrapper，不必本机安装。`backend/gradle.properties` 与
`frontend/android/gradle.properties` 里各有一段代理配置——Java 和 Gradle 都不读
`HTTPS_PROXY` 环境变量，必须显式写；换到无代理网络时把那几行注释掉即可。

## 下一步往哪走

骨架已经通了，接下来按「不破坏现有契约」的顺序推进：

1. **加持久化**——`core` 加存档接口，`server` 在启动/关闭时读写。协议不用动。
2. **模组动态加载**——`ModLoader` 加 `URLClassLoader`，每个模组一个隔离类加载器。
   这一步会牵出安全沙箱问题，需要先定「模组能做什么」的边界。
3. **世界加高度**——牵动协议（`BlockPos` 加 `z`）、渲染（等距投影）、寻路，
   影响面最大，放最后。
4. **补平台验证**——在带 Xcode / Android SDK / Windows / Linux 的机器上跑一遍
   `flutter build`，把上面那张状态表的 ⏳ 换成实测结果。

改协议前先读 [docs/protocol.md](docs/protocol.md) 第八节，那里写了改协议的流程。

## 版权与许可

Copyright (c) 2026 星玖工作室 Ntarstudio

本项目按目录分层授权，**只使用 Apache License 2.0 与 MIT 两种宽松许可证**：

| 路径 | 许可 |
|---|---|
| `backend/protocol/` `backend/core/` `backend/mod/` `backend/server/` | Apache-2.0 |
| `frontend/` `docs/` | MIT |
| 品牌名称、Logo、界面设计 | 保留所有权利 |

全文见仓库根 [LICENSE](../LICENSE)（Apache-2.0）与 [LICENSE-MIT](../LICENSE-MIT)（MIT），分层说明见 [LICENSING.md](../LICENSING.md)，第三方组件见 [NOTICE](../NOTICE)。

**为什么协议层用 Apache-2.0**：协议层是被第三方实现、适配、对接的那一层。Apache-2.0 比 MIT 多给明示专利授权（第 3 条）与 NOTICE 保留义务（第 4 条 d 项），让别人放心按协议实现。

**两种许可都无传染性**：第三方模组可以闭源，第三方客户端也可以闭源——这是骨架能长出生态的前提。
