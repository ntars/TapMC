# 鸿蒙（HarmonyOS / OpenHarmony）端说明

Flutter 官方当前**不**支持鸿蒙。要在鸿蒙上运行本前端，必须使用社区维护的
Flutter 分叉把 `ohos/` 工程目录生成出来。本文只写「怎么接」与「已知边界」，
不假装它已经能像其他六端那样开箱即用。

## 一、为什么 `ohos/` 目录不在仓库里

`ohos/` 由鸿蒙分叉的 `flutter create` 生成，它的模板文件与分叉版本强绑定
（`oh-package.json5`、`hvigorfile.ts`、`build-profile.json5` 的字段随版本变化）。
把它固化进仓库会有两个后果：

1. 换一个分叉版本，仓库里的 `ohos/` 就是过期模板，构建报错但原因不直观；
2. 官方 Flutter 看到 `ohos/` 不认识，某些 `flutter` 命令会报「无法识别的平台目录」。

因此约定：**`ohos/` 由开发者本地生成，不入版本库**（见 `frontend/.gitignore`）。

## 二、版本门槛（这一条决定能否编译）

| 项 | 要求 | 说明 |
|---|---|---|
| 鸿蒙 Flutter 分叉 | `3.41.10-ohos-1.0.0` 或更高 | 这是本仓库代码的验证基线 |
| OpenHarmony SDK | API 18+ | 分叉的最低要求 |
| DevEco Studio | 5.1.0+ | 提供 hvigor / ohpm / node / hdc |
| Dart SDK 下限 | 3.8.0 | 已写在 `pubspec.yaml` 的 `environment.sdk` |

**为什么卡在 3.41 而不是官方最新的 3.50**：分叉的标签里 3.41.10 之后只有
`3.44.9+ohos-1.0.0-beta` 与 `3.47.7+ohos-0.0.1-canary`，前者 beta、后者 canary，
都不适合作为「必须能编译」的基线。选稳定即可用的最高一档，是本项目的取舍。

同理，`pubspec.yaml` 里没有引入 `material_ui`（Flutter 3.47+ 才有的新包），
继续用 SDK 内置的 `package:flutter/material.dart`。相关理由写在该文件与
`analysis_options.yaml` 的注释里。

## 三、接入步骤

### 1. 取分叉

```bash
# 官方维护仓库（国内访问稳定）
git clone https://gitee.com/openharmony-sig/flutter_flutter.git
cd flutter_flutter
git fetch --tags
git checkout 3.41.10-ohos-1.0.0

# 清掉旧缓存：缓存里绑定的是另一套 Dart SDK 与引擎产物，
# 不清会出现 "Wrong full snapshot version" 这类难查的错误
rm -rf bin/cache
```

把分叉的 `bin` 放到 `PATH` 最前面，**不要**和官方 Flutter 混用同一个终端会话。

### 2. 配 DevEco 工具链

```bash
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home
export PATH=/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin:$PATH
export PATH=/Applications/DevEco-Studio.app/Contents/tools/node/bin:$PATH
export PATH=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin:$PATH
```

`flutter doctor` 应能看到 `HarmonyOS toolchain` 与 `OHOS devices` 两项。

### 3. 生成 `ohos/` 并构建

```bash
cd frontend

# 只生成鸿蒙目录，不动其他六端
flutter create --platforms ohos .

flutter pub get
flutter build hap --release
```

`flutter devices` 能看到鸿蒙设备或模拟器后，也可以直接 `flutter run -d <device-id>`。

## 四、端口与网络

鸿蒙应用访问宿主机上的后端，地址不能写 `127.0.0.1`（那指向设备自己）。
联调时用开发机的局域网 IP：

```bash
flutter run -d <device-id> --dart-define=TAPMC_SERVER_HOST=192.168.1.10
```

模拟器与宿主机在同一虚拟网络时，按其网关地址填。这个参数在
`lib/core/app_config.dart` 里读取，优先级高于平台默认值。

## 五、已知边界

| 边界 | 现状 | 影响 |
|---|---|---|
| 分叉版本滞后官方 | 最高稳定 3.41.10，官方已 3.50 | 不能用 3.47+ 的新 API（含 `material_ui`） |
| 三方插件可用性 | 分叉已适配 110+ 常用插件 | 冷门插件可能需要自己写 ArkTS 侧桥接 |
| 平台判断写法 | 用 `defaultTargetPlatform`，**不能**用 `Platform.isOhos` | 后者写进代码会在非鸿蒙端编译失败 |
| CI 覆盖 | 无鸿蒙 CI | 鸿蒙端构建需本地验证，不能依赖流水线 |

本骨架只用了一个三方依赖 `web_socket_channel`，它在分叉的适配清单内，
因此当前不存在需要自己桥接的插件。

## 六、验收标准

鸿蒙端算「接好了」的最低条件，缺一不可：

1. `flutter build hap --release` 产出 hap 包；
2. 模拟器或真机上能启动到主界面；
3. 能连上后端并完成 `system.hello` → `world.snapshot` → `player.join`；
4. 轻点格子能放置方块、长按能破坏，且服务端广播能被收到。

第 3、4 条与其他六端共用同一套 Dart 代码，因此只要第 1、2 条通过，
后两条大概率同时成立——若不通，说明分叉的网络或渲染实现有差异，需单独排查。
