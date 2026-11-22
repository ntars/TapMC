#!/usr/bin/env bash
#
# TapMC 发布构建：产出「服务端可运行包 + Web 前端产物 + 校验清单」。
#
# 这里的产物故意保持朴素：一个 java -jar 可跑的 fatJar、一个静态 Web 目录、
# 一份 SHA-256 清单。TapMC 没有数据库/消息中间件，这两个文件就是完整交付物。
#
# 用法：
#   scripts/build_release.sh [输出目录]
#
# 默认输出：dist/
# 退出码：0 成功 / 1 构建或校验失败 / 2 环境缺命令

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/scripts/env.sh"
tapmc_env_init

OUT_DIR="${1:-$REPO_ROOT/dist}"
BACKEND_DIR="$REPO_ROOT/core/backend"
FRONTEND_DIR="$REPO_ROOT/core/frontend"

require() { command -v "$1" >/dev/null 2>&1 || { echo "[release] 缺少命令：$1" >&2; exit 2; }; }
require java
require python3
require flutter

mkdir -p "$OUT_DIR"
echo "[release] 清理旧产物：$OUT_DIR"
find "$OUT_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

echo "[release] 构建后端 fatJar / distributions"
(
  cd "$BACKEND_DIR"
  ./gradlew clean :server:fatJar :server:distTar :server:distZip --no-daemon
)

FAT_JARS=("$BACKEND_DIR"/server/build/libs/server-*-all.jar)
[[ -f "${FAT_JARS[0]}" ]] || { echo "[release] 未找到 server-*-all.jar" >&2; exit 1; }

echo "[release] 构建 Web 发布产物"
(
  cd "$FRONTEND_DIR"
  flutter pub get
  flutter build web --release
)

WEB_ROOT="$FRONTEND_DIR/build/web"
[[ -f "$WEB_ROOT/index.html" ]] || { echo "[release] 缺少 Web 产物 index.html" >&2; exit 1; }

SERVER_OUT="$OUT_DIR/server"
WEB_OUT="$OUT_DIR/web"
mkdir -p "$SERVER_OUT" "$WEB_OUT"
cp "${FAT_JARS[0]}" "$SERVER_OUT/"
cp "$BACKEND_DIR"/server/build/distributions/*.tar "$SERVER_OUT/" 2>/dev/null || true
cp "$BACKEND_DIR"/server/build/distributions/*.zip "$SERVER_OUT/" 2>/dev/null || true
cp -R "$WEB_ROOT"/. "$WEB_OUT/"

# 校验清单给发布/运维一个可核对的锚点：同名文件同名哈希，能发现复制中断与替换。
# 用 `cd dist && shasum -c SHA256SUMS` 可直接验；因此清单里不写注释行。
python3 - "$OUT_DIR" <<'PY'
import hashlib
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
lines = []
for path in sorted(p for p in root.rglob("*") if p.is_file()):
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    lines.append(f"{digest}  {path.relative_to(root)}")
(root / "SHA256SUMS").write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"[release] 校验清单：{root / 'SHA256SUMS'}（{len(lines)} 个文件）")
PY

echo "[release] 完成"
echo "  服务端：$(basename "${FAT_JARS[0]}") → $SERVER_OUT"
echo "  Web：$WEB_OUT"
echo "  启动：java -jar $SERVER_OUT/$(basename "${FAT_JARS[0]}") --host 127.0.0.1 --port 8777"
