#!/usr/bin/env bash
#
# TapMC 存档重启验证（T04）
#
# 一条命令回答：「服务端真的会把世界写进磁盘、并在下次启动时原样读回来吗」。
# 单测只能证明「写入的字节能读回」，证明不了 Main 的装配、退出钩子与真实退出路径。
# 所以这里开两个真实进程，中间隔着一次 SIGTERM。
#
#   1. 第一轮：起服务 → 破坏并放置若干方块 → SIGTERM（触发退出存档）
#   2. 断言存档文件存在且是合法 JSON
#   3. 第二轮：用同一存档路径起服务 → 拉 world.snapshot
#   4. 逐格比对两轮快照，任何一格不同即失败
#
# 用法：
#   scripts/persist_verify.sh              # 默认
#   scripts/persist_verify.sh --keep       # 保留存档文件供人工查看
#
# 退出码：0 通过 / 1 断言失败 / 2 环境缺命令

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/scripts/env.sh"
tapmc_env_init
BACKEND_DIR="$REPO_ROOT/core/backend"
PROBE="$REPO_ROOT/scripts/persist/probe.dart"
LOG_DIR="$REPO_ROOT/tmp/persist"

KEEP=0
HOST="127.0.0.1"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep) KEEP=1 ;;
    -h|--help) sed -n '/^# TapMC 存档重启验证/,/^# 退出码/p' "${BASH_SOURCE[0]}" \
                 | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数：$1" >&2; exit 2 ;;
  esac
  shift
done

mkdir -p "$LOG_DIR"
WORK_DIR="$LOG_DIR/work"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
SAVE_FILE="$WORK_DIR/world.json"

R1_LOG="$LOG_DIR/round1.log"
R2_LOG="$LOG_DIR/round2.log"
: >"$R1_LOG"
: >"$R2_LOG"

PIDS=()
cleanup() {
  for pid in "${PIDS[@]:-}"; do
    [[ -z "$pid" ]] && continue
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT

fail() {
  echo "[persist] 失败：$1" >&2
  [[ -n "${2:-}" ]] && { echo "----- ${2} 最后 40 行 -----" >&2; tail -n 40 "$2" >&2 || true; }
  exit 1
}
require() { command -v "$1" >/dev/null 2>&1 || { echo "[persist] 缺少命令：$1" >&2; exit 2; }; }

require java
require python3
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
s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()
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

find_fat_jar() {
  ls -t "$BACKEND_DIR"/server/build/libs/server-*-all.jar 2>/dev/null | head -1 || true
}
FAT_JAR="$(find_fat_jar)"
if [[ -z "$FAT_JAR" ]]; then
  echo "[persist] 未找到 fatJar，先构建"
  ( cd "$BACKEND_DIR" && ./gradlew :server:fatJar -q ) >>"$R1_LOG" 2>&1 \
    || fail "构建 fatJar 失败" "$R1_LOG"
  FAT_JAR="$(find_fat_jar)"
  [[ -n "$FAT_JAR" ]] || fail "构建后仍未找到 server-*-all.jar" "$R1_LOG"
fi

# ---------------------------------------------------------------- 第一轮
PORT1="$(pick_port)"
echo "[persist] 第一轮：起服务 ws://${HOST}:${PORT1}，存档 $SAVE_FILE"
java -jar "$FAT_JAR" --port "$PORT1" --host "$HOST" \
  --save-file "$SAVE_FILE" --autosave 0 >>"$R1_LOG" 2>&1 &
PID1=$!
PIDS+=("$PID1")
wait_for_port "$HOST" "$PORT1" 60 || fail "第一轮后端未监听 ${PORT1}" "$R1_LOG"

BEFORE="$WORK_DIR/snapshot-before.json"
if ! dart "$PROBE" --host "$HOST" --port "$PORT1" --mutate --dump "$BEFORE" \
     >"$LOG_DIR/probe1.log" 2>&1; then
  cat "$LOG_DIR/probe1.log" >&2
  fail "第一轮改动/取快照失败" "$R1_LOG"
fi
cat "$LOG_DIR/probe1.log"

# SIGTERM 是关键：退出钩子只在正常终止时执行。这里不用 kill -9，
# 因为要验的正是「退出时保存」这条路径。
kill -TERM "$PID1"
wait "$PID1" 2>/dev/null || true
PIDS=("${PIDS[@]/$PID1}")

grep -q "退出存档完成" "$R1_LOG" || fail "退出时未打印「退出存档完成」" "$R1_LOG"

# ---------------------------------------------------------------- 断言存档
[[ -f "$SAVE_FILE" ]] || fail "存档文件未生成：$SAVE_FILE" "$R1_LOG"
python3 - "$SAVE_FILE" <<'PY' || exit 1
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
for key in ("formatVersion", "width", "height", "savedAt", "blocks"):
    assert key in data, f"存档缺字段 {key}"
assert data["formatVersion"] == 1, f"格式版本应为 1，实为 {data['formatVersion']}"
assert len(data["blocks"]) == data["width"] * data["height"], "方块数量与尺寸不符"
print(f"[persist] 存档合法  {data['width']}x{data['height']}  "
      f"blocks={len(data['blocks'])}  bytes={len(json.dumps(data))}")
PY

# ---------------------------------------------------------------- 第二轮
PORT2="$(pick_port)"
echo "[persist] 第二轮：用同一存档重启 ws://${HOST}:${PORT2}"
java -jar "$FAT_JAR" --port "$PORT2" --host "$HOST" \
  --save-file "$SAVE_FILE" --autosave 0 >>"$R2_LOG" 2>&1 &
PID2=$!
PIDS+=("$PID2")
wait_for_port "$HOST" "$PORT2" 60 || fail "第二轮后端未监听 ${PORT2}" "$R2_LOG"

grep -q "已载入存档" "$R2_LOG" || fail "第二轮未打印「已载入存档」，可能回退到了新地图" "$R2_LOG"

AFTER="$WORK_DIR/snapshot-after.json"
if ! dart "$PROBE" --host "$HOST" --port "$PORT2" --dump "$AFTER" \
     >"$LOG_DIR/probe2.log" 2>&1; then
  cat "$LOG_DIR/probe2.log" >&2
  fail "第二轮取快照失败" "$R2_LOG"
fi

# 逐格比对：只报「一致/不一致」看不出问题在哪，所以打印首个差异格。
python3 - "$BEFORE" "$AFTER" <<'PY' || exit 1
import json, sys
a = json.load(open(sys.argv[1], encoding="utf-8"))
b = json.load(open(sys.argv[2], encoding="utf-8"))
assert a["width"] == b["width"] and a["height"] == b["height"], "两轮世界尺寸不同"
diffs = [i for i, (x, y) in enumerate(zip(a["blocks"], b["blocks"])) if x != y]
w = a["width"]
if diffs:
    i = diffs[0]
    print(f"[persist] 共 {len(diffs)} 格不一致；首例索引 {i} = ({i % w},{i // w}) "
          f"重启前 {a['blocks'][i]} → 重启后 {b['blocks'][i]}", file=sys.stderr)
    sys.exit(1)
print(f"[persist] 逐格一致  {len(a['blocks'])} 格全等  {a['width']}x{a['height']}")
PY

# ---------------------------------------------------------------- 第三轮：定时存档
# 退出钩子只覆盖「正常退出」。容器被 docker stop 超时杀掉、断电、kill -9 都不会触发。
# 这一轮故意用 SIGKILL 杀掉进程，验「周期写盘」能在钩子失效时兜底。
PORT3="$(pick_port)"
KILL_FILE="$WORK_DIR/world-killed.json"
R3_LOG="$LOG_DIR/round3.log"
: >"$R3_LOG"
echo "[persist] 第三轮：autosave=1s，改世界后 SIGKILL"
java -jar "$FAT_JAR" --port "$PORT3" --host "$HOST" \
  --save-file "$KILL_FILE" --autosave 1 >>"$R3_LOG" 2>&1 &
PID3=$!
PIDS+=("$PID3")
wait_for_port "$HOST" "$PORT3" 60 || fail "第三轮后端未监听 ${PORT3}" "$R3_LOG"

DROPPED="$WORK_DIR/snapshot-dropped.json"
if ! dart "$PROBE" --host "$HOST" --port "$PORT3" --mutate --dump "$DROPPED" \
     >"$LOG_DIR/probe3.log" 2>&1; then
  cat "$LOG_DIR/probe3.log" >&2
  fail "第三轮改动失败" "$R3_LOG"
fi

# 等一个 autosave 周期。这里必须真等：定时线程的最小间隔就是 1s，
# 改完立刻 kill 会命中「还没到写盘点」的正常情况，测出来的是运气不是行为。
sleep 3
kill -KILL "$PID3" 2>/dev/null || true
wait "$PID3" 2>/dev/null || true
PIDS=("${PIDS[@]/$PID3}")

[[ -f "$KILL_FILE" ]] || fail "autosave 未在 3s 内写盘（SIGKILL 后无档可救）" "$R3_LOG"
grep -q "退出存档完成" "$R3_LOG" && fail "SIGKILL 不该触发退出钩子，日志出现「退出存档完成」说明测试本身没按预期执行" "$R3_LOG"

DIRECT="$WORK_DIR/snapshot-direct.json"
python3 - "$KILL_FILE" "$DIRECT" <<'PY' || exit 1
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["formatVersion"] == 1
assert len(data["blocks"]) == data["width"] * data["height"]
json.dump({"width": data["width"], "height": data["height"], "blocks": data["blocks"]},
          open(sys.argv[2], "w", encoding="utf-8"))
print(f"[persist] SIGKILL 后仍有存档  {data['width']}x{data['height']}  blocks={len(data['blocks'])}")
PY

# 存档内容必须等于被杀前内存里的世界——否则「有档」也救不回来。
python3 - "$DROPPED" "$DIRECT" <<'PY' || exit 1
import json, sys
a = json.load(open(sys.argv[1], encoding="utf-8"))
b = json.load(open(sys.argv[2], encoding="utf-8"))
diffs = [i for i, (x, y) in enumerate(zip(a["blocks"], b["blocks"])) if x != y]
if diffs:
    i = diffs[0]
    print(f"[persist] autosave 内容滞后：{len(diffs)} 格不同，首例 ({i % a['width']},{i // a['width']}) "
          f"{a['blocks'][i]} vs {b['blocks'][i]}", file=sys.stderr)
    sys.exit(1)
print(f"[persist] autosave 内容与内存一致  {len(a['blocks'])} 格")
PY

echo "[persist] 通过  存档 $SAVE_FILE  日志 $LOG_DIR"
if [[ "$KEEP" == "0" ]]; then
  echo "[persist] 提示：存档已在 ${SAVE_FILE}，加 --keep 可保留 tmp/persist 供人工查看"
fi
