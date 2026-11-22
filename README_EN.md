[简体中文](README.md) | [English](README_EN.md)

# TapMC

**A moddable multiplayer sandbox game skeleton: a Flutter front end on seven platforms plus a Java server, coupled only by one JSON-RPC 2.0 contract.**

![Status](https://img.shields.io/badge/status-skeleton-8957e5?style=flat-square)
[![Version](https://img.shields.io/badge/version-0.1.0-fb8500.svg?style=flat-square)](#)
[![GitHub license](https://img.shields.io/github/license/ntars/TapMC?style=flat-square)](./LICENSE)
[![Backend](https://img.shields.io/badge/backend-Java%2021-ED8B00.svg?style=flat-square&logo=openjdk&logoColor=white)](./core/backend)
[![Frontend](https://img.shields.io/badge/frontend-Flutter%203.32-02569B.svg?style=flat-square&logo=flutter&logoColor=white)](./core/frontend)
[![Tests](https://img.shields.io/badge/tests-82%20backend%2B12%20frontend-2ea44f.svg?style=flat-square)](#)

---

## 1. Name and Positioning

**Name**: TapMC. `Tap` for touch input, `MC` for the sandbox game genre.

**One-line positioning**: a multiplayer sandbox game skeleton built on exactly two stacks — Flutter for the whole front end, Java for the whole back end, separated by one contract you can read in logs.

**Repository description**: `可模组化的多人沙盒游戏骨架：Flutter 七端前端 + Java 服务端，JSON-RPC 2.0 over WebSocket | A moddable multiplayer sandbox game skeleton: Flutter front end, Java server, JSON-RPC 2.0 over WebSocket.`

**Topics** (20, English only): `sandbox-game`, `voxel`, `multiplayer`, `multiplayer-game`, `game-server`, `game-engine`, `modding`, `mod-loader`, `plugin-system`, `flutter`, `dart`, `java`, `json-rpc`, `websocket`, `cross-platform`, `desktop-game`, `mobile-game`, `harmonyos`, `gradle`, `open-source`

| Item | Value |
|---|---|
| Version | 0.1.0 |
| Status | Skeleton stage: the full path works and both sides pass tests; no release yet |
| Repository | <https://github.com/ntars/TapMC> |
| License | Apache-2.0 / MIT (layered by directory) |

---

## 2. Overview

### 2.1 Background

A sandbox game's client and server are in tension by nature: rules must be authoritative on the server, or multiplayer becomes everyone computing their own world; but input must respond instantly on the client, or every click waits a round trip. Most projects drift into writing the rules twice and then pay for two sources of truth indefinitely.

### 2.2 The problem

**Draw one verifiable boundary between rules and presentation** — and make that boundary reusable by third-party mods, not just the official client.

### 2.3 Approach

The back end is the single source of truth; the front end only renders and collects input. World state, rule checks and mod hooks all live on the Java side. Flutter receives "what to draw now" and makes no rule decisions. The only coupling surface is [`core/docs/protocol.md`](./core/docs/protocol.md).

### 2.4 Suitable for

- Teams that need a runnable, extendable multiplayer skeleton rather than a finished game;
- Validating the "Flutter front end + JVM server" combination for games;
- A minimal reference implementation of a mod SPI (compile-time isolation, explicit event ordering).

### 2.5 Not suitable for

- Players expecting a finished game: today it has a 24×16 grid, five block types, no saves, no auth;
- Projects needing a 3D world, chunk loading, lighting or pathfinding — 3D touches protocol, rendering and pathfinding at once and sits last on the roadmap;
- Public multiplayer: single-process serial handling, no accounts, no anti-cheat.

### 2.6 Strengths and limitations

| Strength | Evidence |
|---|---|
| Contract first | The protocol document is the single source; both Dart and Java constant classes derive from it |
| Network-free core | The `core` module has no JSON, network or threads, so the whole game logic runs in unit tests without a port (22 cases) |
| Mod isolation at compile time | Mods receive `ModContext`, never `WorldGrid`, so rules cannot be bypassed |
| No third stack | Only Flutter and Java; one build chain and one debug chain each |

| Limitation | Scope | Mitigation |
|---|---|---|
| No persistence | ~~Restarting resets the map~~ | Fixed in 0.2.0: `world.json` is written on shutdown and restored on restart |
| No authentication | Anyone connected gets a player id; suitable only for localhost or trusted LAN | Binds `127.0.0.1` by default; add a gateway before exposing publicly |
| Single-threaded serial handling | Concurrent connections limited by one core | Correctness first at skeleton stage; scaling needs a session queue in `server` |
| Mods cannot hot-load | New mods require recompiling and restarting | Roadmap item 2: isolated class loaders in `ModLoader` |
| Two-dimensional world | No height, no chunks, no lighting | Roadmap item 4, the largest blast radius, deliberately last |

---

## 3. Core Features

### 3.1 World and actions

| Feature | Trigger | Result |
|---|---|---|
| Fetch world | Front end calls `world.snapshot` on first paint | Returns a row-major `width × height` block array |
| Read one cell | `world.getBlock` during rendering or interaction | Returns the block type; out-of-bounds returns `AIR` instead of an error |
| Place a block | Player acts on an empty cell, `world.placeBlock` | Returns `WorldChange` and broadcasts `event.worldChanged` to all connections |
| Break a block | Player acts on a breakable block, `world.breakBlock` | Same as above; `WATER` and `WOOD` cannot be broken |
| Move | Arrow keys or on-screen pad, `player.move` | Returns new coordinates; out-of-bounds returns `-32002` |

### 3.2 Session and mods

| Feature | Trigger | Result |
|---|---|---|
| Handshake | `system.hello` after connecting | Server name, version, protocol version, world size, block types |
| Join world | `player.join` | Assigns a player identity; player methods before joining return `-32001` |
| List mods | `system.mods` | Mod id, name, version, state and failure reason in load order |

### 3.3 Seven front-end targets

Android, iOS, Windows, macOS, Linux, Web and HarmonyOS share one business code base; platform differences live in build configuration and window shells.

---

## 4. Core Characteristics

### 4.1 Contract first: one protocol, two derivations

The protocol file is the single source of truth; both side's constant classes derive from it, and all three must move together. The payoff shows up during integration: a misplaced field surfaces as a protocol version mismatch at handshake instead of an occasional blank screen.

### 4.2 A core with no network dependency

The `core` module contains no JSON, network or thread code. The whole game logic therefore runs in unit tests without opening a port — the 22 cases in `GameEngineTest` run without opening a port.

### 4.3 Mod isolation as a compile-time constraint

Third-party mods depend only on the `mod` module and receive `ModContext`, not `WorldGrid`. Bypassing rules does not compile.

### 4.4 One-way layering

`server → core → mod`, with `protocol` shared by `server` and `mod`. When a layer fails, the search space is that layer and everything below it.

### 4.5 Single-process delivery

The back end produces an executable jar (`./gradlew :server:fatJar`) with no container or external middleware; the front end uses `flutter build` for each target.

---

## 5. Design Details and Engineering Trade-offs

| Decision | Rationale | Rejected alternative |
|---|---|---|
| JSON-RPC 2.0 over WebSocket | Bidirectional push, readable text, standard error codes | gRPC (needs a proxy in browsers), REST polling (latency or wasted traffic), custom binary (unreadable logs), in-process FFI (conflicts with independent deployment) |
| A two-dimensional grid | Adding height changes protocol, rendering and pathfinding together; get the path working first | 3D voxels: last on the roadmap |
| One connection, one identity | Identity lives in `RpcDispatcher`, so `handleStateless()` fails loudly instead of silently crossing players | A single global player: no multiplayer |
| No client-side rule prediction | Mods can veto any action, so local results can be overruled and wasted | Client prediction: revisit as confirm-then-rollback once the path is stable |
| No `material_ui` | It requires Flutter ≥ 3.47, while the HarmonyOS community fork tops out at 3.41.10-ohos | Following upstream: loses the HarmonyOS target |
| Mods cannot reach `WorldGrid` | Turns "mods cannot bypass rules" into a compile-time constraint | Exposing the world object: rules become decorative |

---

## 6. Technology Stack and Dependencies

| Layer | Runtime / tool | Version constraint |
|---|---|---|
| Back end | JDK | 21+ |
| Back-end build | Gradle Wrapper | Bundled, no local install needed |
| Back-end WebSocket | Java-WebSocket | 1.6.0 |
| Back-end logging | slf4j-api / slf4j-simple | 2.0.17 |
| Front end | Flutter | 3.32+ (3.41.x recommended for HarmonyOS) |
| Front-end transport | `web_socket_channel` | Pure Dart, no native code |
| Front-end build | Android SDK / Xcode | Only for the corresponding targets |

Full dependency list and licenses: [NOTICE](./NOTICE).

---

## 7. Installation and Deployment

### 7.1 Requirements

| Item | Requirement | Purpose |
|---|---|---|
| JDK | 21+ | Back-end build and run |
| Flutter | 3.32+ | Front-end build |
| Android SDK | cmdline-tools + platform 34+ | Android target only |
| Xcode | Full install + CocoaPods | iOS / macOS targets only |

### 7.2 Install and verify

```bash
git clone https://github.com/ntars/TapMC.git
cd TapMC/core/backend && ./gradlew build      # compile and run all tests
cd ../frontend && flutter pub get && flutter test
```

If both commands pass, the environment is ready.

### 7.3 Deploy

```bash
cd core/backend && ./gradlew :server:fatJar
java -jar server/build/libs/server-0.1.0-all.jar --port 8777
```

The server listens on `127.0.0.1:8777` by default. Front-end artefacts come from `flutter build <platform>` and are distributed the usual way for each target.

### 7.4 Upgrade and uninstall

No state at skeleton stage: upgrading means replacing the binary or installer; uninstalling means deleting the directory. Nothing is written to system locations.

### 7.5 Dynamic mod loading

Drop a jar implementing the `cn.ntars.tapmc.mod.TapMcMod` SPI into `./mods/` and start the server (the bundled example lives in `examples/mods/`; copy it over to activate it):

```bash
java -jar dist/server/server-0.1.0-all.jar --mods ./mods --no-save
# try the example: cp examples/mods/guard-mod.jar ./mods/
```

Each jar gets its own child `URLClassLoader`, so bundled dependencies do not collide; unloading closes the loader and releases the file handle.
`system.mods` lists both built-in and dynamically loaded mods with `ACTIVE` / `FAILED` / `DISABLED` states.
Verified: after copying `examples/mods/guard-mod.jar` into `./mods/`, `system.mods` listed `test.guard`, placing `WOOD` returned `-32004` (cancelled by mod), and removing the jar disabled the cancellation. The example is not in `./mods/` by default so standard acceptance is unaffected.
Mods run in-process without a security sandbox; only load trusted jars.

---


### 7.6 Containerisation

The repository includes a `Dockerfile` and `docker-compose.yml`. The server listens on `0.0.0.0:8777` inside the container with save and mod directories mounted; nginx serves the Web build on port `8080`.

```bash
./scripts/build_release.sh          # produce dist/web for compose to mount
docker compose up -d --build
curl http://127.0.0.1:8080/         # Web artifact
# the server container runs a health check every 30 s against 127.0.0.1:8777
docker compose ps                   # server should become healthy
```

Without Docker, verify the health probe locally:

```bash
env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u http_proxy -u https_proxy -u all_proxy \
  bash -lc 'source scripts/env.sh; tapmc_env_init; ./scripts/health_verify.sh'
```

The script starts a real server and asserts that the probe exits 0 while it is alive and 1 after it stops.
The health check only proves the port is listening; it does not replace handshake or contract tests.

---

## 8. Quick Start

Two commands, two terminals, a picture within ten minutes.

```bash
# Terminal 1: start the server
cd core/backend && ./gradlew :server:run

# Terminal 2: start the front end
cd core/frontend && flutter run -d chrome
```

Expected result: a 24×16 grid in the browser with terrain, arrow-key movement, block breaking and placing. If the backend stops briefly, the front end reconnects automatically (500ms/1s/2s backoff, three attempts), replays hello → snapshot → mods → join, and restores the world. After three failures it shows an error page with a Retry button. For a static Web deployment, pass `?server=ws://host:port` to select the backend.

For a device on the same network, bind the server to `0.0.0.0` and point the front end at the host:

```bash
cd core/backend && ./gradlew :server:run --args="--host 0.0.0.0"
cd core/frontend && flutter run --dart-define=TAPMC_SERVER_HOST=192.168.1.10
```

### 8.1 One-command self-check

When unsure whether the environment is healthy, run the smoke script: it starts the backend, runs the handshake, serves the Web build statically, then cleans up every process it spawned.

```bash
./scripts/smoke.sh
```

Expected key lines:

```text
[probe] system.hello OK  protocolVersion=1.0  world=24x16  blockTypes=5
[probe] player.join OK  id=player-1-75416  pos=(12,8)
[smoke] 通过  protocolVersion=1.0  日志：.../tmp/smoke
```

| Flag | Effect |
|---|---|
| `--no-web` | Backend only, skip the Web artifact check |
| `--build-web` | Run `flutter build web --release` first (1–3 minutes on a cold build) |
| `--expect-protocol 1.0` | Assert the server protocol version, catching a one-sided constant drift |
| `--keep` | Leave processes running for manual inspection |

Exit codes: `0` pass, `1` assertion failed, `2` missing command. On failure the last 40 lines of the relevant log are printed; full logs live in `tmp/smoke/`.

The script needs only `java` and `dart`: the probe at `scripts/smoke/probe.dart` imports nothing but `dart:io`, so no third-party package and no `pub get` is required.

### 8.2 Release build and full acceptance

```bash
./scripts/build_release.sh          # dist/server + dist/web + dist/SHA256SUMS
./scripts/verify_release.sh         # six-step acceptance, including real e2e contract
```

The acceptance script runs 82 backend unit tests, 12 front-end unit tests, a release build, protocol smoke, three persistence scenarios, and 8 real WebSocket contract tests. Use `./scripts/verify_release.sh --skip-e2e` when a live backend contract run is not available. See [RELEASE.md](./RELEASE.md) for deployment and checksum verification.

---

## 9. Configuration

| Key | Type | Default | Required | Range | Purpose |
|---|---|---|---|---|---|
| `--host` | string | `127.0.0.1` | no | valid IPv4 / hostname | Server listen address |
| `--port` | integer | `8777` | no | 1–65535 | Server listen port |
| `--save-file` | string | `world.json` | no | writable path | World save file |
| `--autosave` | integer | `60` | no | 0–86400 seconds | Periodic save interval; `0` disables autosave |
| `--no-save` | boolean | off | no | — | Run entirely in memory |
| `TAPMC_SERVER_HOST` | string (compile-time define) | `127.0.0.1` | no | valid IPv4 / hostname | Server address used by the front end, injected via `--dart-define` |

Precedence: command-line arguments over defaults. The front end has only the compile-time define and reads no configuration file.

Hot reload: protocol and method table support hot-reload debugging on the Flutter side; server configuration changes require a restart.

Proxy note: Java and Gradle do not read `HTTPS_PROXY`. `scripts/env.sh` translates a reachable proxy into JVM flags at runtime; no dead proxy address is committed to `gradle.properties`.

---

## 10. API and Module Reference

JSON-RPC 2.0 over WebSocket, 10 methods and events in total.

| Method | Direction | Parameters | Result |
|---|---|---|---|
| `system.hello` | request | none | Server name, version, protocol version, world size, block types |
| `system.mods` | request | none | Mod array (id / name / version / state / reason) |
| `world.snapshot` | request | none | `{width, height, blocks[]}`, row-major |
| `world.getBlock` | request | `x`, `y` | Block type name; out-of-bounds returns `AIR` |
| `world.placeBlock` | request | `x`, `y`, `block` | `WorldChange` |
| `world.breakBlock` | request | `x`, `y` | `WorldChange` |
| `player.join` | request | none | Player identity |
| `player.move` | request | `direction` | New coordinates |
| `event.worldChanged` | push | `change` | Block change broadcast |
| `event.playerChanged` | push | player state | Player state broadcast |

Error codes:

| Code | Name | Meaning |
|---|---|---|
| -32700 | PARSE_ERROR | Payload is not valid JSON |
| -32600 | INVALID_REQUEST | Missing required fields such as `method` |
| -32601 | METHOD_NOT_FOUND | Method name not registered |
| -32602 | INVALID_PARAMS | Missing or invalid parameter values |
| -32603 | INTERNAL_ERROR | Uncaught server exception |
| -32001 | NOT_JOINED | Player method called before joining |
| -32002 | OUT_OF_BOUNDS | Coordinates outside the world |
| -32003 | BLOCK_REJECTED | Cell cannot be placed on or broken |
| -32004 | CANCELLED_BY_MOD | Vetoed by a mod |

`error.message` is always a displayable Chinese sentence covering "what happened + what to do next". Full payload shapes and rejection order: [`core/docs/protocol.md`](./core/docs/protocol.md).

---

## 11. Repository Layout

```text
TapMC/
├── LICENSE / LICENSE-MIT / LICENSING.md / NOTICE
├── scripts/
│   ├── smoke.sh                 One-command smoke: backend + handshake probe + Web artifact check
│   ├── macos_verify.sh          One-command macOS desktop check: build + launch + assert player.join
│   ├── persist_verify.sh        One-command persistence check: shutdown save + restart + SIGKILL autosave
│   ├── build_release.sh         One-command release build: server jar + Web artifacts + SHA256SUMS
│   ├── verify_release.sh        One-command acceptance: build + tests + smoke + persistence + contract
│   ├── env.sh                   Build environment bootstrap: proxy detection and tool paths
│   ├── smoke/probe.dart         Handshake probe (zero dependencies, `dart:io` only)
│   └── macos_verify/
│       ├── relay.dart           Transparent relay probe: forwards and logs every JSON-RPC frame
│       └── reject_server.dart   Failure-path probe: closes right after handshake to prove the app survives
└── core/
    ├── backend/                 Java server process (four modules)
    │   ├── protocol/            Wire protocol: envelopes, error codes, method names, DTOs
    │   ├── mod/                 Mod SPI: TapMcMod, ModContext, events
    │   ├── core/                Game itself: world, players, rules, mod loading
    │   └── server/              Gateway: WebSocket, RPC dispatch, broadcast
    ├── frontend/                Flutter app (seven targets)
    │   ├── lib/domain/          Pure data models and constants
    │   ├── lib/data/            RPC client, transport, repositories
    │   └── lib/presentation/    UI and state
    └── docs/
        ├── architecture.md      Layering and trade-offs
        └── protocol.md          Front-end/back-end contract
```

---

## 12. Performance

Measured build figures (Apple Silicon, network through a proxy):

| Scenario | Result | Condition |
|---|---|---|
| Web build | 13.2 s | `flutter build web --release` |
| Android build | 12.9 s | After removing the `ndkVersion` declaration, `flutter build apk --debug` |
| First Android build | 24 min | Mostly downloading NDK r28c (about 2.8 GB) |
| Back-end tests | 84 cases passing | `./gradlew clean build --no-daemon` |
| Front-end tests | 14 passed / 8 skipped | `flutter test`; includes two narrow-screen layout assertions; skipped tests need a live backend |

Measured runtime baseline (Apple Silicon arm64 / macOS 27, `./scripts/bench.sh`, 200 single-connection requests + 10 clients × 40 requests):

| Metric | Result | Condition |
|---|---|---|
| Single-connection round trip P50 | 0.224 ms | `world.getBlock`, 200 requests after warm-up |
| Single-connection round trip P95 | 0.402 ms | Same |
| 10-client error rate | 0.00% (400/400 completed) | 40 requests per client; every fifth is `world.snapshot` |
| Server RSS | 85.0 MB average, 86.3 MB peak | Sampled every 0.2 s, 26 samples |

The benchmark uses a temporary port and `--no-save`, so it never touches a player save. Full machine-readable output: `tmp/bench/result.json`. These numbers are a local baseline, not an SLA.

Narrow-screen layout is verified by widget tests: at 375×667 portrait the control pane sits below the world; at 667×375 landscape it moves into a 240 px right-hand scroll pane. In both sizes the direction pad does not overlap the grid and no RenderFlex overflow occurs. Run: `cd core/frontend && flutter test test/home_page_layout_test.dart`. These are size/geometry assertions, not pixel-perfect goldens.

---

## 13. Security and Privacy

- **No authentication**: connecting assigns a player id; there are no accounts and no tokens.
- **Localhost by default**: the server binds `127.0.0.1` and does not advertise on the LAN; device testing requires explicit `--host 0.0.0.0`, after which anyone on the subnet can connect.
- **No persistence**: nothing is written to disk, no player data is stored, and exiting leaves no trace.
- **No telemetry**: no statistics are reported and no external endpoints are called.
- **Mod boundary**: mods run in-process on the server and are trusted code, not a sandbox. Evaluate before loading untrusted mods.

Reporting channel: [SECURITY.md](./SECURITY.md).

---

## 14. Compatibility

| Platform | Build | Run | Note |
|---|---|---|---|
| Web | pass | pass | `flutter build web --release` exited 0 in 11.5 s this round; smoke test checks static artifacts |
| Android | historical pass | unverified | Earlier `flutter build apk --debug` produced a 142 MB APK; this round the Android Gradle distribution URL was unreachable, so it could not be re-verified |
| macOS | historical pass | historical pass | Earlier `flutter build macos --release` produced a 40.6 MB `.app` and a live handshake; this round only Command Line Tools are installed and `flutter build macos` reports `Xcode not installed` |
| iOS | unverified | unverified | `flutter build ios --release` reports `Xcode not installed`; ATS is configured for local networking |
| Linux | unverified | unverified | `flutter build linux --release` reports "only supported on Linux hosts"; this host is macOS |
| Windows | unverified | unverified | `flutter build windows --release` reports "only supported on Windows hosts"; this host is macOS |
| HarmonyOS | unverified | unverified | Requires the HarmonyOS Flutter SDK; see [`core/frontend/docs/harmonyos.md`](./core/frontend/docs/harmonyos.md); not installed here |

"Unverified" means code and platform configuration are in place and only the build environment is missing; it is not reported as passing. This round used `cd core/frontend && flutter build <platform> --release` for every target; runtime requirements: JDK 21+, Flutter 3.32+.

The macOS build and run can be reproduced with one command (starts the backend, sets up a relay probe, launches the `.app`, and asserts that `player.join` landed):

```bash
./scripts/macos_verify.sh              # includes the build, ~1 min
./scripts/macos_verify.sh --no-build   # reuse existing artifact, ~15 s
```

Expected output (key lines):

```text
[macos] 产物：.../Release/TapMC.app（39M）
JOIN_OK JOIN_RESULT id=player-1-78125 pos={x: 12, y: 8}
[macos] 通过  ...
```

Exit codes: `0` pass, `1` assertion failed, `2` missing command, `3` port 8777 already taken (a result obtained then could come from a stale process, so it fails fast).

---

## 15. Known Issues and Limitations

### 15.1 Known issues

| Issue | Scope | Workaround | Tracking |
|---|---|---|---|
| No saves | Restart resets the map | none | Roadmap item 1 |
| No auto-reconnect | After a drop only manual Retry works; world and player slot are not restored | Click Retry on the error page to rerun the full first-load sequence | Planned for 0.2.x |
| No authentication | Localhost and trusted LAN only | Do not expose the port | Roadmap item 2 (designed with hot-loading) |
| Single-threaded handling | Latency rises under concurrency | Cap connections | Unscheduled |


### 15.2 Unimplemented features

| Feature | Why not yet | Status |
|---|---|---|
| Save files | Save format and restore semantics must be decided first | Planned |

| 3D world | Touches protocol, rendering and pathfinding together | Planned (last) |
| Health, inventory, facing | Coordinates were enough at skeleton stage | Unscheduled |
| Multi-client verification | Requires several build environments | Unscheduled |

---

## 16. Changelog

Follows Keep a Changelog and semantic versioning; full history in [CHANGELOG.md](./CHANGELOG.md).

### [0.1.0] - 2026-11-18

- Added: four Java back-end modules (protocol / mod / core / server), 61 tests passing.
- Added: three Flutter layers (domain / data / presentation), 10 unit tests and 8 end-to-end contract tests passing.
- Added: JSON-RPC 2.0 over WebSocket with 10 methods and events.
- Added: seven-target build configuration and Android NDK declaration trimmed (build time 24 min → 12.9 s).

---

## 17. Roadmap

Ordered so that no existing contract breaks. All items are non-commitments.

| Item | Target version | Status |
|---|---|---|
| Persistence (interface in `core`, I/O in `server`) | 0.2.0 | Planned |
| Mod hot-loading (isolated class loaders + directory scan) | 0.3.0 | Implemented, see 7.5; security sandbox still absent |
| Build verification on all targets (Xcode / Windows / Linux / HarmonyOS) | 0.2.x | Planned |
| 3D world (`z` in the protocol, isometric rendering, pathfinding) | 1.0.0 | Planned |

---

## 18. Contributing

- Environment: JDK 21+, Flutter 3.32+, see chapter 7.
- Branches: `main` stays buildable; work happens on `feat/` or `fix/` branches, merged only after `./gradlew build` and `flutter test` pass.
- Commit messages: `<type>(<scope>): <subject>`, with type from `feat` / `fix` / `docs` / `refactor` / `test` / `chore`.
- Protocol changes: edit `core/docs/protocol.md` first, then both constant classes, then add contract tests.
- Full process in [CONTRIBUTING.md](./CONTRIBUTING.md); community expectations in [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md).

---

## 19. Copyright and License

Copyright © 2026 星玖工作室 Ntarstudio. Licensed under Apache-2.0 / MIT.

Licensed by directory, using only Apache License 2.0 and MIT:

| Path | License |
|---|---|
| `core/backend/protocol/` `core/backend/core/` `core/backend/mod/` `core/backend/server/` | Apache-2.0 |
| `core/frontend/` `core/docs/` | MIT |
| Brand name, logo, interface design | All rights reserved |

Full text in [LICENSE](./LICENSE) (Apache-2.0) and [LICENSE-MIT](./LICENSE-MIT) (MIT); routing in [LICENSING.md](./LICENSING.md). Neither license is copyleft: third-party mods and clients may stay closed source.

---

## 20. NOTICE and Open-Source Compliance

Third-party summary:

| Component | Version | License | Purpose |
|---|---|---|---|
| Java-WebSocket | 1.6.0 | MIT | WebSocket server implementation |
| slf4j-api / slf4j-simple | 2.0.17 | MIT | Logging facade and binding |
| `web_socket_channel` | constrained by the Flutter SDK | BSD-3-Clause | Front-end WebSocket transport |

Full inventory, including the Flutter and Gradle dependency trees, is in [NOTICE](./NOTICE).
