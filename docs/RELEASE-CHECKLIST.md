# TapMC 发布检查单

## 准备阶段
- [ ] VERSION 文件已更新（MAJOR.MINOR.PATCH）
- [ ] 协议版本同步到 `protocol.dart` 和 `Methods.java`
- [ ] changelog.md 已更新

## 代码阶段
- [ ] `flutter analyze` 全绿（无 error）
- [ ] `flutter test` 全绿
- [ ] `gradlew build` 全绿

## 协议阶段
- [ ] check-protocol 脚本退出 0（两端协议对齐）
- [ ] TAPMC_E2E=1 契约测试通过

## 存档阶段
- [ ] 三份不同版本的历史存档可恢复
- [ ] 存档迁移脚本测试通过

## 构建阶段
- [ ] Docker 镜像构建成功
- [ ] `docker-compose up` 健康检查通过
- [ ] 重启后数据仍在

## 压测阶段
- [ ] 8 客户端并发 10 分钟无掉线
- [ ] 压测期间状态一致性断言通过

## 备份恢复阶段
- [ ] backup.sh 脚本执行成功
- [ ] restore.sh 脚本执行成功

## 文档阶段
- [ ] README.md 已更新
- [ ] PUBLISH.md 已完成
- [ ] OPS.md 已完成
- [ ] OBSERVABILITY.md 已完成

## 发布阶段
- [ ] tag 已打（vMAJOR.MINOR.PATCH）
- [ ] 发布说明包含「协议变化」和「存档兼容性」
- [ ] GitHub Release 已创建

## 后续任务
- [ ] CI 构建通过
- [ ] 镜像已推送到仓库
- [ ] 公告已发布
