# 分层许可说明

> 本文件是人类可读的分层路由表。`LICENSE` 是 Apache-2.0 全文，`LICENSE-MIT` 是 MIT 全文。
> GitHub 只按 `LICENSE` 识别仓库主许可，因此显示为 Apache-2.0；MIT 覆盖的部分见下表。

本仓库按目录分层授权，只使用两种宽松许可证：**Apache License 2.0** 与 **MIT**。
许可全文见 [`LICENSE`](./LICENSE)（Apache-2.0）与 [`LICENSE-MIT`](./LICENSE-MIT)（MIT）。

Copyright (c) 2026 星玖工作室 Ntarstudio

---

## 零、默认归属（先看这条）

**下表未列出的、由本项目编写的文件，一律适用根 [`LICENSE`](./LICENSE)，即 Apache-2.0。**

这条兜底规则是必须的。只列目录而不写默认值，克隆者面对 `core/` 下的
Gradle 包装器、`pubspec.yaml`、`.gitignore` 就无从判断归属，法律上等于没有授权。
需要相反结果的路径，必须显式写进下表——**不存在「靠猜」的路径**。

第三方依赖不适用本兜底条款，见第五节。

## 一、分层映射

| 路径 | 许可 | 说明 |
|---|---|---|
| `core/backend/protocol/` | **Apache-2.0** | 前后端通信契约：JSON-RPC 2.0 消息定义 |
| `core/backend/core/` | **Apache-2.0** | 世界状态、规则判定、模组钩子 |
| `core/backend/mod/` | **Apache-2.0** | 模组加载与 API |
| `core/backend/server/` | **Apache-2.0** | 服务进程与 WebSocket 端点 |
| `core/frontend/` | **MIT** | Flutter 多端界面（七端） |
| `core/docs/` | **MIT** | 架构与协议文档 |
| `core/backend/` 下的 Gradle 包装器（`gradlew` `gradlew.bat` `gradle/` `build.gradle.kts` `settings.gradle.kts` `gradle.properties`） | **Apache-2.0** | 属后端构建的一部分，随其所在层 |
| 根级 `README.md` `README_EN.md` `CHANGELOG.md` `CONTRIBUTING.md` `CODE_OF_CONDUCT.md` `SECURITY.md` `.gitignore` | **MIT** | 说明文档与仓库配置 |
| 品牌名称、Logo、界面设计 | **保留所有权利** | 不随代码许可授予 |

## 二、为什么协议层必须 Apache-2.0

游戏骨架的价值完全取决于**别人愿不愿意基于它做模组和客户端**。协议层是被实现、
被适配、被第三方工具对接的那一层，因此：

1. **明示专利授权**（第 3 条）：让别人放心按协议实现，不用担心专利纠纷；
2. **NOTICE 保留义务**（第 4 条 d 项）：归属声明不会丢。

Apache-2.0 同样宽松：可商用、可闭源、可修改、可再许可，**没有传染性**。
第三方模组可以闭源，第三方客户端也可以闭源——这是骨架能长起来的前提。

## 三、关于「为什么不用 AGPL」

AGPL 会直接杀死模组生态：没有一个模组作者愿意让自己的模组被传染成 AGPL。
而模组生态恰好是这个项目唯一的价值来源。

## 四、商标

「TapMC」「星玖工作室」「Ntarstudio」等名称、Logo 与界面设计归星玖工作室所有。
代码许可只授予**代码**权利，不授予商标权。

## 五、第三方组件

后端：Java-WebSocket 1.6.0（MIT）、slf4j 2.0.17（MIT）、Gson 2.15.0（Apache-2.0）。
前端：web_socket_channel 3.0.3（BSD-3-Clause）、Flutter SDK（BSD-3-Clause）。
逐项披露见 [`NOTICE`](./NOTICE)。**没有任何 GPL / LGPL / AGPL / MPL 组件。**

## 六、禁止引入 copyleft 组件

宽松许可可以吸收宽松许可，但**不能反向吸收 copyleft**。
一个 GPL / LGPL / AGPL / MPL 组件一旦引入，整个项目将被要求以该 copyleft 许可分发。
Minecraft 相关库尤其要留意：部分社区库使用 GPL 或自定义限制条款，引入前必须核对。
