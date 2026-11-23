# 前后端通信协议

本文件是 Flutter 前端与 Java 后端之间**唯一的契约来源**。两端各有一份常量类
（Dart 侧 `lib/domain/protocol.dart`，Java 侧 `protocol/.../Methods.java`），
都由本文件派生；三者任意一处改动，另外两处必须同步。

## 一、为什么是 JSON-RPC 2.0 over WebSocket

先说被否掉的方案与原因，避免以后有人重新提议：

| 方案 | 否决理由 |
|---|---|
| gRPC | 浏览器不能直接用 gRPC（要 grpc-web 代理），多一层中间件只是为了移动端，不划算 |
| REST + 轮询 | 游戏需要服务端主动推（别人改了方块要立刻看到），轮询要么延迟高要么白耗流量 |
| 自定义二进制协议 | 调试时读不了日志；骨架阶段的数据量（24×16 格）不值得为省几个字节付这个代价 |
| 进程内 FFI | 与「Java 实现游戏本体、可独立部署」的定位冲突，也让桌面端的 JDK 版本耦合进前端 |

JSON-RPC 2.0 的优点是**双向**（WebSocket 之上服务端也能主动说话）、**文本**
（日志直接可读）、**成熟**（错误码与请求响应的形状有现成规范，不必自创）。

## 二、报文形状

三种报文，靠「哪些字段存在」区分。**约定：值为 null 的字段一律不序列化**，
因此「字段存在」即「有值」。

### 请求（前端 → 后端）

```json
{
  "jsonrpc": "2.0",
  "id": "7",
  "method": "world.placeBlock",
  "params": { "x": 3, "y": 4, "block": "STONE" }
}
```

- `id` 用**字符串**。JSON-RPC 允许字符串或数字，统一成字符串后两端不必为数字精度做特殊处理。
- `params` 可省略（如 `system.hello`）。省略时后端会收到 null，按「无参数」处理。

### 成功响应（后端 → 前端）

```json
{
  "jsonrpc": "2.0",
  "id": "7",
  "result": { "pos": { "x": 3, "y": 4 }, "block": "STONE", "actor": "player-1" }
}
```

**成功响应里不出现 `error` 字段**，反之亦然。前端判断成功与否只看有没有 `error`，
不必判空 `result`。

### 事件（后端 → 前端，主动推）

```json
{
  "jsonrpc": "2.0",
  "method": "event.worldChanged",
  "params": { "change": { "pos": { "x": 3, "y": 4 }, "block": "AIR", "actor": "player-2" } }
}
```

**事件没有 `id`**。前端收到后不该回任何东西。后端也不会为事件等响应。

## 三、错误码

| 码 | 名称 | 含义 | 前端该怎么处理 |
|---|---|---|---|
| -32700 | PARSE_ERROR | 报文不是合法 JSON | 属实现 bug，记日志 |
| -32600 | INVALID_REQUEST | 缺少 `method` 等必需字段 | 属实现 bug，记日志 |
| -32601 | METHOD_NOT_FOUND | 方法名未注册 | 属实现 bug，记日志 |
| -32602 | INVALID_PARAMS | 参数缺失或取值非法 | 文案可直接展示给用户 |
| -32603 | INTERNAL_ERROR | 服务端未捕获异常 | 提示「服务端内部错误」并建议反馈 |
| -32001 | NOT_JOINED | 未加入世界就调需要玩家身份的方法 | 自动补一次 `player.join` 后重试 |
| -32002 | OUT_OF_BOUNDS | 坐标超出世界边界 | 属交互 bug，UI 应限制点击范围 |
| -32003 | BLOCK_REJECTED | 该格不允许放置/破坏（已占用、是空气等） | 文案可直接展示 |
| -32004 | CANCELLED_BY_MOD | 被某个模组拦下 | 文案可直接展示，措辞用「被模组拦下：<原因>」 |

`error.message` 一律是**中文、可直接展示给人**的句子，包含「发生了什么 + 下一步」。
不要写「操作失败」，写「(3,4) 已有方块 STONE，请先破坏」。

## 四、方法表

### system

#### `system.hello`

取服务端信息。前端连上后第一个调用。

参数：无。

结果：

```json
{
  "serverName": "TapMC",
  "serverVersion": "0.1.0",
  "protocolVersion": "1.0",
  "worldWidth": 24,
  "worldHeight": 16,
  "blockTypes": ["AIR", "DIRT", "STONE", "WATER", "WOOD"]
}
```

前端应校验 `protocolVersion` 与自身支持的一致；不一致时提示版本不匹配，
不要硬连——字段错位产生的 bug 极难定位。

#### `system.mods`

列出生效的模组。

参数：无。

结果：数组，元素形状见下。顺序即加载顺序，先加载的模组先收到事件。

```json
[
  {
    "id": "cn.ntars.tapmc.sample",
    "name": "示例模组",
    "version": "1.0.0",
    "state": "ACTIVE",
    "reason": ""
  }
]
```

`state` 取值：`ACTIVE`（生效）/ `DISABLED`（被配置关闭或有同 id 冲突）/
`FAILED`（加载抛异常）。`reason` 在 `ACTIVE` 时为空串而非 null。

### world

#### `world.snapshot`

取整张地图。首屏加载用。

参数：无。

结果：

```json
{
  "width": 24,
  "height": 16,
  "blocks": ["WOOD", "WOOD", "... 共 width × height 项"]
}
```

`blocks` 按**行优先**排列，索引 `y * width + x`。用一维数组而非二维：
JSON 里二维数组体积更大，且反序列化后直接当列表用更省事。

#### `world.getBlock`

读单个方块。

参数：`x`（整数，必填）、`y`（整数，必填）。

结果：方块类型名字符串，如 `"STONE"`。**越界返回 `"AIR"`，不报错**——
渲染边缘格时会频繁读到边界外，报错等于让前端每帧都判边界。

#### `world.placeBlock`

放置方块。

参数：`x`、`y`（整数，必填）、`block`（字符串，必填，方块类型名）。

结果：`WorldChange` 对象（见下）。

拒绝条件（按检查顺序）：

1. 坐标越界 → `-32002`
2. `block` 为空或缺 → `-32602`
3. `block` 不是已知类型 → `-32602`，文案里列出可用值
4. `block` 是 `AIR` → `-32003`（清空请用破坏）
5. 目标格不是空气 → `-32003`（不允许直接覆盖已有方块）
6. 被模组取消 → `-32004`

#### `world.breakBlock`

破坏方块。

参数：`x`、`y`（整数，必填）。

结果：`WorldChange`，其中 `block` 为 `"AIR"`。

拒绝条件：坐标越界 → `-32002`；该格已是空气 → `-32003`；被模组取消 → `-32004`。

**WorldChange 的形状**（`placeBlock` / `breakBlock` 的结果，也是事件载荷的成员）：

```json
{ "pos": { "x": 3, "y": 4 }, "block": "STONE", "actor": "player-1" }
```

`actor` 是触发者 id；系统或模组改动时为 `"system"`。

### player

#### `player.loginOffline`

离线模式登录。适用于没有 Microsoft 账号的用户。

参数：

- `name`（字符串，必填）：玩家名，最长 16 字符

结果：

```json
{
  "id": "player-1-72375",
  "pos": { "x": 12, "y": 8 }
}
```

错误码：
- `-32602`：参数缺失或非法（玩家名为空或超长）
- `-32603`：服务器内部错误

注意：
- 离线模式不验证玩家名唯一性，同名玩家会共享同一游戏存档
- 玩家名不包含空格和特殊字符（仅允许字母、数字、下划线）

#### `player.join`

加入世界，占一个玩家位。

参数：无。玩家 id 由**服务端按连接分配**，前端无法指定——参数里根本没有这个字段，
所以也无法冒充别人。

结果：`PlayerState`

```json
{ "id": "player-1-48213", "pos": { "x": 12, "y": 8 } }
```

出生点取地图中心；若中心不可通行，服务端会向右扫描第一个可通行格。
整图无可站立格时返回 `-32603`。

**幂等**：同一连接重复调用返回同一个玩家（不会重复占位）。

#### `player.move`

按方向移动一格。

参数：`direction`（字符串，必填），取值 `NORTH` / `SOUTH` / `WEST` / `EAST`。

结果：移动后的 `PlayerState`。

拒绝条件：未加入世界 → `-32001`；方向名非法 → `-32602`；
目标格不可通行 → `-32003`；被模组取消 → `-32004`。

**方向与坐标的关系**（原点左上，x 向右、y 向下）：

| 方向 | 位移 |
|---|---|
| NORTH | y − 1 |
| SOUTH | y + 1 |
| WEST | x − 1 |
| EAST | x + 1 |

这一条两端必须一致。写错不会有任何报错，只会让操作反着来。

## 五、事件表

#### `event.worldChanged`

世界有格子变了。`placeBlock` / `breakBlock` / 模组改世界都会触发。

载荷：

```json
{ "change": { "pos": { "x": 3, "y": 4 }, "block": "AIR", "actor": "player-2" } }
```

广播给**所有**连接，包括触发者自己。触发者会同时收到「RPC 响应」与「事件」，
两者内容相同——前端用事件做统一更新、用响应做即时反馈，不必去重。

#### `event.playerChanged`

预留，当前未实现。玩家进出的广播。

## 六、数据字典

### 方块类型

| 名 | 可通行 | 说明 |
|---|---|---|
| `AIR` | 是 | 空气。不能显式放置 |
| `DIRT` | 是 | 泥土 |
| `STONE` | 是 | 石头 |
| `WATER` | **否** | 水 |
| `WOOD` | **否** | 树干 |

新增方块类型时，`BlockType` 枚举的 `name()` 直接上线，**改名等于改协议**。

### 坐标

二维网格，无高度。原点在**左上角**，x 向右、y 向下。
越界读安全（返回 `AIR`），越界写被拒（返回错误码）。

## 七、连接与生命周期

```
前端                                  后端
 |                                     |
 |--- WebSocket 握手 --------------->  |
 |                                     |
 |--- system.hello ----------------->  |  校验协议版本
 |<-- {protocolVersion, 尺寸...} ----- |
 |                                     |
 |--- world.snapshot --------------->  |  取整张地图
 |<-- {width,height,blocks} ---------- |
 |                                     |
 |--- system.mods ------------------>  |  取模组列表
 |<-- [{id,name,state...}] ----------- |
 |                                     |
 |--- player.join ------------------>  |  分配玩家 id
 |<-- {id,pos} ----------------------- |
 |                                     |
 |            （进入游戏循环）          |
 |--- world.placeBlock ------------->  |
 |<-- WorldChange -------------------- |
 |<-- event.worldChanged (广播) ------ |
```

**一个连接一个玩家身份**。所以「先 join 再 move」必须走同一个连接；
后端 `GameServer.handleStateless()` 每次新建分发器，不能用于有状态的调用序列。

**断开时**：后端摘除该连接的广播目标，并移除其玩家。前端的所有在途请求
立刻失败（不等超时），UI 进入「连接失败」态并提供重试。

### 重启与存档（不改协议）

服务端自 0.2.0 起默认把世界写入本地 `world.json`，重启后自动恢复。**这条能力
完全在协议之外**：没有新增方法、没有新增字段、错误码不变。对客户端而言，重启
前后的差别只有两个可观测现象：

1. 重连后 `system.hello` 与 `world.snapshot` 返回的地形是上次退出时的样子；
2. `player.join` 依旧分配新 id、给出生点——**玩家位置不入档**，前端应把这当成
   「换了个新会话」处理，不要假设沿用旧坐标。

因此客户端不需要为存档做任何适配。若将来要让玩家位置持久化，那才需要动协议
（新增字段或方法），并按第八章流程走三步同步。

## 八、改协议的流程

1. 改本文件；
2. 改 Java 侧 `Methods` / `JsonRpc` / DTO 的 `@SerializedName`；
3. 改 Dart 侧 `protocol.dart` / 模型类的 `fromJson`；
4. 跑 `backend/./gradlew test` 与 `frontend/flutter test`；
5. 跑端到端契约测试确认两端真的对得上：
   ```bash
   cd backend && ./gradlew :server:run          # 一个终端
   cd frontend && TAPMC_E2E=1 flutter test test/e2e_contract_test.dart
   ```

第 5 步不能省。字段名写错时，两端的单元测试会双双通过，只有真实对撞才暴露。

只想快速判断「两端还对不对得上」时，可跑零依赖的冒烟探针（自动起停后端）：

```bash
./scripts/smoke.sh --no-web --expect-protocol 1.0
```

它只覆盖 `system.hello` / `world.snapshot` / `player.join` 三条主链路，
是上面的契约测试的**子集**，不能替代第 5 步。

### instance

#### `instance.list`

列出所有实例。

参数：无。

结果：

```json
[
  {
    "id": "instance-1",
    "name": "我的世界生存",
    "lastPlayed": 1703256000,
    "gameVersion": "1.20.1"
  }
]
```

#### `instance.create`

创建新实例。

参数：

```json
{
  "name": "我的世界生存",
  "templateId": "default" // 可选
}
```

结果：

```json
{
  "id": "instance-1"
}
```

#### `instance.delete`

删除实例。

参数：

```json
{
  "id": "instance-1"
}
```

结果：无

#### `instance.rename`

重命名实例。

参数：

```json
{
  "id": "instance-1",
  "name": "新的实例名"
}
```

结果：无

#### `instance.import`

导入整合包。

参数：

```json
{
  "path": "/path/to/modpack.zip"
}
```

结果：

```json
{
  "id": "instance-1",
  "name": "整合包名"
}
```

### mod

#### `mod.list`

列出实例的模组。

参数：

```json
{
  "instanceId": "instance-1"
}
```

结果：

```json
[
  {
    "id": "fabric-api",
    "name": "Fabric API",
    "version": "0.95.0+1.20.1",
    "loader": "fabric",
    "enabled": true
  }
]
```

#### `mod.enable`

启用模组。

参数：

```json
{
  "instanceId": "instance-1",
  "modId": "fabric-api"
}
```

结果：无

#### `mod.disable`

禁用模组。

参数：

```json
{
  "instanceId": "instance-1",
  "modId": "fabric-api"
}
```

结果：无

#### `mod.detectLoader`

识别加载器类型。

参数：

```json
{
  "instanceId": "instance-1"
}
```

结果：

```json
{
  "loader": "fabric",
  "version": "0.14.21"
}
```

### download

#### `download.start`

开始下载。

参数：

```json
{
  "url": "https://example.com/mod.jar",
  "path": "/path/to/download/mod.jar"
}
```

结果：

```json
{
  "taskId": "download-1"
}
```

#### `download.pause`

暂停下载。

参数：

```json
{
  "taskId": "download-1"
}
```

结果：无

#### `download.delete`

删除下载任务。

参数：

```json
{
  "taskId": "download-1"
}
```

结果：无

### log

#### `log.get`

获取最近的日志。

参数：

```json
{
  "limit": 100,
  "instanceId": "instance-1" // 可选
}
```

结果：

```json
[
  {
    "timestamp": 1703256000,
    "level": "INFO",
    "message": "Server started"
  }
]
```

#### `log.exportCrash`

导出崩溃报告。

参数：

```json
{
  "instanceId": "instance-1"
}
```

结果：

```json
{
  "path": "/path/to/crash-report.txt"
}
```

#### `log.clear`

清空日志。

参数：

```json
{
  "instanceId": "instance-1"
}
```

结果：无

### system extensions

#### `system.health`

检查系统健康状态。

参数：无。

结果：

```json
{
  "status": "healthy",
  "javaVersion": "17.0.9",
  "memoryUsedMB": 512,
  "memoryMaxMB": 2048
}
```

#### `system.restart`

重启服务端。

参数：无。

结果：无

