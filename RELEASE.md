# TapMC 发布与验收

这份文档只回答一件事：**拿到这个仓库后，怎样产出一个可分发版本，并证明它能用。**

## 1. 发布产物

执行：

```bash
./scripts/build_release.sh
```

输出在 `dist/`：

| 路径 | 用途 |
|---|---|
| `dist/server/server-<version>-all.jar` | 可执行服务端，含全部 Java 依赖，`java -jar` 直接运行 |
| `dist/server/server-<version>.tar/.zip` | Gradle 标准启动包，便于传统部署 |
| `dist/web/` | Flutter Web release 静态站点，可直接放到 nginx / Caddy / 静态托管 |
| `dist/SHA256SUMS` | 全部文件 SHA-256 清单，用于分发后核对完整性 |

`dist/` 是本地产物，已 gitignore；仓库不提交二进制。

## 2. 启动与访问

后端默认只监听本机，并把世界存到当前目录的 `world.json`：

```bash
java -jar dist/server/server-0.1.0-all.jar
```

局域网联机时绑定地址并指定存档：

```bash
java -jar dist/server/server-0.1.0-all.jar \
  --host 0.0.0.0 --port 8777 \
  --save-file /var/lib/tapmc/world.json --autosave 60
```

Web 静态站点放到任意静态服务器后，用查询参数指定后端：

```text
https://game.example.com/?server=wss://game.example.com/ws
```

`?server=` 必须是 `ws://` 或 `wss://` 地址；未指定时按平台默认连 `127.0.0.1:8777`。生产环境应在反向代理处开启 TLS 与鉴权，当前服务端本身没有账号体系。

## 3. 一键验收

```bash
./scripts/verify_release.sh
```

逐项含义：

| 步骤 | 命令实质 | 通过标准 |
|---|---|---|
| 1 | `./gradlew clean build` | 84 个后端用例全过 |
| 2 | `flutter analyze && flutter test` | 无静态问题；14 个单测通过，8 个 e2e 默认跳过 |
| 3 | `./scripts/build_release.sh` | 服务端 jar / 启动包 / Web 产物 / 校验清单齐全 |
| 4 | `./scripts/smoke.sh --expect-protocol 1.0` | hello、snapshot、join 三条主链路通过 |
| 5 | `./scripts/persist_verify.sh` | 退出写盘；重启 384 格逐格一致；SIGKILL 后自动存档有效 |
| 6 | `TAPMC_E2E=1 flutter test test/e2e_contract_test.dart` | 8 项前后端契约全过（真实 WebSocket 后端） |

退出码：`0` 全部通过、`1` 某项失败、`2` 缺命令。脚本只使用临时端口与 `tmp/` 目录，不覆盖用户自己的 `world.json`。

补充验收（不属于六步主链，按需执行）：

| 目标 | 命令 | 当前结果 |
|---|---|---|
| 运行期基准 | `./scripts/bench.sh` | P50 0.224 ms / P95 0.402 ms；10 并发错误率 0%；RSS 峰值 86.3 MB |
| 模组动态加载 | `cp examples/mods/guard-mod.jar ./mods/ && java -jar dist/server/server-*-all.jar --mods ./mods` | 测试守卫 jar 生效；`system.mods` 列出 `test.guard`；放置 WOOD 返回 -32004（验完移走示例） |
| 健康检查 | `./scripts/health_verify.sh` | 运行中探针退 0，停止后退 1；docker build 需有 Docker 宿主机 |
| 窄屏适配 | `cd core/frontend && flutter test test/home_page_layout_test.dart` | 375×667 与 667×375 无溢出、方向键不压网格 |

如需跳过最后一项真实后端契约测试：

```bash
./scripts/verify_release.sh --skip-e2e
```

## 4. 校验发布包

```bash
cd dist
shasum -c SHA256SUMS
```

任一文件校验失败，说明复制、下载或构建过程被破坏，不要发布该包。

## 5. 已知边界

- 服务端无鉴权，默认只绑本机；公网部署必须加网关。
- 玩家位置不入档，重启后重新 `player.join` 返回出生点。
- 当前验收覆盖 Web 与服务端；Android 蓝叠与 Windows Parallels 虚拟机已补做构建和运行实测，其他平台环境差异见 `README.md` 第十四章。
- macOS 桌面端实跑需本机有 Xcode，可用 `./scripts/macos_verify.sh` 单独验证。
