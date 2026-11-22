#!/usr/bin/env bash
#
# TapMC 运行期性能基准（T05）
#
# 起真实后端进程，测三项可复现数字：
#   1. 单连接顺序 RPC 往返延迟 P50 / P95；
#   2. 10 个并发连接下的错误率（含响应错误与连接中断）；
#   3. 基准期间服务端 RSS 平均值与峰值。
#
# 用法：
#   ./scripts/bench.sh                         # 200 次单连接 + 10×40 并发
#   ./scripts/bench.sh --requests 500 --clients 10 --client-requests 50
#
# 退出码：0 通过 / 1 基准中出错 / 2 环境缺命令

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/scripts/env.sh"
tapmc_env_init
BACKEND_DIR="$REPO_ROOT/core/backend"
PROBE="$REPO_ROOT/scripts/bench/bench.dart"
WORK_DIR="$REPO_ROOT/tmp/bench"

REQUESTS=200
CLIENTS=10
CLIENT_REQUESTS=40

while [[ $# -gt 0 ]]; do
  case "$1" in
    --requests) REQUESTS="${2:?--requests 需要一个整数}"; shift ;;
    --clients) CLIENTS="${2:?--clients 需要一个整数}"; shift ;;
    --client-requests) CLIENT_REQUESTS="${2:?--client-requests 需要一个整数}"; shift ;;
    -h|--help) sed -n '/^# TapMC 运行期性能基准/,/^# 退出码/p' "${BASH_SOURCE[0]}" \
                 | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "[bench] 未知参数：$1" >&2; exit 2 ;;
  esac
  shift
done

require() { command -v "$1" >/dev/null 2>&1 || { echo "[bench] 缺少命令：$1" >&2; exit 2; }; }
require java
require python3
require dart

mkdir -p "$WORK_DIR"
RESULT="$WORK_DIR/result.json"
RSS_FILE="$WORK_DIR/rss-kb.txt"
LOG="$WORK_DIR/backend.log"
: >"$RSS_FILE"
: >"$LOG"

find_fat_jar() {
  ls -t "$BACKEND_DIR"/server/build/libs/server-*-all.jar 2>/dev/null | head -1 || true
}
FAT_JAR="$(find_fat_jar)"
if [[ -z "$FAT_JAR" ]]; then
  echo "[bench] 未找到 fatJar，先构建"
  ( cd "$BACKEND_DIR" && ./gradlew :server:fatJar -q --no-daemon ) >>"$LOG" 2>&1
  FAT_JAR="$(find_fat_jar)"
  [[ -n "$FAT_JAR" ]] || { echo "[bench] 构建后仍无 fatJar" >&2; exit 1; }
fi

PORT="$(python3 - <<'PY'
import socket
s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()
PY
)"
echo "[bench] 起后端 ws://127.0.0.1:${PORT}（--no-save，不碰玩家存档）"
java -jar "$FAT_JAR" --port "$PORT" --host 127.0.0.1 --no-save >>"$LOG" 2>&1 &
SERVER_PID=$!
SAMPLER_PID=""
cleanup() {
  [[ -n "$SAMPLER_PID" ]] && kill "$SAMPLER_PID" 2>/dev/null || true
  kill "$SERVER_PID" 2>/dev/null || true
  wait "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT

python3 - "$PORT" <<'PY'
import socket, sys, time
port = int(sys.argv[1])
for _ in range(60):
    s = socket.socket(); s.settimeout(0.5)
    try:
        s.connect(("127.0.0.1", port)); s.close(); break
    except OSError:
        s.close(); time.sleep(1)
else:
    raise SystemExit("[bench] 后端未就绪")
PY

# ps 在 macOS 上给 KB，Linux 上 /proc 给 kB；两边都归一成 KB。
( while kill -0 "$SERVER_PID" 2>/dev/null; do
    if [[ -r "/proc/$SERVER_PID/status" ]]; then
      awk '/^VmRSS:/ {print $2; exit}' "/proc/$SERVER_PID/status" >>"$RSS_FILE"
    else
      ps -o rss= -p "$SERVER_PID" 2>/dev/null | tr -d ' ' >>"$RSS_FILE"
    fi
    sleep 0.2
  done ) &
SAMPLER_PID=$!

echo "[bench] 采样中：单连接 ${REQUESTS} 次 + ${CLIENTS} 并发 × ${CLIENT_REQUESTS} 次"
if ! dart "$PROBE" --host 127.0.0.1 --port "$PORT" \
    --requests "$REQUESTS" --clients "$CLIENTS" \
    --client-requests "$CLIENT_REQUESTS" --json "$RESULT"; then
  echo "[bench] 基准断言失败，后端日志尾部：" >&2
  tail -n 40 "$LOG" >&2
  exit 1
fi

kill "$SAMPLER_PID" 2>/dev/null || true
wait "$SAMPLER_PID" 2>/dev/null || true
SAMPLER_PID=""

python3 - "$RSS_FILE" "$RESULT" <<'PY'
import json, statistics, sys
rss_path, result_path = sys.argv[1:]
values = []
with open(rss_path, encoding='utf-8') as f:
    for line in f:
        line = line.strip()
        if line.isdigit() and int(line) > 0:
            values.append(int(line))
if not values:
    raise SystemExit('[bench] 未采到 RSS 样本')
data = json.load(open(result_path, encoding='utf-8'))
data['rss'] = {
    'samples': len(values),
    'averageMb': round(statistics.mean(values) / 1024, 1),
    'peakMb': round(max(values) / 1024, 1),
}
with open(result_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write('\n')
print(f"[bench] 服务端 RSS  avg {data['rss']['averageMb']} MB  "
      f"peak {data['rss']['peakMb']} MB（{len(values)} 次采样）")
PY

echo "[bench] 机器：$(uname -srm)"
echo "[bench] 结果：$RESULT"
