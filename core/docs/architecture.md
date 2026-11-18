# 架构设计

这份文档记录**为什么这么切**，以及**否决了什么**。代码能告诉你「是什么」，
只有这里能告诉你「为什么不是另一种样子」。

---

## 一、总体形状

```
┌──────────────────────────────────────────────────────────┐
│                         Flutter                          │
│                                                          │
│   presentation          UI 与状态，ChangeNotifier         │
│        ↓                                                 │
│      data               RPC / 传输 / 仓储                 │
│        ↓                                                 │
│     domain              纯数据模型，零 IO                  │
└────────────────────────┬─────────────────────────────────┘
                         │  JSON-RPC 2.0 over WebSocket
                         │  ws://host:8777
┌────────────────────────┴─────────────────────────────────┐
│                          Java                            │
│                                                          │
│      server             WebSocket / RPC 分发 / 广播       │
│        ↓                                                 │
│       core              世界、玩家、规则、模组加载          │
│        ↓                                                 │
│        mod              模组 SPI                          │
│                                                          │
│      protocol           线协议（被 server 与 mod 共享）     │
└──────────────────────────────────────────────────────────┘
```

两边的分层都是**单向向下**。这条约束不是风格偏好，它的价值在于：
任何一层出问题，排查范围天然被限定在它和它的下游。

---

## 二、前端为什么不把游戏逻辑也写一份

新手最直觉的做法是「前端本地先算一遍，再跟服务器对一次」——响应快，离线也能玩。
这里明确不做，原因有三：

1. **双份规则必然漂移**。同一个「水不能走」的判定写两遍，改一处忘一处，
   表现是「本地能走、服务端说不行」，用户看到的是角色卡住却不知道原因。
2. **模组只在服务端**。模组可以否决任何动作，前端无法预判它会不会否决，
   所以本地算出来的结果随时可能被推翻，白算。
3. **骨架阶段要的是链路正确**。等链路稳了再谈预测，那时候的预测也应该是
   「服务端确认后回滚」的机制，而不是"各算一份"。

所以前端拿到 `WorldChange` 事件后只做一件事：`_world.withBlock(change.pos, change.block)`。
它不判断这个变化合不合理——那是后端已经做完的事。

---

## 三、通信为什么选 JSON-RPC 2.0 over WebSocket

候选方案四个，逐个否决：

| 方案 | 否决理由 |
|---|---|
| **gRPC** | 浏览器端必须走 gRPC-Web，需要额外代理层（Envoy 之类）。骨架阶段引入一个反向代理，运维成本和「能跑」的目标直接冲突。 |
| **REST + 轮询** | 方块变化需要实时同步。轮询要么延迟高、要么请求量大。要做实时就得再叠一层 SSE，等于两个协议。 |
| **自定义二进制** | 省带宽，但调试必须写解析工具。骨架阶段最需要的是 `curl`/浏览器直接看报文，二进制把这个能力拿走，换来的带宽收益在这个数据量下等于零。 |
| **JSON-RPC 2.0 over WebSocket** ✅ | 浏览器原生支持 WebSocket；一套协议同时覆盖「请求-响应」和「服务端主动推送」；报文是 JSON，肉眼可读，出问题不用加日志就能定位。 |

JSON-RPC 而非「自定义 JSON 消息」的理由：它有现成的规范，`jsonrpc`/`id`/`method`/
`params`/`result`/`error` 这几个字段的含义不用自己定义，也不用向新人解释。省下的是
设计成本，不是流量成本。

### 报文形状的一条硬规则：null 字段不序列化

`RpcDispatcher` 与 `EventBroadcaster` 都用裸 `new GsonBuilder().create()`，**不**开
`serializeNulls()`。

原因是 JSON-RPC 2.0 规定：成功响应不含 `error`，失败响应不含 `result`，通知不含 `id`。
如果 null 也写出去，报文里会出现三个字段全在、只是值不同的情况，接收方就必须判空
才能区分「成功还是失败」——而判空是最容易写错的一类代码。

省略之后，**字段存在即有意义**，类型判断变成一次 `containsKey`。这条规则在
`RpcDispatcherTest` 里被逐条断言锁住，改坏会让测试红。

---

## 四、后端为什么切成四块

```
server ──→ core ──→ mod
   └────────┴──────→ protocol
```

| 模块 | 如果把它合进别的模块，会失去什么 |
|---|---|
| `protocol` | 「改协议」失去唯一落点。协议类会散在 `server` 和 `mod` 里，改一个字段要翻两个包 |
| `mod` | 第三方写模组时必须依赖 `core`（连带整个游戏引擎）。SPI 的隔离性消失 |
| `core` | 游戏逻辑被迫和 WebSocket 混在一起，单元测试必须先起端口 |
| `server` | 换传输层（进程内直调、命令行、未来的 QUIC）时必须改游戏逻辑 |

### `core` 零网络依赖是硬约束

`core` 的 `build.gradle.kts` 里只有 `api(project(":protocol"))`，没有 Gson、没有
WebSocket 库。这不是懒得加，是故意的：

```java
// GameEngineTest 里 22 个用例的一个 —— 不需要端口，不需要连接
GameEngine engine = new GameEngine(new WorldGrid(8, 8));
Outcome<PlayerState> result = engine.move("p1", MoveDirection.EAST);
assertTrue(result.isOk());
```

如果 `GameEngine` 能发网络请求，测试就得考虑「服务没起怎么办」，测试会变慢且不稳。

### `mod` 不含 `core` 让「模组不能乱来」变成编译期约束

`ModContext` 接口是模组能看到的**全部**世界操作：

```java
int worldWidth();
int worldHeight();
String getBlock(int x, int y);
boolean setBlock(int x, int y, String block);
void onBlockPlace(BlockPlaceListener listener);
void onBlockBreak(BlockBreakListener listener);
void onPlayerMove(PlayerMoveListener listener);
```

没有 `WorldGrid world()`。模组拿不到网格引用，就只能走这些方法，也就绕不过
`setBlock` 里的广播与边界检查。**这个限制写在类型系统里，不是写在文档里。**

反过来说，`GameEngine` 同时实现 `ModContext`，把「引擎自己」和「模组视角」
用同一个接口对齐——模组看到的和引擎暴露的必须是同一套语义，否则模组的行为会
和引擎的规则产生微妙差异。

---

## 五、一个连接一个玩家身份

`RpcDispatcher` 持有 `playerId` 字段，在 `player.join` 成功后写入。之后
`player.move` 用这个 id，而不是从 `params` 里读。

这个设计带来一个必须显式处理的坑：`GameServer.handleStateless()` 每次调用都
**新建** dispatcher，身份自然是空的。所以：

| 方法 | 该走哪条路 | 误用的结果 |
|---|---|---|
| `system.hello` | `handleStateless()` | — |
| `world.snapshot` | `handleStateless()` | — |
| `world.getBlock` | `handleStateless()` | — |
| `player.join` | 连接的 dispatcher | — |
| `player.move` | 连接的 dispatcher | `-32001 NOT_JOINED` |

方法名从 `handle()` 改成 `handleStateless()` 就是为了让误用在代码评审时可见——
一个叫 `handle` 的方法被用在 `player.move` 上，读代码的人不会警觉；叫
`handleStateless` 就会。

---

## 六、坐标系统

二维网格，**原点在左上角**，x 向右递增，y 向下递增。

```
 (0,0) ──────→ x
   │  ┌──┬──┬──┐
   │  │  │  │  │
   ↓  ├──┼──┼──┤
   y  │  │  │  │
      └──┴──┴──┘
```

所以 `NORTH` 是 y−1，`SOUTH` 是 y+1。这与「数学坐标系」（y 轴向上）相反，
与「屏幕坐标系」一致。

选屏幕坐标系的原因：渲染时不用做 y 翻转。代价是所有涉及方向的代码必须记住
「北是减」，这也是为什么 `MoveDirection` 把 `dx`/`dy` 直接写在枚举里——

```java
NORTH(0, -1), SOUTH(0, 1), WEST(-1, 0), EAST(1, 0)
```

方向与位移绑在同一个地方，就不会出现「这里判断北、那里减错了」的问题。

---

## 七、模组的失败隔离

`ModLoader` 的三条规则：

| 情况 | 处理 | 为什么 |
|---|---|---|
| `metadata()` 抛异常 | 记 `FAILED`，id 显示 `<unknown>` | 连身份都拿不到，不能算加载 |
| `onLoad()` 抛异常 | 记 `FAILED` 并保留原因，**继续加载下一个** | 一个坏模组拖垮全服是最容易引发用户流失的问题 |
| 同 id 重复注册 | 第一个生效，后续记 `DISABLED` | 静默覆盖会让「为什么我的模组没生效」变成悬案 |

`FAILED` 的模组**不会**被注册任何监听器——半初始化的模组比没有模组更危险，
因为它可能持有部分状态并在后续事件里崩溃。

---

## 八、事件为什么可以取消，且理由「首次胜出」

```java
public void cancel(String reason) {
    if (this.cancelReason == null) {   // 先到先得
        this.cancelReason = reason;
    }
}
```

多个模组同时拦下同一个动作时，只有第一个的理由被记录。这是刻意的：

- 如果每次 `cancel` 都覆盖，最终用户看到的理由是「最后一个加载的模组」说的，
  而那个模组未必是最相关的原因。
- 如果拼接所有理由，用户会收到一长串互相矛盾的说明。

「首次胜出」至少保证了**可预测**——模组的加载顺序是确定的，理由就是确定的。

---

## 九、Flutter 端的几个具体决定

### 状态管理用 `ChangeNotifier`，不引库

骨架阶段只有一个页面、一个会话对象。引 Riverpod / Bloc 会多一层没人读的样板。
`GameSession` 的注释里写明了这个取舍，将来页面变多时再换，改动面被限制在
`presentation/` 内。

### 装配放在 `State` 里，不做全局单例

```dart
// main.dart
void initState() {
  _rpc = RpcClient(WebSocketTransport(AppConfig.endpoint));
  _session = GameSession(GameRepository(_rpc), _rpc);
}
void dispose() { _session.dispose(); _rpc.dispose(); }
```

全局单例在 Flutter 热重载时会留下旧的连接——旧的没关、新的又开，端口上挂一堆
僵尸连接。放在 `State` 里，`dispose` 能保证连接跟着 widget 一起释放。

### `transport.dart` 是接口，不是类

因为测试需要 `FakeTransport`。`rpc_client_test.dart` 的 10 个用例全部跑在假传输上，
不需要真实端口，跑完不到一秒。如果传输层写死成 `WebSocket`，这 10 个用例就得改成
集成测试，慢且不稳。

### 没有 `material_ui`

鸿蒙社区分叉（`openharmony-sig/flutter_flutter`）当前最高稳定线是
`3.41.10-ohos-1.0.0`，而 `material_ui` 要求 Flutter ≥3.47。两者不能共存。

取舍是：**保鸿蒙端能构建**，放弃 `material_ui` 的新组件。代价是
`analysis_options.yaml` 里要忽略 `deprecated_member_use`（`MaterialStateProperty`
之类）。理由写在那份配置的注释里，不是静默忽略。

详细版本对照与接入步骤见 [../frontend/docs/harmonyos.md](../frontend/docs/harmonyos.md)。

---

## 十、网络与平台配置的坑

这些是踩过的，记下来省得再踩：

| 平台 | 配置 | 不加会怎样 |
|---|---|---|
| Android | `INTERNET` 权限 | 直接抛 `SocketException` |
| Android | `usesCleartextTraffic="true"` | 明文 `ws://` 被系统拦掉，报「明文流量不允许」 |
| macOS | `network.client` entitlement | 沙箱阻止出站连接，报 `Operation not permitted` |
| iOS | ATS `NSAllowsLocalNetworking` | 本地网络请求被 ATS 拒绝 |

另外两个**非平台特有**但极容易踩的：

1. **Java 与 Gradle 都不读 `HTTPS_PROXY` 环境变量**。走代理时必须显式写
   `systemProp.https.proxyHost` / `proxyPort` 到 `gradle.properties`。表现为
   `PKIX path building failed`——报的是证书错误，实际是流量没走代理。
2. **鸿蒙端不能用 `Platform.isOhos`**。`dart:io` 的 `Platform` 里没有这个成员。
   要用 `defaultTargetPlatform`，并通过 `flutter create --platforms ohos .`
   在本地生成 `ohos/` 目录（不入库）。

---

## 十一、这份骨架刻意没做的事

列出来是为了避免「以为是漏了」：

| 没做 | 因为要做的话得先解决 |
|---|---|
| 持久化 | 存档格式与版本迁移策略 |
| 鉴权 | 账号体系，或者至少 token 方案 |
| 多线程处理请求 | 引擎非线程安全，要先设计分区或加锁粒度 |
| 模组动态加载 | 类加载器隔离 + 安全沙箱（模组能读文件吗？能起线程吗？） |
| 世界高度 | 协议 `BlockPos` 加 `z`、渲染换投影、寻路重写 |
| 玩家实体属性 | 生命值/背包/朝向会影响协议与 UI 两处 |

顺序建议在根 [README](../README.md) 的「下一步」里，那里按影响面从小到大排了序。
