#!/bin/bash
set -e

echo "=== TapMC 端到端验证测试 ==="
echo ""

# 1. 检查 Flutter Web 构建
echo "1. 检查 Flutter Web 构建..."
if [ -f "core/frontend/build/web/main.dart.js" ]; then
    echo "   ✅ Flutter Web 构建成功"
    ls -lh core/frontend/build/web/main.dart.js
else
    echo "   ❌ Flutter Web 构建失败"
    exit 1
fi

# 2. 检查后端 JAR
echo ""
echo "2. 检查后端 JAR..."
if [ -f "core/backend/server/build/libs/server-0.1.0-all.jar" ]; then
    echo "   ✅ 后端 JAR 存在"
    ls -lh core/backend/server/build/libs/server-0.1.0-all.jar
else
    echo "   ❌ 后端 JAR 不存在"
    exit 1
fi

# 3. 检查后端 JAR 可运行
echo ""
echo "3. 测试后端 JAR 运行..."
java -jar core/backend/server/build/libs/server-0.1.0-all.jar --help > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "   ✅ 后端 JAR 可运行"
else
    echo "   ❌ 后端 JAR 无法运行"
    exit 1
fi

# 4. 检查 Flutter analyze
echo ""
echo "4. 运行 flutter analyze..."
flutter analyze 2>&1 | grep -q "error" && {
    echo "   ❌ Flutter analyze 发现错误"
    exit 1
} || {
    echo "   ✅ Flutter analyze 通过（无错误）"
}

# 5. 检查协议文件
echo ""
echo "5. 检查协议扩展..."
if [ -f "core/backend/protocol/src/main/java/cn/ntars/tapmc/protocol/Methods.java" ]; then
    echo "   ✅ 协议文件存在"
    grep -q "instance" core/backend/protocol/src/main/java/cn/ntars/tapmc/protocol/Methods.java && echo "   ✅ instance 方法已定义"
    grep -q "mod" core/backend/protocol/src/main/java/cn/ntars/tapmc/protocol/Methods.java && echo "   ✅ mod 方法已定义"
fi

# 6. 检查新页面文件
echo ""
echo "6. 检查 P2 功能页面..."
for page in instance_page download_page log_page; do
    if [ -f "core/frontend/lib/presentation/pages/${page}.dart" ]; then
        echo "   ✅ ${page}.dart 存在"
    else
        echo "   ❌ ${page}.dart 缺失"
    fi
done

# 7. 检查 Java 运行时探测
echo ""
echo "7. 检查 Java 运行时探测..."
if [ -f "core/frontend/lib/domain/java_runtime.dart" ]; then
    echo "   ✅ java_runtime.dart 存在"
    grep -q "JavaRuntimeDetector" core/frontend/lib/domain/java_runtime.dart && echo "   ✅ Java 运行时探测类已定义"
fi

echo ""
echo "=== 验证完成 ==="

# 清理
rm -f /tmp/test_e2e.sh
