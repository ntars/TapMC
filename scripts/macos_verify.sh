#!/usr/bin/env bash
#
# macOS 桌面端运行验证（T03）
#
# 回答一个问题：「flutter build macos --release 出来的那个 .app，双击起来之后
# 到底有没有真的连上后端、真的进了世界？」
#
# 做法：应用把后端地址编译死成 127.0.0.1:8777，而验证时后端要另挑空闲端口
# （不能占着 8777 打扰用户）。于是在 8777 上放一个透明中转探针（relay.dart），
# 把应用的报文原样转给真后端，并把每一条报文记进日志。
# 判定靠日志里出现 JOIN_OK —— 那是 player.join 的真实响应，含玩家 id 与出生点。
#
# 用法：
#   scripts/macos_verify.sh                  # 构建后的 .app 路径按默认取
#   scripts/macos_verify.sh --no-build       # 跳过构建，直接验已有产物
#   scripts/macos_verify.sh --keep           # 结束后不杀进程
#   scripts/macos_verify.sh --app <path>     # 指定 .app 路径
#   scripts/macos_verify.sh --timeout 90     # 等 JOIN_OK 的最长秒数
#
# 退出码：0 通过 / 1 失败 / 2 环境缺失 / 3 端口 8777 被占

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/scripts/env.sh"
tapmc_env_init
BACKEND_DIR="$REPO_ROOT/core/backend"
FRONTEND_DIR="$REPO_ROOT/core/frontend"
RELAY="$REPO_ROOT/scripts/macos_verify/relay.dart"
LOG_DIR="$REPO_ROOT/tmp/macos_verify"
APP_PATH="$FRONTEND_DIR/build/macos/Build/Products/Release/TapMC.app"

DO_BUILD=1
KEEP=0
TIMEOUT=90
RELAY_PORT=8777

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build)  DO_BUILD=0 ;;
    --keep)      KEEP=1 ;;
    --app)       APP_PATH="${2:?--app 需要一个路径}"; shift ;;
    --timeout)   TIMEOUT="${2:?--timeout 需要秒数}"; shift ;;
    -h|--help)   sed -n '/^# macOS 桌面端运行验证/,/^# 退出码/p' "${BASH_SOURCE[0]}" \
                   | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)           echo "未知参数：$1" >&2; exit 2 ;;
  esac
  shift
done

mkdir -p "$LOG_DIR"
BACKEND_LOG="$LOG_DIR/backend.log"
RELAY_LOG="$LOG_DIR/relay.log"
: >"$BACKEND_LOG"
: >"$RELAY_LOG"

PIDS=()
APP_PID=""
cleanup() {
  if [[ "$KEEP" == "1" ]]; then
    echo "[macos] --keep 已开启，子进程保留：${PIDS[*]:-无} app=${APP_PID:-无}"
    return
  fi
  # 退出路径上什么都不许再失败，否则会盖掉真正的退出码。
  [[ -n "$APP_PID" ]] && { kill "$APP_PID" 2>/dev/null || true; wait "$APP_PID" 2>/dev/null || true; }
  for pid in "${PIDS[@]:-}"; do
    [[ -z "$pid" ]] && continue
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT

dump_logs() {
  local file="$1" label="$2"
  echo "----- ${label} 最后 40 行（${file}）-----" >&2
  tail -n 40 "$file" >&2 || true
  echo "----- 日志结束 -----" >&2
}
fail() {
  local message="$1" log="${2:-}" label="${3:-日志}"
  echo "[macos] 失败：$message" >&2
  [[ -n "$log" ]] && dump_logs "$log" "$label"
  exit 1
}
require() {
  command -v "$1" >/dev/null 2>&1 || { echo "[macos] 缺少命令：$1" >&2; exit 2; }
}

require java
require python3
require curl
# dart 优先 PATH 上的；只装 Flutter 时退回其自带的那份。
if ! command -v dart >/dev/null 2>&1; then
  if command -v flutter >/dev/null 2>&1; then
    DART_BIN="$(dirname "$(command -v flutter)")/dart"
    [[ -x "$DART_BIN" ]] && export PATH="$(dirname "$DART_BIN"):$PATH"
  fi
fi
require dart

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
s = socket.socket(); s.settimeout(0.5)
try:
    s.connect((sys.argv[1], int(sys.argv[2])))
except OSError:
    sys.exit(1)
finally:
    s.close()
PY
    then return 0; fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  return 1
}

# ---------------------------------------------------------------- 0. 前置检查
# 8777 是应用的编译期默认地址。被占了就说明有别的 TapMC 后端在跑，
# 这时候验出来的结果可能来自旧进程，直接判失败比给出假阳性好。
if lsof -nP -iTCP:"$RELAY_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "[macos] 端口 ${RELAY_PORT} 已被占用，无法架中转探针：" >&2
  lsof -nP -iTCP:"$RELAY_PORT" -sTCP:LISTEN >&2 || true
  exit 3
fi

# ---------------------------------------------------------------- 1. 构建
if [[ "$DO_BUILD" == "1" ]]; then
  echo "[macos] 构建 flutter build macos --release"
  ( cd "$FRONTEND_DIR" && flutter build macos --release ) >>"$LOG_DIR/build.log" 2>&1 \
    || fail "flutter build macos 失败" "$LOG_DIR/build.log" "构建日志"
fi
[[ -d "$APP_PATH" ]] || fail "未找到 ${APP_PATH}（先跑一次构建）"
APP_BIN="$APP_PATH/Contents/MacOS/$(basename "$APP_PATH" .app)"
[[ -x "$APP_BIN" ]] || fail "未找到可执行文件 ${APP_BIN}"
APP_SIZE="$(du -sh "$APP_PATH" | awk '{print $1}')"
echo "[macos] 产物：${APP_PATH}（${APP_SIZE}）"

# ---------------------------------------------------------------- 2. 起后端
# 注意结尾的 `|| true`：`ls` 找不到文件时返回非零，而 `set -o pipefail` 会让
# 整条管道失败；在 `VAR="$(...)"` 里这会直接触发 `set -e` 静默退出整个脚本
# （刚跑完 `gradlew clean` 时必然发生）。先把「没找到」变成一个可判定的空串。
find_fat_jar() {
  ls -t "$BACKEND_DIR"/server/build/libs/server-*-all.jar 2>/dev/null | head -1 || true
}

FAT_JAR="$(find_fat_jar)"
if [[ -z "$FAT_JAR" ]]; then
  echo "[macos] 未找到 fatJar，先构建（./gradlew :server:fatJar）"
  ( cd "$BACKEND_DIR" && ./gradlew :server:fatJar -q ) >>"$BACKEND_LOG" 2>&1 \
    || fail "构建 fatJar 失败" "$BACKEND_LOG" "构建日志"
  FAT_JAR="$(find_fat_jar)"
  [[ -n "$FAT_JAR" ]] || fail "构建后仍未找到 server-*-all.jar" "$BACKEND_LOG" "构建日志"
fi

PORT="$(pick_port)"
echo "[macos] 起后端：ws://127.0.0.1:${PORT}"
# --no-save：验证要的是「这批代码能不能跑通」，不能受上一轮残留存档影响，
# 也不该在用户的仓库根目录留下 world.json。存档路径单独由 persist_verify.sh 验。
java -jar "$FAT_JAR" --port "$PORT" --host 127.0.0.1 --no-save >>"$BACKEND_LOG" 2>&1 &
BACKEND_PID=$!
PIDS+=("$BACKEND_PID")
wait_for_port 127.0.0.1 "$PORT" 60 || fail "后端 60s 内未监听 ${PORT}" "$BACKEND_LOG" "后端日志"

# ---------------------------------------------------------------- 3. 起中转探针
echo "[macos] 起中转探针：127.0.0.1:${RELAY_PORT} → ${PORT}"
dart "$RELAY" --listen "$RELAY_PORT" --target "$PORT" --log "$RELAY_LOG" \
  --idle "$((TIMEOUT + 30))" >>"$LOG_DIR/relay.stdout" 2>&1 &
RELAY_PID=$!
PIDS+=("$RELAY_PID")
wait_for_port 127.0.0.1 "$RELAY_PORT" 30 || fail "中转探针 30s 内未监听 ${RELAY_PORT}" "$LOG_DIR/relay.stdout" "探针输出"

# ---------------------------------------------------------------- 4. 启动应用
# 直接执行二进制而不是 `open`：`open` 把应用交给 launchd 后就返回，
# 拿不到 pid，也没法在结束时干净收掉——验证脚本必须自己握住进程。
echo "[macos] 启动应用：${APP_BIN}"
"$APP_BIN" >>"$LOG_DIR/app.log" 2>&1 &
APP_PID=$!

# ---------------------------------------------------------------- 5. 等 JOIN_OK
echo "[macos] 等待 player.join 落地（上限 ${TIMEOUT}s）"
elapsed=0
joined=0
while (( elapsed < TIMEOUT )); do
  if grep -q 'JOIN_OK' "$RELAY_LOG" 2>/dev/null; then joined=1; break; fi
  # 应用启动就崩的话不必等满超时。
  if ! kill -0 "$APP_PID" 2>/dev/null; then
    fail "应用启动后已退出（pid ${APP_PID} 不存在）" "$LOG_DIR/app.log" "应用日志"
  fi
  sleep 1
  elapsed=$((elapsed + 1))
done

if [[ "$joined" != "1" ]]; then
  fail "${TIMEOUT}s 内未见 player.join 成功（日志无 JOIN_OK）" "$RELAY_LOG" "探针日志"
fi

# ---------------------------------------------------------------- 6. 断言汇总
echo "[macos] 报文轨迹："
grep -E 'CLIENT_CONNECTED|BACKEND_CONNECTED|req id=|hello |snapshot |JOIN_OK' "$RELAY_LOG" | sed 's/^/  /'

grep -q 'hello protocolVersion=' "$RELAY_LOG" || fail "未见 system.hello 响应" "$RELAY_LOG" "探针日志"
grep -q 'snapshot 24x16 blocks=384' "$RELAY_LOG" || fail "world.snapshot 不是 24x16/384 格" "$RELAY_LOG" "探针日志"

JOIN_LINE="$(grep 'JOIN_OK' "$RELAY_LOG" | head -1)"
echo "[macos] join 证据：${JOIN_LINE}"

# 应用必须还活着：连上就崩等于没跑通。
kill -0 "$APP_PID" 2>/dev/null || fail "join 成功后应用进程已退出" "$LOG_DIR/app.log" "应用日志"

echo "[macos] 通过  app=${APP_PATH}  port=${PORT}  join=${JOIN_LINE#*JOIN_OK }"
