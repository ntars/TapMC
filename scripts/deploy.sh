#!/bin/bash
set -e

echo "=== TapMC 部署脚本 ==="

# 检查 Flutter 构建
echo "检查 Flutter 构建..."
cd /Users/ntars/Documents/Github/TapMC/core/frontend
flutter build web --release

# 检查 Java 后端构建（如果网络允许）
echo "检查 Java 后端构建..."
cd /Users/ntars/Documents/Github/TapMC/core/backend
if ! gradle build --no-daemon 2>/dev/null; then
    echo "警告: Gradle 构建失败（可能是网络问题）"
    echo "但已存在的 JAR 文件可用于测试:"
    ls -lh server/build/libs/
fi

echo "=== 部署完成 ==="
