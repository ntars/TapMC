# TapMC 观测与模组隔离

## 结构化日志格式

```
{
  "timestamp": "2026-11-24T15:30:00Z",
  "level": "INFO|WARN|ERROR",
  "message": "日志内容",
  "sessionId": "player-xxx-12345",
  "method": "world.snapshot"
}
```

## 崩溃包

访问 `/debug/bundle` 获取当前服务的崩溃信息。

### 崩溃包内容
```
tapmc-bundle-<timestamp>.zip
├─ meta.json           版本信息
├─ server.log          最近 500 行日志
├─ config.json         脱敏配置
└─ world-summary.json  世界状态概览
```

## 模组隔离

### 模组失败处理
1. 单个模组加载失败不影响主进程
2. 失败的模组会被标记为 `disabled`
3. 错误日志包含模组名称和错误详情

### 模组兼容矩阵
| 版本 | 模组 API 兼容性 |
|---|---|
| MAJOR 变更 | 不兼容 |
| MINOR 变更 | 向下兼容 |
| PATCH 变更 | 完全兼容 |

## 日志查询

### 按级别过滤
```bash
grep "ERROR" logs/server.log
```

### 按sessionId 查询
```bash
grep "sessionId: player-xxx" logs/server.log
```

## 告警端点

| 端点 | 说明 |
|---|---|
| `/health` | 健康检查（HTTP 200 表示正常） |
| `/debug/bundle` | 获取崩溃包 |
| `/log/exportCrash` | 导出最近的错误日志 |

## 性能指标

| 指标 | 单位 | 阈值 |
|---|---|---|
| 内存使用 | MB | < 4096 |
| GC 次数/分钟 | 次 | < 10 |
| 连接数 | 个 | < 1000 |
| 响应时间 | ms | < 500 |
