# TapMC 发布工程

## 版本语义

| 位 | 触发 |
|---|---|
| MAJOR | 协议不兼容（method 删除、参数语义变化）、存档格式不兼容 |
| MINOR | 新 method、新玩法、新模组 API |
| PATCH | 修复、性能、文案 |

协议版本与产品版本同号。

## 制品

```
dist/
├─ tapmc-server-0.1.0-all.jar
├─ tapmc-0.1.0-client-web.zip（Web 端）
└─ SHA256SUMS
```

## 镜像要求

| 项 | 要求 |
|---|---|
| 基础镜像 | `eclipse-temurin:21-jre` |
| 运行用户 | 非 root |
| 健康检查 | TCP 探活 |
| 数据卷 | `/data/world`、`/data/mods` |

## 升级与回滚

```
1. 停服
2. 备份（tools/backup.sh）
3. 换 jar / 换镜像 tag
4. 起服，读日志确认 schemaVersion 迁移成功
5. 进服验证一条主流程
```

## 发布检查单

- [ ] VERSION 已改，check-version 通过
- [ ] flutter analyze && flutter test 全绿
- [ ] check-protocol 退出 0
- [ ] 存档迁移：三份历史样例各恢复一次
- [ ] 压测 8 客户端 10 分钟无错误
- [ ] 备份 + 恢复演练各一次

## 当前版本

- 产品版本：0.1.0
- 协议版本：2.0
- 构建日期：2026-11-24

## 制品位置

- 后端 JAR：`core/backend/server/build/libs/server-0.1.0-all.jar`
- 前端 Web：`core/frontend/build/web/`
