# TapMC 运维手册

## 缺陷分级

| 级别 | 定义 | 响应 | 修复 |
|---|---|---|
| S0 | 存档损坏、无法进服、数据丢失 | 立即 | 当天补丁 |
| S1 | 多人不同步、频繁掉线 | 24 小时 | 下个 PATCH |
| S2 | 单功能异常、模组加载失败 | 3 天 | 下个 MINOR |
| S3 | 性能、文案 | 下个版本 | 不承诺 |

## 报障取证

```
/debug/bundle → tapmc-bundle-<ts>.zip
├─ meta.json       版本、协议版本、schemaVersion、JVM、OS
├─ server.log      最近 500 行（结构化）
├─ config.json     脱敏后的配置
└─ world-summary.json  网格尺寸、实体数、模组列表
```

## 兼容矩阵

| 维度 | 承诺 |
|---|---|
| Java | 21 |
| Flutter/Dart | Dart ≥ 3.8 |
| 客户端平台 | Web |
| 模组 API | 与产品同 MINOR 兼容 |
| 存档 | 向前迁移（旧→新） |

## 开服流程

### 1. 准备环境
```bash
# 安装 Java 21
brew install openjdk@21

# 创建数据目录
mkdir -p /data/world /data/mods
```

### 2. 启动服务端
```bash
# 方式一：直接运行 JAR
java -jar tapmc-server-0.1.0-all.jar

# 方式二：使用 Docker
docker run -p 8777:8777 \
  -v /data/world:/data/world \
  -v /data/mods:/data/mods \
  tapmc:latest
```

### 3. 验证服务
```bash
# 检查端口
curl http://localhost:8777/health

# 查看日志
tail -f logs/server.log
```

## 备份与恢复

### 备份
```bash
# 备份存档
tar -czf backup-$(date +%Y%m%d).tar.gz /data/world
```

### 恢复
```bash
# 停服
curl -X POST http://localhost:8777/system/restart

# 恢复数据
tar -xzf backup-<date>.tar.gz -C /
```

## 日志与监控

### 结构化日志
- 所有 log 都包含 `timestamp`、`level`、`message`
- 错误日志包含 `sessionId` 和 `method`

### 崩溃包
访问 `/debug/bundle` 获取崩溃信息。

## 性能调优

### JVM 参数
```bash
java -Xms2g -Xmx4g -jar tapmc-server-0.1.0-all.jar
```

### 并发限制
- WebSocket 消息大小上限：64 KB
- 单客户端 QPS 限制：100

## 告警规则

| 指标 | 阈值 | 动作 |
|---|---|---|
| 内存使用率 | > 85% | 告警 |
| GC 次数/分钟 | > 10 | 告警 |
| 连接数 | > 1000 | 告警 |
| 错误率 | > 1% | 告警 |
