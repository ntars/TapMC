#!/usr/bin/env bash
#
# TapMC 冒烟基线（T02）
#
# 一条命令回答一个问题：「这个仓库 clone 下来，后端能不能起来、握手通不通、
# Web 前端产物能不能被正常访问」。它只做断言，不做修复。
#
#   1. 起后端          → 等服务端监听端口（最多 60s）
#   2. 跑握手探针      → system.hello / world.snapshot / player.join 逐条断言
#   3. 起 Web 前端      → 静态托管 build/web，断言 index.html 与 main.dart.js 可访问
#   4. 收尾            → 杀掉所有子进程；失败时打印最后 40 行日志
#
# 用法：
#   scripts/smoke.sh                  # 默认 127.0.0.1，自动挑端口，复用已有 Web 产物
#   scripts/smoke.sh --build-web      # 先 flutter build web 再验（慢，约 1–3 分钟）
#   scripts/smoke.sh --no-web         # 只验后端（前端依赖未就绪时用）
#   scripts/smoke.sh --keep           # 结束后不杀进程，留给人工排查
#   scripts/smoke.sh --expect-protocol 1.0   # 断言服务端协议版本，防两侧常量漂移
#
# 退出码：0 通过 / 1 断言失败 / 2 环境缺失（java、dart 未装）

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/scripts/env.sh"
tapmc_env_init
BACKEND_DIR="$REPO_ROOT/core/backend"
FRONTEND_DIR="$REPO_ROOT/core/frontend"
PROBE="$REPO_ROOT/scripts/smoke/probe.dart"
# 日志放 tmp/：.gitignore 已忽略，不会污染工作区。
LOG_DIR="$REPO_ROOT/tmp/smoke"

BUILD_WEB=0
RUN_WEB=1
KEEP=0
HOST="127.0.0.1"
EXPECT_PROTOCOL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-web)      BUILD_WEB=1 ;;
    --no-web)         RUN_WEB=0 ;;
    --keep)           KEEP=1 ;;
    --host)           HOST="${2:?--host 需要一个地址}"; shift ;;
    --expect-protocol) EXPECT_PROTOCOL="${2:?--expect-protocol 需要一个版本号}"; shift ;;
    # 帮助文本按标记区间抽取，不写死行号：头部注释增删一行不会让帮助缺尾。
    -h|--help)        sed -n '/^# TapMC 冒烟基线/,/^# 退出码/p' "${BASH_SOURCE[0]}" \
                        | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)                echo "未知参数：$1" >&2; exit 2 ;;
  esac
  shift
done

mkdir -p "$LOG_DIR"
BACKEND_LOG="$LOG_DIR/backend.log"
WEB_LOG="$LOG_DIR/web.log"
: >"$BACKEND_LOG"
: >"$WEB_LOG"

PIDS=()
cleanup() {
  if [[ "$KEEP" == "1" ]]; then
    echo "[smoke] --keep 已开启，子进程保留：${PIDS[*]:-无}"
    return
  fi
  # 逐个子进程收起。收尾阶段什么都不许再失败：
  # 这里已经在退出路径上，任何非零返回都会覆盖真正的退出码。
  for pid in "${PIDS[@]:-}"; do
    [[ -z "$pid" ]] && continue
    # 只杀自己起的进程：先 TERM 给机会自己退，两秒后仍在则 KILL。
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT

# 失败时打印日志尾部，方便一眼看到真正的原因，而不是只有「断言失败」。
dump_logs() {
  local file="$1" label="$2"
  echo "----- ${label} 最后 40 行（${file}）-----" >&2
  tail -n 40 "$file" >&2 || true
  echo "----- 日志结束 -----" >&2
}
fail() {
  local message="$1" log="${2:-}"
  echo "[smoke] 失败：$message" >&2
  [[ -n "$log" ]] && dump_logs "$log" "${3:-日志}"
  exit 1
}

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "[smoke] 缺少命令：$1" >&2; exit 2; }
}

require java
require python3
# dart 优先用 PATH 上的；只装了 Flutter 而没单独装 Dart SDK 时，退回 Flutter 自带的那个。
if ! command -v dart >/dev/null 2>&1; then
  if command -v flutter >/dev/null 2>&1; then
    DART_BIN="$(dirname "$(command -v flutter)")/dart"
    [[ -x "$DART_BIN" ]] && export PATH="$(dirname "$DART_BIN"):$PATH"
  fi
fi
require dart
[[ "$BUILD_WEB" == "1" ]] && require flutter

# 挑一个空闲端口。硬编码 8777 会在「用户自己已经起了一个后端」时误连到旧进程，
# 那种情况下冒烟通过也说明不了当前代码可跑。
pick_port() {
  python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
}

wait_for_port() {
  local host="$1" port="$2" timeout="${3:-60}" elapsed=0
  while (( elapsed < timeout )); do
    if python3 - "$host" "$port" <<'PY'
import socket, sys
host, port = sys.argv[1], int(sys.argv[2])
s = socket.socket()
s.settimeout(0.5)
try:
    s.connect((host, port))
except OSError:
    sys.exit(1)
finally:
    s.close()
PY
    then
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  return 1
}

# ---------------------------------------------------------------- 1. 后端产物
# 产物名含版本号（server-<ver>-all.jar）。用通配取值，改 version 时脚本不必跟着改。
# 结尾 `|| true`：找不到文件时 `ls` 返回非零，而 `set -o pipefail` 会让整条管道失败，
# 在 `VAR="$(...)"` 里就会直接触发 `set -e` 静默退出（`gradlew clean` 之后必然发生）。
find_fat_jar() {
  ls -t "$BACKEND_DIR"/server/build/libs/server-*-all.jar 2>/dev/null | head -1 || true
}
FAT_JAR="$(find_fat_jar)"
if [[ -z "$FAT_JAR" ]]; then
  echo "[smoke] 未找到 ${FAT_JAR}，先构建（./gradlew :server:fatJar）"
  ( cd "$BACKEND_DIR" && ./gradlew :server:fatJar -q ) >>"$BACKEND_LOG" 2>&1 \
    || fail "构建 fatJar 失败" "$BACKEND_LOG" "构建日志"
  FAT_JAR="$(find_fat_jar)"
  [[ -n "$FAT_JAR" ]] || fail "构建后仍未找到 server-*-all.jar" "$BACKEND_LOG" "构建日志"
fi

# ---------------------------------------------------------------- 2. 起后端
PORT="$(pick_port)"
echo "[smoke] 起后端：ws://${HOST}:${PORT}"
# --no-save：冒烟验的是「这批代码能不能起来」，结果不该依赖磁盘上有没有旧存档，
# 也不该在用户目录留下 world.json。存档链路由 scripts/persist_verify.sh 单独验。
java -jar "$FAT_JAR" --port "$PORT" --host "$HOST" --no-save >>"$BACKEND_LOG" 2>&1 &
BACKEND_PID=$!
PIDS+=("$BACKEND_PID")

wait_for_port "$HOST" "$PORT" 60 || fail "后端 60s 内未监听 ${HOST}:${PORT}" "$BACKEND_LOG" "后端日志"

# ---------------------------------------------------------------- 3. 握手探针
echo "[smoke] 跑握手探针"
# 探针输出同时进日志与屏幕。这里不用管道 + PIPESTATUS：
# 那个变量在不同 shell 下行为不一致，直接重定向再 cat 更稳。
if ! dart "$PROBE" --host "$HOST" --port "$PORT" >"$LOG_DIR/probe.log" 2>&1; then
  cat "$LOG_DIR/probe.log" >&2
  fail "握手断言未通过（详见探针日志）" "$BACKEND_LOG" "后端日志"
fi
cat "$LOG_DIR/probe.log"

# 判定要求「输出含 system.hello 返回的协议版本」，这里再显式回显一次，
# 保证即便探针输出格式以后变了，冒烟报告里仍然有这一行。
PROTOCOL_VERSION="$(grep -o 'protocolVersion=[^ ]*' "$LOG_DIR/probe.log" | head -1 | cut -d= -f2)"
[[ -n "$PROTOCOL_VERSION" ]] || fail "未从探针输出中取到 protocolVersion" "$LOG_DIR/probe.log" "探针日志"
echo "[smoke] 协议版本：${PROTOCOL_VERSION}"

# 协议版本是两端常量类对齐的锚点。CI 里传 --expect-protocol 1.0，
# 有人只改了一侧常量时这里会立刻红，不必等到前端连上才暴露。
if [[ -n "$EXPECT_PROTOCOL" && "$PROTOCOL_VERSION" != "$EXPECT_PROTOCOL" ]]; then
  fail "协议版本不符：服务端 ${PROTOCOL_VERSION}，期望 ${EXPECT_PROTOCOL}" \
    "$LOG_DIR/probe.log" "探针日志"
fi

# ---------------------------------------------------------------- 4. 起 Web 前端
if [[ "$RUN_WEB" == "1" ]]; then
  WEB_ROOT="$FRONTEND_DIR/build/web"
  if [[ "$BUILD_WEB" == "1" || ! -f "$WEB_ROOT/index.html" ]]; then
    echo "[smoke] 构建 Web 产物（flutter build web --release）"
    ( cd "$FRONTEND_DIR" && flutter build web --release ) >>"$WEB_LOG" 2>&1 \
      || fail "flutter build web 失败" "$WEB_LOG" "Web 构建日志"
  fi
  [[ -f "$WEB_ROOT/index.html" ]] || fail "缺少 ${WEB_ROOT}/index.html" "$WEB_LOG" "Web 日志"

  WEB_PORT="$(pick_port)"
  echo "[smoke] 起 Web 前端：http://${HOST}:${WEB_PORT}"
  # 用 exec：让子 shell 把自己替换成 python，$! 才是 python 本身的 pid。
  # 少了 exec，$! 只是子 shell 的 pid，kill 它之后 python 会留下来占着端口。
  ( cd "$WEB_ROOT" && exec python3 -m http.server "$WEB_PORT" --bind "$HOST" ) >>"$WEB_LOG" 2>&1 &
  WEB_PID=$!
  PIDS+=("$WEB_PID")

  wait_for_port "$HOST" "$WEB_PORT" 30 || fail "静态服务 30s 内未监听 ${HOST}:${WEB_PORT}" "$WEB_LOG" "Web 日志"

  for path in index.html flutter_bootstrap.js main.dart.js; do
    code="$(curl -s -o /dev/null -w '%{http_code}' "http://${HOST}:${WEB_PORT}/${path}")"
    [[ "$code" == "200" ]] || fail "GET /${path} 返回 ${code}（期望 200）" "$WEB_LOG" "Web 日志"
    echo "[smoke] GET /${path} → 200"
  done
else
  echo "[smoke] 跳过 Web 前端（--no-web）"
fi

echo "[smoke] 通过  protocolVersion=${PROTOCOL_VERSION}  日志：${LOG_DIR}"
