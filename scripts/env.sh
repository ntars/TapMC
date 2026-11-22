#!/usr/bin/env bash
# 可复现验证的统一环境引导。
#
# 目的：把「本机恰好怎么装的工具」挡在业务脚本之外。验证脚本只调用 tapmc_env_init，
# 之后 java / dart / flutter / gradle 都能按统一方式找到。

TAPMC_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAPMC_TMP_ROOT="${TMPDIR:-/tmp}/tapmc-verify"
TAPMC_FLUTTER_ROOT="${TAPMC_FLUTTER_ROOT:-$HOME/.local/flutter-3.50.0}"

tapmc_env_init() {
  mkdir -p "$TAPMC_TMP_ROOT/gradle" "$TAPMC_TMP_ROOT/home" "$TAPMC_TMP_ROOT/pub-cache"

  # Gradle 与 Java 都不读 HTTPS_PROXY。把环境变量翻译成命令行属性，
  # 避免把某个开发机的代理端口（历史上的 52201）写死进仓库。
  if [[ -n "${HTTPS_PROXY:-${https_proxy:-}}" ]]; then
    local proxy="${HTTPS_PROXY:-${https_proxy}}"
    proxy="${proxy#*://}"
    proxy="${proxy#*@}"
    local host="${proxy%%:*}"
    local port="${proxy##*:}"
    [[ "$port" == "$proxy" ]] && port=80
    export GRADLE_PROXY_HOST="$host"
    export GRADLE_PROXY_PORT="$port"
  else
    export GRADLE_PROXY_HOST=
    export GRADLE_PROXY_PORT=
  fi

  # 有些本机代理进程虽在 env 里声明，实际并未监听。Gradle 属性里写死一个死端口会
  # 让构建直接 Connection refused；这里在可用时才把代理传给 Gradle。
  if ! python3 - "$GRADLE_PROXY_HOST" "$GRADLE_PROXY_PORT" <<'PY' 2>/dev/null
import socket, sys
s = socket.socket()
s.settimeout(0.3)
try:
    s.connect((sys.argv[1], int(sys.argv[2])))
finally:
    s.close()
PY
  then
    export GRADLE_PROXY_HOST=
    export GRADLE_PROXY_PORT=
  fi

  if [[ -n "$GRADLE_PROXY_HOST" && -n "$GRADLE_PROXY_PORT" ]]; then
    GRADLE_OPTS="${GRADLE_OPTS:-} -Dhttp.proxyHost=$GRADLE_PROXY_HOST -Dhttp.proxyPort=$GRADLE_PROXY_PORT -Dhttps.proxyHost=$GRADLE_PROXY_HOST -Dhttps.proxyPort=$GRADLE_PROXY_PORT"
    export GRADLE_OPTS
  fi

  export GRADLE_USER_HOME="$TAPMC_TMP_ROOT/gradle"

  # Flutter 会尝试刷新其 SDK 缓存、写 ~/.dart-tool 与 pub cache。验证环境用临时 HOME，
  # 不污染用户目录；如果本机 SDK 不在默认位置，用 TAPMC_FLUTTER_ROOT 覆盖。
  if [[ -x "$TAPMC_FLUTTER_ROOT/bin/flutter" ]] && [[ -d "$TAPMC_FLUTTER_ROOT/bin/cache/dart-sdk/bin" ]]; then
    export HOME="$TAPMC_TMP_ROOT/home"
    export PUB_CACHE="$TAPMC_TMP_ROOT/pub-cache"
    export PATH="$TAPMC_FLUTTER_ROOT/bin/cache/dart-sdk/bin:$TAPMC_FLUTTER_ROOT/bin:$PATH"
  fi
}
