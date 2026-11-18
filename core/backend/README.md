# TapMC 后端

Java 侧实现游戏本体逻辑与模组生态。**一个可独立运行的进程**，通过 WebSocket
以 JSON-RPC 2.0 对外提供服务；Flutter 前端是它的客户端。

## 模块划分

依赖方向**单向向下**，不允许反向引用。这条规则由 `settings.gradle.kts` 的注释与
模块的 `build.gradle.kts` 共同约束，评审时以「上层可以依赖下层、下层不得感知上层」为准。

```
server  ──→ core ──→ mod
   │          │
   └──────────┴──→ protocol
```

| 模块 | 职责 | 不该出现的东西 |
|---|---|---|
| `protocol` | 线协议：报文封装、错误码、方法名常量、DTO | 任何业务判断 |
| `mod` | 模组 SPI：`TapMcMod` / `ModContext` / 事件 | 对 core、server 的依赖 |
| `core` | 游戏本体：世界网格、玩家、规则判定、模组加载 | JSON、网络、线程 |
| `server` | 网关：WebSocket、RPC 分发、广播 | 任何游戏规则 |

**为什么这样切**：

- `protocol` 单独成模块，是为了让「改协议」这件事有明确落点。它同时被 `mod` 与
  `server` 依赖，但两者都不依赖对方。
- `mod` 不含 core，是为了让第三方写模组时只需一个 jar 的依赖，不必把整个服务端
  编译进来。这也让「模组只能通过 `ModContext` 操作世界」成为物理约束而非口头约定。
- `core` 零网络依赖，因此可以不起端口就跑完整逻辑测试（见 `GameEngineTest`）。
- `server` 只做翻译，所以换传输层（进程内直调、命令行）时不必改游戏逻辑。

## 快速开始

```bash
cd backend
./gradlew build                # 编译 + 全部测试
./gradlew :server:run          # 启动，默认 127.0.0.1:8777
./gradlew :server:fatJar       # 打可执行 jar
java -jar server/build/libs/server-0.1.0-all.jar --port 8777
```

参数：

| 参数 | 默认 | 说明 |
|---|---|---|
| `--port <n>` | 8777 | 监听端口 |
| `--host <ip>` | 127.0.0.1 | 绑定地址。默认只绑本机，联机需显式传 `0.0.0.0` |

默认只绑 `127.0.0.1` 是刻意的：这是个本地游戏服务，不该默认对局域网开放。

## 环境要求

| 项 | 要求 | 说明 |
|---|---|---|
| JDK | 21+ | 字节码目标固定为 21，用 25 编译也能产出 21 兼容的 class |
| Gradle | 用仓库自带 wrapper | 无需本机安装 |

`gradle.properties` 里有代理配置（`systemProp.https.proxyHost`）。换到无代理网络时
把四行注释掉即可——Java 不读 `HTTPS_PROXY` 环境变量，所以必须显式写在这里。

## 写一个模组

```java
public final class MyMod implements TapMcMod {

    @Override
    public ModMetadata metadata() {
        return new SimpleMetadata("cn.example.mymod", "我的模组", "1.0.0");
    }

    @Override
    public void onLoad(ModContext ctx) throws Exception {
        // 禁止在水上放方块
        ctx.onBlockPlace(event -> {
            if ("WATER".equals(ctx.getBlock(event.getX(), event.getY()))) {
                event.cancel("不能在水中放置方块");
            }
        });

        // 玩家移动后把踩过的格子铺成石头
        ctx.onPlayerMove(event -> {
            ctx.setBlock(event.getToX(), event.getToY(), "STONE");
        });
    }
}
```

注册方式（骨架阶段）：在 `GameServer` 构造时传入列表。

```java
new GameServer(24, 16, List.of(new MyMod()));
```

**当前不支持从 jar 动态加载**。动态加载需要类加载器隔离与安全沙箱，属于第二阶段，
先把接口跑通。接口的变化规则：加方法请用 `default` 方法，不要改已有签名。

### 模组的能力边界

模组**拿不到**世界对象的引用，只能通过 `ModContext`：

| 能做 | 不能做 |
|---|---|
| 读任意格方块（`getBlock`） | 持有 `WorldGrid` 引用 |
| 改任意格方块（`setBlock`，会广播） | 自己起线程改世界 |
| 取消放置 / 破坏 / 移动 | 拦截「已加入世界的玩家」之外的东西 |
| 读世界尺寸 | 直接访问网络或文件 |

这个限制的意义：服务端的并发与边界校验只需守 `ModContext` 一处，不必担心模组
绕过规则。

### 失败与去重

| 情况 | 处理 |
|---|---|
| `metadata()` 抛异常 | 记为 `FAILED`，id 显示为 `<unknown>` |
| `onLoad()` 抛异常 | 记为 `FAILED` 并保留原因，**不影响其他模组** |
| 同 id 重复注册 | 第一个生效，后续记为 `DISABLED` |

单个坏模组拖垮全服是最容易引发用户流失的问题，所以失败隔离是硬要求。

## 端口与协议

协议全文见 [../docs/protocol.md](../docs/protocol.md)。这里只列最容易出错的三点：

1. **一个连接一个玩家身份**。`player.join` 与后续 `player.move` 必须走同一个
   `RpcDispatcher`。`GameServer.handleStateless()` 每次新建分发器，只适合无状态
   方法（hello / snapshot / getBlock），误用会得到 `-32001 NOT_JOINED`。
2. **null 字段不序列化**。成功响应不含 `error`，事件不含 `id`。前端据此判断类型，
   不需要判空。
3. **坐标原点在左上**，x 向右、y 向下。`NORTH` 是 y−1。

## 测试

```bash
./gradlew test                    # 全部
./gradlew :core:test              # 只跑游戏逻辑
./gradlew :server:test            # 只跑 RPC 与模组生态
```

共 61 个用例，分四组：

| 测试类 | 覆盖 |
|---|---|
| `WorldGridTest` | 越界读写语义、行优先导出、不可变性 |
| `GameEngineTest` | 移动与方块规则、模组拦截、广播时机 |
| `RpcDispatcherTest` | 报文形状、错误码、字段名（**锁住线上格式**） |
| `ModLifecycleTest` | 加载失败隔离、去重、模组能力 |

`RpcDispatcherTest` 的作用需要单独说明：它断言的是 JSON 里的**字段名**。
Dart 侧的 `fromJson` 依赖这些名字，改坏一个，这里的用例就该红。

## 已知边界

| 边界 | 现状 |
|---|---|
| 世界是二维网格 | 无高度、无区块、无光照。骨架阶段够用，加高度会牵动协议与渲染 |
| 玩家只有坐标 | 无生命值、背包、朝向 |
| 单线程串行处理 | `onMessage` 里对引擎加锁，并发度低但正确性明确 |
| 无持久化 | 重启即重置地图 |
| 无鉴权 | 任何人连上即分配玩家 id |
| 模组不能动态加载 | 只能在代码里注册 |

这些不是遗漏，是骨架阶段的取舍。任何一条要动，先改 `docs/protocol.md` 再动代码。
