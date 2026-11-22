#!/usr/bin/env bash
# 容器 HEALTHCHECK 的本地等价验证：起真实服务端，断言探针在存活/停止时的退出码。
# 用法：scripts/health_verify.sh
# 退出码：0 通过 / 1 断言失败 / 2 缺命令

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/scripts/env.sh"
tapmc_env_init

require() { command -v "$1" >/dev/null 2>&1 || { echo "[health] 缺少命令：$1" >&2; exit 2; }; }
require java
require python3

FAT_JARS=("$REPO_ROOT/core/backend"/server/build/libs/server-*-all.jar)
[[ -f "${FAT_JARS[0]}" ]] || { echo "[health] 未找到 fatJar，先跑 ./gradlew :server:fatJar" >&2; exit 1; }

PORT="$(python3 - <<'PY'
import socket
s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()
PY
)"
LOG="$REPO_ROOT/tmp/health-backend.log"
mkdir -p "$REPO_ROOT/tmp"
: >"$LOG"

java -jar "${FAT_JARS[0]}" --port "$PORT" --host 127.0.0.1 --no-save >>"$LOG" 2>&1 &
PID=$!
trap 'kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true' EXIT

for _ in $(seq 1 50); do
  if java -cp "${FAT_JARS[0]}" cn.ntars.tapmc.server.HealthProbe 127.0.0.1 "$PORT" >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done

java -cp "${FAT_JARS[0]}" cn.ntars.tapmc.server.HealthProbe 127.0.0.1 "$PORT" >/dev/null 2>&1 || {
  echo "[health] 后端未就绪" >&2; tail -20 "$LOG" >&2; exit 1;
}
echo "[health] 运行中探针退出码 0"

kill "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true
trap - EXIT
sleep 0.3

if java -cp "${FAT_JARS[0]}" cn.ntars.tapmc.server.HealthProbe 127.0.0.1 "$PORT" >/dev/null 2>&1; then
  echo "[health] 停止后探针仍返回 0，判定失败" >&2
  exit 1
fi
echo "[health] 停止后探针退出码 1"
echo "[health] 通过"
