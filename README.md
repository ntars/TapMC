[简体中文](README.md) | [English](README_EN.md)

# TapMC

**可模组化的多人沙盒游戏骨架：Flutter 七端前端 + Java 服务端，两者只通过一份 JSON-RPC 2.0 协议耦合。**

![Status](https://img.shields.io/badge/status-skeleton-8957e5?style=flat-square)
[![Version](https://img.shields.io/badge/version-0.1.0-fb8500.svg?style=flat-square)](#)
[![GitHub license](https://img.shields.io/github/license/ntars/TapMC?style=flat-square)](./LICENSE)
[![Backend](https://img.shields.io/badge/backend-Java%2021-ED8B00.svg?style=flat-square&logo=openjdk&logoColor=white)](./core/backend)
[![Frontend](https://img.shields.io/badge/frontend-Flutter%203.32-02569B.svg?style=flat-square&logo=flutter&logoColor=white)](./core/frontend)
[![Tests](https://img.shields.io/badge/tests-79%20passing-2ea44f.svg?style=flat-square)](#)

---

## 一、项目名称与定位

**名称**：TapMC。`Tap` 指代触屏操作，`MC` 指代沙盒游戏品类。

**一句话定位**：一个技术栈只有两部分的多人沙盒游戏骨架——Flutter 做全部前端，Java 做全部后端，中间只隔一份可肉眼调试的协议。

**仓库描述**：`可模组化的多人沙盒游戏骨架：Flutter 七端前端 + Java 服务端，JSON-RPC 2.0 over WebSocket | A moddable multiplayer sandbox game skeleton: Flutter front end, Java server, JSON-RPC 2.0 over WebSocket.`

**话题标签**（20 个，仅英文）：`sandbox-game`、`voxel`、`multiplayer`、`multiplayer-game`、`game-server`、`game-engine`、`modding`、`mod-loader`、`plugin-system`、`flutter`、`dart`、`java`、`json-rpc`、`websocket`、`cross-platform`、`desktop-game`、`mobile-game`、`harmonyos`、`gradle`、`open-source`

| 项 | 内容 |
|---|---|
| 版本 | 0.1.0 |
| 状态 | 骨架阶段：链路已通、两端测试通过，尚无发行版 |
| 仓库 | <https://github.com/ntars/TapMC> |
| 许可 | Apache-2.0 / MIT（按目录分层） |

---

## 二、项目简介

### 2.1 背景

沙盒游戏的客户端与服务端天然是一对矛盾：规则必须在服务端权威判定，否则联机就是各算各的；但手感必须在客户端即时响应，否则每一次点击都要等一个来回。多数项目在这一步滑向「两边各写一份规则」，随后陷入长期的双份真源维护。

### 2.2 要解决的问题

**用一条可验证的边界，把「规则」和「呈现」彻底分开**，并且这条边界要能被第三方模组复用，而不是只服务于官方客户端。

### 2.3 核心思路

后端是唯一的真相来源，前端只负责呈现与输入。世界状态、规则判定、模组钩子全部在 Java 侧；Flutter 拿到的是「当前该画什么」，它自己不做任何游戏规则判断。两端唯一的耦合面是 [`core/docs/protocol.md`](./core/docs/protocol.md)。

### 2.4 适用场景

- 需要一个可运行、可扩展的多人游戏骨架，而不是成品游戏；
- 想验证「Flutter 前端 + JVM 服务端」这条组合在游戏场景下的可行性；
- 需要一个模组 SPI 的最小可参照实现（编译期隔离、事件顺序明确）。

### 2.5 不适用场景

- 想要开箱即玩的成品游戏：当前只有 24×16 的二维网格、五种方块、无存档、无鉴权；
- 需要三维世界、区块加载、光照与寻路：三维会同时牵动协议、渲染与寻路，属路线图最后一项；
- 需要公网多人服务：当前是单进程串行处理，没有账号体系与反作弊。

### 2.6 优势与局限

| 优势 | 依据 |
|---|---|
| 契约先行 | 协议文档是唯一真源，Dart 与 Java 两侧常量类都由它派生 |
| 内核零网络 | `core` 模块不含 JSON、网络与线程，整局逻辑可不起端口跑单测（22 个用例） |
| 模组隔离是编译期约束 | 模组只能拿到 `ModContext`，拿不到 `WorldGrid`，绕不过规则 |
| 无第三条技术栈 | 只有 Flutter 与 Java，构建链与调试链各一套 |

| 局限 | 影响范围 | 规避方式 |
|---|---|---|
| 无持久化 | 服务重启即重置地图 | 路线图第 1 项，`core` 加存档接口即可，协议不动 |
| 无鉴权 | 连上即分配玩家 id，仅适合本机与可信局域网 | 默认只绑 `127.0.0.1`，对外暴露前须自行加网关 |
| 单线程串行 | 并发连接数受限于单核处理能力 | 骨架阶段的正确性优先；扩展需在 `server` 层引入会话队列 |
| 模组不能动态加载 | 新模组需重新编译启动 | 路线图第 2 项，`ModLoader` 加隔离类加载器 |
| 二维世界 | 无高度、无区块、无光照 | 路线图第 4 项，影响面最大，刻意排最后 |

---

## 三、核心功能

### 3.1 世界与操作

| 功能 | 触发条件 | 结果 |
|---|---|---|
| 取整图 | 前端首屏调用 `world.snapshot` | 返回 `width × height` 的行优先方块数组 |
| 读单格 | 渲染或交互需要时调用 `world.getBlock` | 返回方块类型名；越界返回 `AIR` 而非报错 |
| 放方块 | 玩家在空格上操作，调用 `world.placeBlock` | 返回 `WorldChange`，并向所有连接广播 `event.worldChanged` |
| 破方块 | 玩家在可破坏方块上操作，调用 `world.breakBlock` | 同上；`WATER` 与 `WOOD` 不可破坏 |
| 移动 | 方向键或屏幕方向键，调用 `player.move` | 返回新坐标；越界返回 `-32002` |

### 3.2 会话与模组

| 功能 | 触发条件 | 结果 |
|---|---|---|
| 握手 | 连接建立后调用 `system.hello` | 返回服务名、版本、协议版本、世界尺寸与方块类型表 |
| 加入世界 | 调用 `player.join` | 分配玩家身份并加入世界；未加入时调用玩家方法返回 `-32001` |
| 列模组 | 调用 `system.mods` | 按加载顺序返回模组 id、名称、版本、状态与失败原因 |

### 3.3 前端七端

Android、iOS、Windows、macOS、Linux、Web、HarmonyOS 共用同一份业务代码；平台差异只在构建配置与窗口外壳。

---

## 四、核心特性

### 4.1 契约先行：一份协议，两侧派生

协议文件是唯一真源，前端常量类与后端常量类都从它派生，改协议时三处必须同步。这条纪律的收益在联调期最明显：字段错位不会变成「偶发空白画面」，而是握手阶段直接报版本不匹配。

### 4.2 内核零网络依赖

`core` 模块不出现 JSON、网络、线程。带来的直接结果是整局游戏逻辑可以不起端口跑单元测试——`GameEngineTest` 的 22 个用例就是这么跑的，毫秒级完成。

### 4.3 模组隔离是编译期约束，不是口头约定

第三方模组只依赖 `mod` 模块，拿到的是 `ModContext` 而非 `WorldGrid`。想绕过规则改世界，编译就过不去。

### 4.4 分层单向向下

`server → core → mod`，`protocol` 被 `server` 与 `mod` 共享。任何一层出问题，排查范围天然限定在它和它的下游。

### 4.5 单进程交付

后端产出可执行 jar（`./gradlew :server:fatJar`），不依赖容器与外部中间件；前端 `flutter build` 产出各端安装包。

---

## 五、设计细节与工程取舍

| 决定 | 理由 | 被否决的方案 |
|---|---|---|
| JSON-RPC 2.0 over WebSocket | 双向推送、文本可读、错误码有现成规范 | gRPC（浏览器需代理）、REST 轮询（延迟或白耗流量）、自定义二进制（调试读不了日志）、进程内 FFI（与可独立部署冲突） |
| 世界是二维网格 | 加高度要同时改协议、渲染、寻路，骨架阶段先跑通链路 | 三维体素：留给路线图最后一项 |
| 一个连接一个玩家身份 | 身份存在 `RpcDispatcher` 里，`handleStateless()` 明确报错而不是静默串号 | 全局单一玩家：无法支持多人联机 |
| 前端不做规则预判 | 模组可以否决任何动作，本地算出的结果随时被推翻，白算 | 客户端预测：等链路稳定后再以「确认后回滚」实现 |
| 不引入 `material_ui` | 它要求 Flutter ≥ 3.47，而鸿蒙社区分叉最高稳定线是 3.41.10-ohos | 跟随上游：会失去鸿蒙端 |
| 模组拿不到 `WorldGrid` | 把「模组不能绕过规则」变成编译期约束 | 直接暴露世界对象：规则形同虚设 |

---

## 六、技术栈与依赖清单

| 层 | 运行时 / 工具 | 版本约束 |
|---|---|---|
| 后端 | JDK | 21+ |
| 后端构建 | Gradle Wrapper | 随仓库提供，无需本机安装 |
| 后端 WebSocket | Java-WebSocket | 1.6.0 |
| 后端日志 | slf4j-api / slf4j-simple | 2.0.17 |
| 前端 | Flutter | 3.32+（推荐 3.41.x 以兼顾鸿蒙） |
| 前端传输 | `web_socket_channel` | 纯 Dart 包，无原生代码 |
| 前端构建 | Android SDK / Xcode | 仅对应平台构建时需要 |

完整依赖明细与许可证见 [NOTICE](./NOTICE)。

---

## 七、安装与部署

### 7.1 环境要求

| 项 | 要求 | 用途 |
|---|---|---|
| JDK | 21+ | 后端编译与运行 |
| Flutter | 3.32+ | 前端构建 |
| Android SDK | cmdline-tools + platform 34+ | 仅 Android 端构建 |
| Xcode | 完整安装 + CocoaPods | 仅 iOS / macOS 端构建 |

### 7.2 安装与验证

```bash
git clone https://github.com/ntars/TapMC.git
cd TapMC/core/backend && ./gradlew build      # 编译并运行全部测试
cd ../frontend && flutter pub get && flutter test
```

两条命令都通过即为环境就绪。

### 7.3 部署

```bash
cd core/backend && ./gradlew :server:fatJar
java -jar server/build/libs/server-0.1.0-all.jar --port 8777
```

服务默认监听 `127.0.0.1:8777`。前端产物用 `flutter build <platform>` 生成，按各平台常规方式分发。

### 7.4 升级与卸载

骨架阶段无状态，升级即替换二进制或安装包；卸载删除目录即可，不写系统位置。

### 7.5 容器化

当前未提供镜像。服务端无外部依赖，`eclipse-temurin:21-jre` 基础镜像加一个 jar 即可，待有部署需求时补。

---

## 八、快速开始

两条命令、两个终端，十分钟内看到画面。

```bash
# 终端 1：起服务
cd core/backend && ./gradlew :server:run

# 终端 2：起前端
cd core/frontend && flutter run -d chrome
```

预期结果：浏览器出现 24×16 网格，能看到地形、能用方向键走动、能挖方块与放方块。关掉终端 2 再重连，状态条会从「已连接」变成「连接失败」并在几秒后重试。

真机联调时，服务端绑 `0.0.0.0`，前端指定主机：

```bash
cd core/backend && ./gradlew :server:run --args="--host 0.0.0.0"
cd core/frontend && flutter run --dart-define=TAPMC_SERVER_HOST=192.168.1.10
```

---

## 九、配置说明

| 键名 | 类型 | 默认值 | 必填 | 取值范围 | 作用 |
|---|---|---|---|---|---|
| `--host` | 字符串 | `127.0.0.1` | 否 | 合法 IPv4 / 主机名 | 服务端监听地址 |
| `--port` | 整数 | `8777` | 否 | 1–65535 | 服务端监听端口 |
| `TAPMC_SERVER_HOST` | 字符串（编译期宏） | `127.0.0.1` | 否 | 合法 IPv4 / 主机名 | 前端连接的服务端地址，经 `--dart-define` 注入 |

配置优先级：命令行参数 > 默认值；前端只有编译期宏一种来源，不读配置文件。

热更新：协议与方法表支持热重载调试（Flutter 侧），服务端配置修改需重启进程。

代理说明：`core/backend/gradle.properties` 与 `core/frontend/android/gradle.properties` 各有一段代理配置——Java 与 Gradle 都不读 `HTTPS_PROXY` 环境变量，必须显式写；无代理网络下注释掉即可。

---

## 十、API 与模块说明

协议为 JSON-RPC 2.0 over WebSocket，共 10 个方法与事件。

| 方法 | 方向 | 参数 | 结果 |
|---|---|---|---|
| `system.hello` | 请求 | 无 | 服务名、版本、协议版本、世界尺寸、方块类型表 |
| `system.mods` | 请求 | 无 | 模组数组（id / name / version / state / reason） |
| `world.snapshot` | 请求 | 无 | `{width, height, blocks[]}`，行优先 |
| `world.getBlock` | 请求 | `x`、`y` | 方块类型名；越界返回 `AIR` |
| `world.placeBlock` | 请求 | `x`、`y`、`block` | `WorldChange` |
| `world.breakBlock` | 请求 | `x`、`y` | `WorldChange` |
| `player.join` | 请求 | 无 | 玩家身份 |
| `player.move` | 请求 | `direction` | 新坐标 |
| `event.worldChanged` | 推送 | `change` | 方块变化广播 |
| `event.playerChanged` | 推送 | 玩家状态 | 玩家状态广播 |

错误码：

| 码 | 名称 | 含义 |
|---|---|---|
| -32700 | PARSE_ERROR | 报文不是合法 JSON |
| -32600 | INVALID_REQUEST | 缺少 `method` 等必需字段 |
| -32601 | METHOD_NOT_FOUND | 方法名未注册 |
| -32602 | INVALID_PARAMS | 参数缺失或取值非法 |
| -32603 | INTERNAL_ERROR | 服务端未捕获异常 |
| -32001 | NOT_JOINED | 未加入世界就调需要玩家身份的方法 |
| -32002 | OUT_OF_BOUNDS | 坐标超出世界边界 |
| -32003 | BLOCK_REJECTED | 该格不允许放置或破坏 |
| -32004 | CANCELLED_BY_MOD | 被模组拦下 |

`error.message` 一律为中文可展示句子，包含「发生了什么 + 下一步」。完整报文形状与拒绝顺序见 [`core/docs/protocol.md`](./core/docs/protocol.md)。

---

## 十一、目录结构

```text
TapMC/
├── LICENSE / LICENSE-MIT / LICENSING.md / NOTICE
└── core/
    ├── backend/                 Java 服务进程（四模块）
    │   ├── protocol/            线协议：报文、错误码、方法名、DTO
    │   ├── mod/                 模组 SPI：TapMcMod、ModContext、事件
    │   ├── core/                游戏本体：世界、玩家、规则、模组加载
    │   └── server/              网关：WebSocket、RPC 分发、广播
    ├── frontend/                Flutter 多端应用（七端）
    │   ├── lib/domain/          纯数据模型与常量
    │   ├── lib/data/            RPC 客户端、传输层、仓储
    │   └── lib/presentation/    UI 与状态
    └── docs/
        ├── architecture.md      分层设计与取舍
        └── protocol.md          前后端通信契约
```

---

## 十二、性能表现

已实测的构建指标（Apple Silicon，本机网络经代理）：

| 场景 | 结果 | 条件 |
|---|---|---|
| Web 构建 | 13.2 s | `flutter build web --release` |
| Android 构建 | 12.9 s | 移除 `ndkVersion` 声明后，`flutter build apk --debug` |
| Android 首次构建 | 24 min | 其中绝大部分为 NDK r28c（约 2.8 GB）下载 |
| 后端测试 | 61 个用例全通过 | `./gradlew build` |

运行期性能（帧率、并发连接数、内存占用）**尚未做基准测试**，不给出估算数字。骨架阶段的数据量（24×16 格、单进程串行）不构成性能瓶颈。

---

## 十三、安全与隐私

- **无鉴权**：连接即分配玩家 id，没有账号体系，也没有令牌。
- **默认只绑本机**：服务端默认监听 `127.0.0.1`，不对局域网广播；真机联调需显式 `--host 0.0.0.0`，此时同一网段内任何人可连接。
- **无持久化**：不写磁盘，不保存玩家数据，进程退出即无痕迹。
- **无遥测**：不上报任何统计，不请求外部接口。
- **模组边界**：模组在服务端进程内运行，属于受信任代码，不是安全沙箱；加载不可信模组前需自行评估。

漏洞上报渠道见 [SECURITY.md](./SECURITY.md)。

---

## 十四、兼容性说明

| 平台 | 编译 | 运行 | 说明 |
|---|---|---|---|
| Web | 通过 | 通过 | `flutter build web --release` 实测 |
| Android | 通过 | 待验 | 产出 142 MB debug APK，包名与权限已校验 |
| macOS | 待验 | 待验 | entitlements 已配 `network.client` |
| iOS | 待验 | 待验 | ATS 已配本地网络 |
| Linux | 待验 | 待验 | 需 Linux 宿主构建 |
| Windows | 待验 | 待验 | 需 Windows 宿主构建 |
| HarmonyOS | 待验 | 待验 | 需鸿蒙版 Flutter SDK，见 [`core/frontend/docs/harmonyos.md`](./core/frontend/docs/harmonyos.md) |

「待验」表示代码与平台配置已就位、缺的是构建环境，不写成通过。运行环境要求：JDK 21+、Flutter 3.32+。

---

## 十五、已知问题与限制

### 15.1 已知问题

| 问题 | 影响范围 | 临时规避 | 跟踪 |
|---|---|---|---|
| 无存档 | 重启即重置地图 | 无 | 路线图第 1 项 |
| 无鉴权 | 仅适合本机与可信局域网 | 不对外暴露端口 | 路线图第 2 项（随动态加载一并设计） |
| 单线程串行 | 高并发下延迟上升 | 限制连接数 | 未排期 |
| 模组不可动态加载 | 新增模组需重新编译启动 | 在代码中注册 | 路线图第 2 项 |

### 15.2 未实现功能

| 功能 | 未实现原因 | 计划状态 |
|---|---|---|
| 持久化存档 | 需要先定存档格式与恢复语义 | 计划中 |
| 模组动态加载 | 需要类加载器隔离与安全边界 | 计划中 |
| 三维世界 | 同时牵动协议、渲染与寻路 | 计划中（最后） |
| 玩家生命值、背包、朝向 | 骨架阶段只需坐标 | 未排期 |
| 多人同屏验证 | 需要多端构建环境 | 未排期 |

---

## 十六、更新日志

遵循 Keep a Changelog 与语义化版本，完整记录见 [CHANGELOG.md](./CHANGELOG.md)。

### [0.1.0] - 2026-11-18

- 新增：Java 后端四模块（protocol / mod / core / server），61 个测试通过。
- 新增：Flutter 前端三层（domain / data / presentation），单元测试 10 个、端到端契约测试 8 个通过。
- 新增：JSON-RPC 2.0 over WebSocket 协议，10 个方法与事件。
- 新增：七端构建配置与 Android NDK 声明精简（构建耗时 24 min → 12.9 s）。

---

## 十七、后续路线图

按「不破坏现有契约」的顺序推进，均为非承诺计划：

| 计划项 | 目标版本 | 状态 |
|---|---|---|
| 持久化存档（`core` 加接口，`server` 读写） | 0.2.0 | 计划中 |
| 模组动态加载（隔离类加载器 + 安全边界） | 0.3.0 | 计划中 |
| 补齐各端构建验证（Xcode / Windows / Linux / 鸿蒙） | 0.2.x | 计划中 |
| 三维世界（协议加 `z`、等距渲染、寻路） | 1.0.0 | 计划中 |

---

## 十八、参与贡献

- 开发环境：JDK 21+、Flutter 3.32+，见第七章。
- 分支模型：`main` 保持可构建；改动走 `feat/`、`fix/` 前缀分支，合并前须通过 `./gradlew build` 与 `flutter test`。
- 提交信息：`<type>(<scope>): <subject>`，type 取 `feat` / `fix` / `docs` / `refactor` / `test` / `chore`。
- 改协议：先改 `core/docs/protocol.md`，再同步两侧常量类，最后补契约测试。
- 详细流程见 [CONTRIBUTING.md](./CONTRIBUTING.md)，行为准则见 [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)。

---

## 十九、版权与许可

Copyright © 2026 星玖工作室 Ntarstudio. Licensed under Apache-2.0 / MIT.

本项目按目录分层授权，只使用 Apache License 2.0 与 MIT 两种宽松许可证：

| 路径 | 许可 |
|---|---|
| `core/backend/protocol/` `core/backend/core/` `core/backend/mod/` `core/backend/server/` | Apache-2.0 |
| `core/frontend/` `core/docs/` | MIT |
| 品牌名称、Logo、界面设计 | 保留所有权利 |

全文见 [LICENSE](./LICENSE)（Apache-2.0）与 [LICENSE-MIT](./LICENSE-MIT)（MIT），分层说明见 [LICENSING.md](./LICENSING.md)。两种许可均无传染性：第三方模组与第三方客户端都可以闭源。

---

## 二十、NOTICE 开源合规声明

第三方组件摘要：

| 组件 | 版本 | 许可证 | 用途 |
|---|---|---|---|
| Java-WebSocket | 1.6.0 | MIT | WebSocket 服务端实现 |
| slf4j-api / slf4j-simple | 2.0.17 | MIT | 日志门面与实现 |
| `web_socket_channel` | 由 Flutter SDK 约束 | BSD-3-Clause | 前端 WebSocket 传输 |

完整清单（含 Flutter 与 Gradle 依赖树）见 [NOTICE](./NOTICE)。
