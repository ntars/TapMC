[简体中文](README.md) | [English](README_EN.md)

# TapMC

**可模组化的多人沙盒游戏骨架：Flutter 七端前端 + Java 服务端，两者只通过一份 JSON-RPC 2.0 协议耦合。**

![Status](https://img.shields.io/badge/status-skeleton-8957e5?style=flat-square)
[![Version](https://img.shields.io/badge/version-0.1.0-fb8500.svg?style=flat-square)](#)
[![GitHub license](https://img.shields.io/github/license/ntars/TapMC?style=flat-square)](./LICENSE)
[![Backend](https://img.shields.io/badge/backend-Java%2021-ED8B00.svg?style=flat-square&logo=openjdk&logoColor=white)](./core/backend)
[![Frontend](https://img.shields.io/badge/frontend-Flutter%203.32-02569B.svg?style=flat-square&logo=flutter&logoColor=white)](./core/frontend)
[![Tests](https://img.shields.io/badge/tests-82%20backend%2B12%20frontend-2ea44f.svg?style=flat-square)](#)

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

**用一条可验证的边界，把「规则」与「呈现」明确分开**，并且这条边界要能被第三方模组复用，而不是只服务于官方客户端。

### 2.3 核心思路

后端是唯一的真相来源，前端只负责呈现与输入。世界状态、规则判定、模组钩子全部在 Java 侧；Flutter 拿到的是「当前该画什么」，它自己不做任何游戏规则判断。两端唯一的耦合面是 [`core/docs/protocol.md`](./core/docs/protocol.md)。

### 2.4 适用场景

- 需要一个可运行、可扩展的多人游戏骨架，而不是成品游戏；
- 想验证「Flutter 前端 + JVM 服务端」这条组合在游戏场景下的可行性；
- 需要一个模组 SPI 的最小可参照实现（编译期隔离、事件顺序明确）。

### 2.5 不适用场景

- 想要开箱即玩的成品游戏：当前只有 24×16 的二维网格、五种方块、无鉴权；
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
| 无持久化 | ~~服务重启即重置地图~~ | 已解决：0.2.0 起默认写 `world.json`，重启逐格恢复 |
| 存档不含玩家位置 | 重启后需重新加入，回到出生点 | 见 15.2，待定离线玩家语义 |
| 无鉴权 | 连上即分配玩家 id，仅适合本机与可信局域网 | 默认只绑 `127.0.0.1`，对外暴露前须自行加网关 |
| 单线程串行 | 并发连接数受限于单核处理能力 | 骨架阶段的正确性优先；扩展需在 `server` 层引入会话队列 |
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

`core` 模块不出现 JSON、网络、线程。带来的直接结果是整局游戏逻辑可以不起端口跑单元测试——`GameEngineTest` 的 22 个用例即在无端口状态下完成。

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

服务默认监听 `127.0.0.1:8777`，并把世界存到启动目录下的 `world.json`。换路径或关掉存档：

```bash
java -jar server/build/libs/server-0.1.0-all.jar --save-file ~/.tapmc/world.json --autosave 30
java -jar server/build/libs/server-0.1.0-all.jar --no-save          # 纯内存，退出即弃
```

前端产物用 `flutter build <platform>` 生成，按各平台常规方式分发。

### 7.4 升级与卸载

升级即替换二进制或安装包；世界数据在 `world.json`，升级不会覆盖它（读档尺寸不符时才回退新地图）。
卸载删除安装目录即可，不写系统位置；`world.json` 是玩家数据，按需自行保留或删除。

### 7.5 模组动态加载

把实现了 `cn.ntars.tapmc.mod.TapMcMod` SPI 的 jar 放到 `./mods/`，启动服务端即自动加载（仓库自带示例在 `examples/mods/`，复制过去才会生效）：

```bash
java -jar dist/server/server-0.1.0-all.jar --mods ./mods --no-save
# 试跑示例：cp examples/mods/guard-mod.jar ./mods/
```

每个 jar 用独立子 `URLClassLoader` 加载，jar 内可自带同名依赖；卸载时关闭加载器释放文件句柄。
`system.mods` 会列出动态模组与内置模组，状态为 `ACTIVE` / `FAILED` / `DISABLED`。
实测：把 `examples/mods/guard-mod.jar` 复制进 `./mods/` 后，`system.mods` 出现 `test.guard`，放置 `WOOD` 返回 `-32004`（被模组拦下）；移走 jar 后不再拦截。示例默认不放在 `./mods/`，避免影响标准验收。
注意：模组与服务端同进程运行，没有安全沙箱，只加载可信 jar。

---


### 7.6 容器化

仓库提供 `Dockerfile` 与 `docker-compose.yml`：服务端在容器内监听 `0.0.0.0:8777`，
存档与模组目录挂卷；Web 静态站点由 nginx 在 `8080` 端口提供。

```bash
./scripts/build_release.sh          # 先产出 dist/web 供 compose 挂载
docker compose up -d --build
curl http://127.0.0.1:8080/         # Web 产物
# 服务端健康检查在容器内部每 30 秒执行一次，探测 127.0.0.1:8777
docker compose ps                   # 观察 server 状态为 healthy
```

没有 Docker 时可用本地等价命令验证健康检查探针：

```bash
env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u http_proxy -u https_proxy -u all_proxy \
  bash -lc 'source scripts/env.sh; tapmc_env_init; ./scripts/health_verify.sh'
```

脚本起真实后端，分别断言运行中探针退出码 0、停止后退出码 1。
健康检查只证明进程在监听端口，不替代握手与契约测试。

---

## 八、快速开始

两条命令、两个终端，十分钟内看到画面。

```bash
# 终端 1：起服务
cd core/backend && ./gradlew :server:run

# 终端 2：起前端
cd core/frontend && flutter run -d chrome
```

预期结果：浏览器出现 24×16 网格，能看到地形、能用方向键走动、能挖方块与放方块。后端短暂停止后前端会自动重连（500ms/1s/2s 退避，最多三次），成功后自动重放 hello → snapshot → mods → join 并恢复世界；三次失败后停在错误页，可手动点「重试」。Web 部署时可用 `?server=ws://host:port` 指定后端地址。

真机联调时，服务端绑 `0.0.0.0`，前端指定主机：

```bash
cd core/backend && ./gradlew :server:run --args="--host 0.0.0.0"
cd core/frontend && flutter run --dart-define=TAPMC_SERVER_HOST=192.168.1.10
```

### 8.1 一条命令自检

不确定环境是否正常时，先跑冒烟脚本：它自己起后端、跑握手、起静态服务验 Web 产物，然后收干净进程。

```bash
./scripts/smoke.sh
```

预期输出（关键行）：

```text
[probe] system.hello OK  protocolVersion=1.0  world=24x16  blockTypes=5
[probe] player.join OK  id=player-1-75416  pos=(12,8)
[smoke] 通过  protocolVersion=1.0  日志：.../tmp/smoke
```

| 参数 | 作用 |
|---|---|
| `--no-web` | 只验后端，跳过 Web 产物检查 |
| `--build-web` | 先跑 `flutter build web --release` 再验（首次约 1–3 分钟） |
| `--expect-protocol 1.0` | 断言服务端协议版本，防两侧常量单边漂移 |
| `--keep` | 结束后留下进程，便于人工连上去排查 |

退出码：`0` 通过、`1` 断言失败、`2` 环境缺命令。失败时自动打印对应日志的最后 40 行，完整日志在 `tmp/smoke/`。

脚本只依赖 `java` 与 `dart`：探针 `scripts/smoke/probe.dart` 只用 `dart:io`，不引第三方包，因此不必先 `pub get`。

### 8.2 存档自检

存档的实际行为（不只是单测）由另一个脚本验证：它开两次真实进程，中间隔一次 `SIGTERM` 与一次 `SIGKILL`。

```bash
./scripts/persist_verify.sh
```

预期输出（关键行）：

```text
[persist] 存档合法  24x16  blocks=384  bytes=3183
[persist] 逐格一致  384 格全等  24x16
[persist] SIGKILL 后仍有存档  24x16  blocks=384
[persist] autosave 内容与内存一致  384 格
[persist] 通过
```

三轮分别验三条路径：

| 轮次 | 起停方式 | 验的是什么 |
|---|---|---|
| 第一轮 | `SIGTERM` | 退出钩子写盘；存档 JSON 结构合法 |
| 第二轮 | 复用同一路径重启 | 读档生效，快照逐格等于第一轮 |
| 第三轮 | `autosave=1s` 后 `SIGKILL` | 定时存档能在退出钩子失效时兜底 |

退出码：`0` 通过、`1` 断言失败、`2` 环境缺命令。工作目录在 `tmp/persist/`（已 gitignore），不会碰真实的 `world.json`。

### 8.3 发布构建与整体验收

```bash
./scripts/build_release.sh          # 产出 dist/server + dist/web + dist/SHA256SUMS
./scripts/verify_release.sh         # 一条命令跑完 6 项验收
```

验收项：后端 82 个单测 → 前端 12 个单测 → 发布构建 → 协议冒烟 → 存档三轮端到端 → 前后端真实契约。`verify_release.sh --skip-e2e` 可在不便跑真实后端契约时跳过最后一项。发布目录可直接分发：`dist/server/server-0.1.0-all.jar` 用 `java -jar` 启动，`dist/web/` 是静态站点，`SHA256SUMS` 用于核对产物完整性。完整发布与部署说明见 [RELEASE.md](./RELEASE.md)。

---

## 九、配置说明

| 键名 | 类型 | 默认值 | 必填 | 取值范围 | 作用 |
|---|---|---|---|---|---|
| `--host` | 字符串 | `127.0.0.1` | 否 | 合法 IPv4 / 主机名 | 服务端监听地址 |
| `--port` | 整数 | `8777` | 否 | 1–65535 | 服务端监听端口 |
| `--save-file` | 字符串 | `world.json` | 否 | 可写路径 | 存档文件路径（相对当前工作目录） |
| `--save [路径]` | 布尔 + 可选路径 | 开启 | 否 | — | 显式开启存档，可顺带指定路径 |
| `--no-save` | 布尔 | 关闭 | 否 | — | 关闭存档，世界只存在内存里 |
| `--autosave` | 整数 | `60` | 否 | 0–86400（秒） | 定时存档周期；`0` 表示只在退出时存 |
| `TAPMC_SERVER_HOST` | 字符串（编译期宏） | `127.0.0.1` | 否 | 合法 IPv4 / 主机名 | 前端连接的服务端地址，经 `--dart-define` 注入 |

配置优先级：命令行参数 > 默认值；前端只有编译期宏一种来源，不读配置文件。

热更新：协议与方法表支持热重载调试（Flutter 侧），服务端配置修改需重启进程。

存档默认开启：不存档的版本一重启就抹掉玩家成果，作为可交付产品不合适，故默认写 `./world.json`（该文件已在 `.gitignore` 中）。一次性验证请传 `--no-save`。

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
├── scripts/
│   ├── smoke.sh                 一键冒烟：起后端 + 握手探针 + Web 产物检查
│   ├── macos_verify.sh          一键验 macOS 桌面端：构建 + 启动 + 断言 player.join
│   ├── persist_verify.sh        一键验存档：退出写盘 + 重启恢复 + SIGKILL 定时保存
│   ├── build_release.sh         一键发布构建：服务端 jar + Web 产物 + SHA256SUMS
│   ├── verify_release.sh        一键整体验收：构建 + 测试 + 冒烟 + 存档 + 契约
│   ├── env.sh                   构建环境引导：代理检测、Gradle/Flutter 路径归一
│   ├── smoke/probe.dart         握手探针（零依赖，只用 dart:io）
│   ├── persist/probe.dart       存档探针：改世界并导出快照用于逐格比对
│   └── macos_verify/
│       ├── relay.dart           透明中转探针：转发并记录每条 JSON-RPC 报文
│       └── reject_server.dart   失败路径探针：握手后立刻断开，验应用不崩
└── core/
    ├── backend/                 Java 服务进程（四模块）
    │   ├── protocol/            线协议：报文、错误码、方法名、DTO
    │   ├── mod/                 模组 SPI：TapMcMod、ModContext、事件
    │   ├── core/                游戏本体：世界、玩家、规则、模组加载
    │   │   └── storage/         存档接口（WorldStore / StorageException），不绑格式
    │   └── server/              网关：WebSocket、RPC 分发、广播
    │       ├── storage/         JSON 存档实现：原子写入 + 坏档隔离
    │       └── SaveDaemon.java  定时存档线程（按 revision 判断是否真需要写）
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
| macOS 构建 | 31 s（增量）/ 40.6 MB 产物 | `flutter build macos --release`，Xcode 27 |
| macOS 启动 | 四步握手 72 ms | `./scripts/macos_verify.sh --no-build`，从 `CLIENT_CONNECTED` 到 `JOIN_OK` |
| Android 构建 | 12.9 s | 移除 `ndkVersion` 声明后，`flutter build apk --debug` |
| Android 首次构建 | 24 min | 其中绝大部分为 NDK r28c（约 2.8 GB）下载 |
| 后端测试 | 84 个用例全通过 | `./gradlew clean build --no-daemon` |
| 前端测试 | 14 通过 / 8 跳过 | `flutter test`；含两种窄屏尺寸的布局断言，跳过项是需真实后端的 e2e |
| 存档写入 | 3183 字节（JSON，24×16=384 格） | `./scripts/persist_verify.sh` |
| 存档重启恢复 | 384 格逐格一致，三轮验证 < 25 s | 同上；含退出钩子与 SIGKILL 定时存档两条路径 |

实测运行期基准（Apple Silicon arm64 / macOS 27，`./scripts/bench.sh`，单连接 200 次 + 10 并发 × 40 次）：

| 指标 | 结果 | 条件 |
|---|---|---|
| 单连接往返 P50 | 0.224 ms | `world.getBlock`，连接预热后 200 次 |
| 单连接往返 P95 | 0.402 ms | 同上 |
| 10 并发错误率 | 0.00%（400/400 完成） | 每连接 40 次；每 5 次掺一次 `world.snapshot` |
| 服务端 RSS | 平均 85.0 MB，峰值 86.3 MB | 基准期间 0.2s 采样，共 26 次 |

基准使用临时端口与 `--no-save`，不覆盖玩家存档；完整机器可读结果在 `tmp/bench/result.json`。这些数字是本机基线，不是 SLA。

窄屏布局已用 widget 测试实测：375×667 竖屏时控制区在世界下方，667×375 横屏时控制区退到右侧 240px 滚动栏；两种尺寸下方向键与网格无重叠、无 RenderFlex overflow。命令：`cd core/frontend && flutter test test/home_page_layout_test.dart`。这是尺寸与几何断言，不是逐像素 golden。

---

## 十三、安全与隐私

- **无鉴权**：连接即分配玩家 id，没有账号体系，也没有令牌。
- **默认只绑本机**：服务端默认监听 `127.0.0.1`，不对局域网广播；真机联调需显式 `--host 0.0.0.0`，此时同一网段内任何人可连接。
- **存档为明文 JSON**：世界内容写在本机 `world.json`，不含任何玩家凭据；文件权限继承进程 umask，多人共用机器时需自行收紧目录权限。
- **无遥测**：不上报任何统计，不请求外部接口。
- **模组边界**：模组在服务端进程内运行，属于受信任代码，不是安全沙箱；加载不可信模组前需自行评估。

漏洞上报渠道见 [SECURITY.md](./SECURITY.md)。

---

## 十四、兼容性说明

| 平台 | 编译 | 运行 | 说明 |
|---|---|---|---|
| Web | 通过 | 通过 | `flutter build web --release` 本轮退出码 0、11.5 s；冒烟脚本校验静态产物可访问 |
| Android | 历史通过 | 待验 | 早期 `flutter build apk --debug` 产出 142 MB APK；本轮 Android Gradle 发行包 URL 网络不可达，无法重验 |
| macOS | 历史通过 | 历史通过 | 早期 `flutter build macos --release` 产出 40.6 MB `.app` 并实跑完成握手；本轮本机只有 Command Line Tools、缺 Xcode，`flutter build macos` 报 `Xcode not installed` |
| iOS | 待验 | 待验 | `flutter build ios --release` 报 `Xcode not installed`；ATS 已配本地网络 |
| Linux | 待验 | 待验 | `flutter build linux --release` 报 `only supported on Linux hosts`，本机为 macOS |
| Windows | 待验 | 待验 | `flutter build windows --release` 报 `only supported on Windows hosts`，本机为 macOS |
| HarmonyOS | 待验 | 待验 | 需鸿蒙版 Flutter SDK，见 [`core/frontend/docs/harmonyos.md`](./core/frontend/docs/harmonyos.md)；本机未安装 |

「待验」表示代码与平台配置已就位、缺的是构建环境，不写成通过。本轮逐端探测命令统一为 `cd core/frontend && flutter build <platform> --release`，原始输出见各端验收结论；运行环境要求：JDK 21+、Flutter 3.32+。

macOS 端的构建与运行可一条命令复现（自动起后端、架中转探针、启动 `.app`、断言 `player.join` 已落地）：

```bash
./scripts/macos_verify.sh              # 含构建，约 1 分钟
./scripts/macos_verify.sh --no-build   # 复用已有产物，约 15 秒
```

预期输出（关键行）：

```text
[macos] 产物：.../Release/TapMC.app（39M）
[macos] 报文轨迹：
  C>S req id=0 method=system.hello
  S>C hello protocolVersion=1.0 world=24x16
  S>C snapshot 24x16 blocks=384
  C>S req id=3 method=player.join
  JOIN_OK JOIN_RESULT id=player-1-78125 pos={x: 12, y: 8}
[macos] 通过  ...
```

| 参数 | 作用 |
|---|---|
| `--no-build` | 跳过 `flutter build macos`，直接验已有产物 |
| `--app <path>` | 指定待验的 `.app` 路径 |
| `--timeout <秒>` | 等 `player.join` 的上限，默认 90 |
| `--keep` | 结束后留下进程，便于人工连上去排查 |

退出码：`0` 通过、`1` 断言失败、`2` 环境缺命令、`3` 端口 8777 已被占用（此时验出来的结果可能来自旧进程，直接判失败）。

---

## 十五、已知问题与限制

### 15.1 已知问题

| 问题 | 影响范围 | 临时规避 | 跟踪 |
|---|---|---|---|
| 存档为整份快照 | 每次写盘重写 384 格；世界变大后写入开销线性上升 | 24×16 下实测约 3 ms，暂无影响 | 需要时改增量存档 |
| 存档不带玩家位置 | 重启后玩家需重新 `player.join`，位置回到出生点 | 手动走回去 | 0.2.x 计划中 |
| 重连最多三次 | 连续断线三次后停止自动重连 | 点错误页的「重试」重新走完整首屏加载 | 三次后转人工，避免无限重试 |
| 无鉴权 | 仅适合本机与可信局域网 | 不对外暴露端口 | 路线图第 2 项（随动态加载一并设计） |
| 单线程串行 | 高并发下延迟上升 | 限制连接数 | 未排期 |


### 15.2 未实现功能

| 功能 | 未实现原因 | 计划状态 |
|---|---|---|
| 玩家位置持久化 | 需要先定「离线玩家」的语义（是否保留位、是否被占格挡住） | 计划中 |
| 多存档槽 / 世界命名 | 单机场景暂无需求 | 未排期 |

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
| 持久化存档（`core` 加接口，`server` 读写） | 0.2.0 | 已完成：JSON 存档 + 退出/定时双路径 + 坏档隔离 |
| 模组动态加载（隔离类加载器 + 目录扫描） | 0.3.0 | 已实现，见 7.5；安全沙箱仍未实现 |
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
| `core/backend/` 的 Gradle 包装器（`gradlew` `gradle/` `build.gradle.kts` 等） | Apache-2.0 |
| `core/frontend/` `core/docs/` | MIT |
| 根级 `README.md` `README_EN.md` `CHANGELOG.md` `CONTRIBUTING.md` `SECURITY.md` 等文档与配置 | MIT |
| 品牌名称、Logo、界面设计 | 保留所有权利 |

**默认归属**：上表未列出的本项目自研文件，一律适用根 `LICENSE`（Apache-2.0）。逐路径路由与再分发须保留的文件清单见 [LICENSING.md](./LICENSING.md)。

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
