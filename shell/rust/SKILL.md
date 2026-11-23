---
name: tapmc-rust-shell
description: TapMC 原生 Rust 启动器壳的开发、构建、冒烟与发布验证流程。
---

# TapMC Rust Shell

`shell/rust` 是 TapMC 的原生桌面启动器壳。它使用 `eframe/egui` 绘制 UI，
不使用 WebView、Tauri 或 JavaScript；游戏规则仍由 `core/backend` 的 Java 核心负责，
两侧只通过 `core/docs/protocol.md` 定义的 JSON-RPC 2.0 over WebSocket 通信。

## 构建

```bash
source "$HOME/.cargo/env"
cd shell/rust
cargo fmt --all --check
cargo clippy --all-targets -- -D warnings
cargo test
cargo build --release
```

## 全链路冒烟

`tapmc-shell --smoke` 不创建窗口，使用与 GUI 相同的 `LauncherSession` 执行
`hello -> snapshot -> mods -> join`，随后验证一次移动和一次方块操作。

```bash
PORT="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
java -jar dist/server/server-0.1.0-all.jar --port "$PORT" --no-save &
TAPMC_SMOKE_ENDPOINT="ws://127.0.0.1:$PORT/" shell/rust/target/release/tapmc-shell --smoke
```

成功时输出 `SMOKE_OK`，包含玩家 id、世界尺寸、移动前后坐标和方块变化。

## 配置与数据

- 配置：系统用户配置目录下的 `TapMC/launcher.json`
- 存档：系统用户数据目录下的 `TapMC/world.json`
- 模组：系统用户数据目录下的 `TapMC/mods/`
- Java 日志：系统临时目录中的 `tapmc-shell-java.log`

启动器不会把存档、模组或日志写进仓库工作目录。
