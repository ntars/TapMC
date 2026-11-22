#!/usr/bin/env bash
#
# TapMC 发布验收入口：基础测试 + 产物冒烟 + 存档端到端 + 前端契约。
#
# 这是 README「验收清单」用的唯一命令。每项都起真实进程或跑真实测试，
# 不用 grep 源码代替行为验证。
#
# 用法：
#   scripts/verify_release.sh [--skip-e2e] [--skip-macos]
#
# 退出码：0 全部通过 / 1 某项失败 / 2 环境缺命令

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/scripts/env.sh"
tapmc_env_init

RUN_E2E=1
RUN_MACOS=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-e2e) RUN_E2E=0 ;;
    --skip-macos) RUN_MACOS=0 ;;
    -h|--help) sed -n '/^# TapMC 发布验收入口/,/^# 退出码/p' "${BASH_SOURCE[0]}" \
                 | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "[verify] 未知参数：$1" >&2; exit 2 ;;
  esac
  shift
done

require() { command -v "$1" >/dev/null 2>&1 || { echo "[verify] 缺少命令：$1" >&2; exit 2; }; }
require java
require python3
require dart
require flutter

step() { echo ""; echo "[verify] $1"; }

step "1/6 后端构建与单元测试"
(
  cd "$REPO_ROOT/core/backend"
  ./gradlew clean build --no-daemon
)

step "2/6 前端单元测试"
(
  cd "$REPO_ROOT/core/frontend"
  flutter test
)

step "3/6 发布构建"
"$REPO_ROOT/scripts/build_release.sh" "$REPO_ROOT/dist"

step "4/6 握手冒烟（协议 1.0）"
"$REPO_ROOT/scripts/smoke.sh" --expect-protocol 1.0 --no-web

step "5/6 存档端到端（退出写盘 / 重启一致 / SIGKILL autosave）"
"$REPO_ROOT/scripts/persist_verify.sh"

if [[ "$RUN_E2E" == "1" ]]; then
  step "6/6 前后端真实契约"
  FAT_JAR="$(ls -t "$REPO_ROOT/core/backend"/server/build/libs/server-*-all.jar 2>/dev/null | head -1 || true)"
  [[ -n "$FAT_JAR" ]] || { echo "[verify] 未找到 fatJar，无法跑契约测试" >&2; exit 1; }
  PORT="$(python3 - <<'PY'
import socket
s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()
PY
)"
  LOG="$REPO_ROOT/tmp/verify-e2e-backend.log"
  mkdir -p "$REPO_ROOT/tmp"
  : >"$LOG"
  java -jar "$FAT_JAR" --port "$PORT" --host 127.0.0.1 --no-save >>"$LOG" 2>&1 &
  PID=$!
  trap 'kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true' EXIT
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
    raise SystemExit("后端未就绪")
PY
  (
    cd "$REPO_ROOT/core/frontend"
    TAPMC_E2E=1 TAPMC_E2E_PORT="$PORT" flutter test test/e2e_contract_test.dart
  )
  kill "$PID" 2>/dev/null || true
  wait "$PID" 2>/dev/null || true
  trap - EXIT
else
  step "6/6 跳过前后端契约（--skip-e2e）"
fi

if [[ "$RUN_MACOS" == "1" ]]; then
  step "附加：macOS 桌面端实跑"
  "$REPO_ROOT/scripts/macos_verify.sh" --no-build
fi

echo ""
echo "[verify] 全部通过"
