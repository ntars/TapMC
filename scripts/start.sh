#!/bin/bash

echo "=== 启动 TapMC ==="
cd /Users/ntars/Documents/Github/TapMC

# 启动 Java 后端
echo "启动 Java 后端..."
cd /Users/ntars/Documents/Github/TapMC/core/backend
java -jar server/build/libs/server-0.1.0-all.jar &
JAVA_PID=$!
echo "Java 后端 PID: $JAVA_PID"

# 等待后端启动
sleep 3

# 启动 Flutter Web 服务器
echo "启动 Flutter Web 服务器..."
cd /Users/ntars/Documents/Github/TapMC/core/frontend
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080 &
FLUTTER_PID=$!
echo "Flutter Web PID: $FLUTTER_PID"

echo "TapMC 已启动"
echo "访问 http://localhost:8080 查看应用"

# 等待用户中断
wait
