# 参与贡献

本文件说明 TapMC 的开发环境、分支模型、提交规范与 PR 要求。

## 1. 开发环境

| 项 | 版本 | 用途 |
|---|---|---|
| JDK | 21+ | 后端编译与运行 |
| Flutter | 3.32+ | 前端构建 |
| Android SDK | cmdline-tools + platform 34+ | 仅 Android 端 |
| Xcode | 完整安装 + CocoaPods | 仅 iOS / macOS 端 |

首次准备：

```bash
git clone https://github.com/ntars/TapMC.git
cd TapMC/core/backend && ./gradlew build
cd ../frontend && flutter pub get && flutter test
```

两条命令都通过后再开始改动。

## 2. 分支模型

- `main` 始终可构建、可运行，不做长期开发分支。
- 功能用 `feat/<主题>`，缺陷用 `fix/<主题>`，文档用 `docs/<主题>`。
- 合并前必须通过 `./gradlew build` 与 `flutter test`，禁止跳过测试。

## 3. 提交信息

格式：`<type>(<scope>): <subject>`

| type | 用途 |
|---|---|
| `feat` | 新功能 |
| `fix` | 缺陷修复 |
| `docs` | 文档 |
| `refactor` | 不改变行为的重构 |
| `test` | 测试 |
| `chore` | 构建、依赖、杂项 |

`scope` 取模块名：`protocol`、`mod`、`core`、`server`、`frontend`、`docs`。

## 4. 改协议的流程

1. 先改 `core/docs/protocol.md`，写清参数、结果、错误码与拒绝顺序。
2. 同步 `core/backend/protocol/.../Methods.java` 与 `core/frontend/lib/domain/protocol.dart`。
3. 补契约测试：后端 `RpcDispatcherTest`，前端 `e2e_contract_test.dart`。
4. 三处不一致时以文档为准，代码向文档靠。

## 5. PR 自查清单

- [ ] 提交信息符合第 3 节格式
- [ ] `./gradlew build` 通过
- [ ] `flutter test` 通过
- [ ] 新增行为有对应测试
- [ ] 涉及协议的改动已同步文档与两侧常量类
- [ ] 涉及依赖的改动已同步 `NOTICE`

## 6. 行为准则

参与本项目即表示同意 [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)。
