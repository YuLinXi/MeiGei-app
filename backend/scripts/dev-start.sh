#!/usr/bin/env bash
# DontLift 后端本地一键启动脚本
# 用法：./scripts/dev-start.sh   （不要用 sh ./scripts/dev-start.sh）
#   - 自动检测并启动 PostgreSQL 16（已运行则跳过）
#   - 设置 JDK 21
#   - 注入 APP_DEV_TOKEN=true 便于本机免 Apple 登录
#   - 默认绑定 0.0.0.0，允许同一局域网真机访问本机后端
#   - 若后端端口已被占用，自动停止旧进程后重新启动
#   - 前台运行 bootRun，Ctrl+C 仅停后端，PG 保持运行（要全停用 dev-stop.sh）

# 防御：若被 sh / dash 误调用（无 BASH_VERSION），自动用 bash 重启自身
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

# ---- 可覆盖配置 ----
# JDK_HOME/JAVA_HOME/PG_BIN/PG_DATA/PG_ISREADY 可由环境变量显式指定；
# 未指定时脚本会按当前机器自动探测 Homebrew 和常见本机安装路径。
PG_LOG="${PG_LOG:-/tmp/pg_dontlift.log}"
APP_PORT="${PORT:-8001}"
APP_BIND_ADDRESS="${SERVER_ADDRESS:-0.0.0.0}"

# ---- 颜色输出 ----
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERR]${NC}   $*" >&2; }

detect_brew_bin() {
  local candidate=""
  candidate="$(command -v brew 2>/dev/null || true)"
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    echo "$candidate"
    return 0
  fi

  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew "$HOME/homebrew/bin/brew" "$HOME/.homebrew/bin/brew"; do
    if [ -x "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

brew_prefix() {
  local formula="${1:-}"
  local brew_bin=""
  brew_bin="$(detect_brew_bin || true)"
  [ -n "$brew_bin" ] || return 1

  if [ -n "$formula" ]; then
    "$brew_bin" --prefix "$formula" 2>/dev/null || true
  else
    "$brew_bin" --prefix 2>/dev/null || true
  fi
}

java_spec_version() {
  local java_bin="$1"
  "$java_bin" -XshowSettings:properties -version 2>&1 \
    | awk -F'= ' '/java.specification.version/{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}'
}

is_jdk21_home() {
  local home="$1"
  local spec=""
  [ -n "$home" ] && [ -x "$home/bin/java" ] || return 1
  spec="$(java_spec_version "$home/bin/java" || true)"
  [ "$spec" = "21" ]
}

detect_jdk_home() {
  local candidate=""
  local brew_jdk=""
  local -a candidates=()

  # 显式 JDK_HOME 是最高优先级，后续校验会给出准确错误。
  if [ -n "${JDK_HOME:-}" ]; then
    echo "$JDK_HOME"
    return 0
  fi

  if [ -n "${JAVA_HOME:-}" ] && is_jdk21_home "$JAVA_HOME"; then
    echo "$JAVA_HOME"
    return 0
  fi

  candidate="$(/usr/libexec/java_home -v 21 2>/dev/null || true)"
  if [ -n "$candidate" ] && is_jdk21_home "$candidate"; then
    echo "$candidate"
    return 0
  fi

  brew_jdk="$(brew_prefix openjdk@21 || true)"
  if [ -n "$brew_jdk" ]; then
    candidates+=("$brew_jdk/libexec/openjdk.jdk/Contents/Home")
  fi
  candidates+=(
    "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
    "/usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
    "$HOME/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
    "$HOME/.homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
  )

  for candidate in "${candidates[@]}"; do
    if is_jdk21_home "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done

  for candidate in "$HOME"/Library/Java/JavaVirtualMachines/*21*/Contents/Home /Library/Java/JavaVirtualMachines/*21*/Contents/Home; do
    if is_jdk21_home "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

pg_ctl_major_version() {
  local pg_ctl_bin="$1"
  "$pg_ctl_bin" --version 2>/dev/null \
    | awk '{for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+(\.[0-9]+)*/) {split($i, version, "."); print version[1]; exit}}'
}

is_pg16_ctl() {
  local pg_ctl_bin="$1"
  local major=""
  [ -n "$pg_ctl_bin" ] && [ -x "$pg_ctl_bin" ] || return 1
  major="$(pg_ctl_major_version "$pg_ctl_bin" || true)"
  [ "$major" = "16" ]
}

is_pg16_data_dir() {
  local data_dir="$1"
  local version=""
  [ -n "$data_dir" ] && [ -d "$data_dir" ] && [ -f "$data_dir/PG_VERSION" ] || return 1
  version="$(tr -d '[:space:]' < "$data_dir/PG_VERSION" 2>/dev/null || true)"
  [ "$version" = "16" ]
}

detect_pg_ctl() {
  local candidate=""
  local brew_pg=""
  local -a candidates=()

  if [ -n "${PG_BIN:-}" ]; then
    echo "$PG_BIN"
    return 0
  fi

  brew_pg="$(brew_prefix postgresql@16 || true)"
  if [ -n "$brew_pg" ]; then
    candidates+=("$brew_pg/bin/pg_ctl")
  fi
  candidates+=(
    "/opt/homebrew/opt/postgresql@16/bin/pg_ctl"
    "/usr/local/opt/postgresql@16/bin/pg_ctl"
    "$HOME/homebrew/opt/postgresql@16/bin/pg_ctl"
    "$HOME/.homebrew/opt/postgresql@16/bin/pg_ctl"
  )

  for candidate in "${candidates[@]}"; do
    if is_pg16_ctl "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done

  candidate="$(command -v pg_ctl 2>/dev/null || true)"
  if is_pg16_ctl "$candidate"; then
    echo "$candidate"
    return 0
  fi

  return 1
}

detect_pg_data() {
  local candidate=""
  local brew_home=""
  local -a candidates=()

  # 显式 PG_DATA/PGDATA 是最高优先级，后续校验会给出准确错误。
  if [ -n "${PG_DATA:-}" ]; then
    echo "$PG_DATA"
    return 0
  fi
  if [ -n "${PGDATA:-}" ]; then
    echo "$PGDATA"
    return 0
  fi

  brew_home="$(brew_prefix || true)"
  if [ -n "$brew_home" ]; then
    candidates+=("$brew_home/var/postgresql@16" "$brew_home/var/postgres")
  fi
  candidates+=(
    "/opt/homebrew/var/postgresql@16"
    "/opt/homebrew/var/postgres"
    "/usr/local/var/postgresql@16"
    "/usr/local/var/postgres"
    "$HOME/homebrew/var/postgresql@16"
    "$HOME/homebrew/var/postgres"
    "$HOME/.homebrew/var/postgresql@16"
    "$HOME/.homebrew/var/postgres"
  )

  for candidate in "${candidates[@]}"; do
    if is_pg16_data_dir "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

detect_pg_isready() {
  local candidate=""

  if [ -n "${PG_ISREADY:-}" ]; then
    echo "$PG_ISREADY"
    return 0
  fi

  candidate="$(dirname "$PG_BIN")/pg_isready"
  if [ -x "$candidate" ]; then
    echo "$candidate"
    return 0
  fi

  candidate="$(command -v pg_isready 2>/dev/null || true)"
  if [ -x "$candidate" ]; then
    echo "$candidate"
    return 0
  fi

  return 1
}

detect_lan_ip() {
  local iface=""
  iface="$(route get default 2>/dev/null | awk '/interface:/{print $2; exit}' || true)"
  if [ -n "$iface" ]; then
    local ip=""
    ip="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      echo "$ip"
      return
    fi
  fi

  ifconfig 2>/dev/null | awk '/inet / && $2 !~ /^127\./ {print $2; exit}' || true
}

stop_existing_backend() {
  local pids=""
  pids="$(lsof -tiTCP:"$APP_PORT" -sTCP:LISTEN 2>/dev/null || true)"
  if [ -z "$pids" ]; then
    info "端口 $APP_PORT 未被占用"
    return
  fi

  warn "端口 $APP_PORT 已被占用，自动停止旧后端进程：$pids"
  kill $pids 2>/dev/null || true
  for _ in {1..20}; do
    if ! lsof -tiTCP:"$APP_PORT" -sTCP:LISTEN > /dev/null 2>&1; then
      info "端口 $APP_PORT 已释放"
      return
    fi
    sleep 0.2
  done

  local remain=""
  remain="$(lsof -tiTCP:"$APP_PORT" -sTCP:LISTEN 2>/dev/null || true)"
  if [ -n "$remain" ]; then
    warn "旧进程未优雅退出，强制停止：$remain"
    kill -9 $remain 2>/dev/null || true
  fi

  for _ in {1..20}; do
    if ! lsof -tiTCP:"$APP_PORT" -sTCP:LISTEN > /dev/null 2>&1; then
      info "端口 $APP_PORT 已释放"
      return
    fi
    sleep 0.2
  done

  error "端口 $APP_PORT 仍未释放，请检查：lsof -nP -iTCP:$APP_PORT -sTCP:LISTEN"
  exit 1
}

# ---- 切到 backend/ 根目录（脚本在 backend/scripts/ 下）----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$BACKEND_DIR"

# ---- 1. 探测并校验 JDK 21 ----
if ! JDK_HOME="$(detect_jdk_home)"; then
  error "未找到可用的 JDK 21"
  error "请先安装 JDK 21（例如 brew install openjdk@21），或通过 JDK_HOME=/path/to/jdk ./scripts/dev-start.sh 指定"
  exit 1
fi
if ! is_jdk21_home "$JDK_HOME"; then
  error "JDK_HOME 不是可用的 JDK 21：$JDK_HOME"
  error "当前脚本需要 Java 21；可通过 JDK_HOME=/path/to/jdk ./scripts/dev-start.sh 指定"
  exit 1
fi
export JAVA_HOME="$JDK_HOME"
info "JAVA_HOME = $JAVA_HOME"

# ---- 2. 校验 gradlew ----
if [ ! -x "./gradlew" ]; then
  error "未找到可执行的 ./gradlew（当前目录：${BACKEND_DIR}）"
  exit 1
fi

# ---- 3. 探测并启动 PostgreSQL（幂等）----
if ! PG_BIN="$(detect_pg_ctl)"; then
  error "未找到 PostgreSQL 16 的 pg_ctl"
  error "请先安装 PostgreSQL 16（例如 brew install postgresql@16），或通过 PG_BIN=/path/to/pg_ctl ./scripts/dev-start.sh 指定"
  exit 1
fi
if ! is_pg16_ctl "$PG_BIN"; then
  error "PG_BIN 不是 PostgreSQL 16 的 pg_ctl：$PG_BIN"
  error "当前版本：$("$PG_BIN" --version 2>/dev/null || echo "无法读取")"
  exit 1
fi
if ! PG_DATA="$(detect_pg_data)"; then
  error "未找到 PostgreSQL 16 数据目录"
  error "请确认已初始化本机数据库，或通过 PG_DATA=/path/to/postgresql@16 ./scripts/dev-start.sh 指定"
  exit 1
fi
if ! is_pg16_data_dir "$PG_DATA"; then
  error "PG_DATA 不是 PostgreSQL 16 数据目录：$PG_DATA"
  error "请确认该目录下 PG_VERSION 为 16，或通过 PG_DATA=/path/to/postgresql@16 ./scripts/dev-start.sh 指定"
  exit 1
fi
if ! PG_ISREADY="$(detect_pg_isready)"; then
  error "未找到 pg_isready"
  error "请确认 PostgreSQL 16 bin 目录存在，或通过 PG_ISREADY=/path/to/pg_isready ./scripts/dev-start.sh 指定"
  exit 1
fi

info "pg_ctl = $PG_BIN"
info "PGDATA = $PG_DATA"
if "$PG_BIN" -D "$PG_DATA" status > /dev/null 2>&1; then
  info "PostgreSQL 16 已在运行"
else
  info "启动 PostgreSQL 16（日志：${PG_LOG}）..."
  "$PG_BIN" -D "$PG_DATA" -l "$PG_LOG" start
fi
# 等待端口可连
for i in {1..20}; do
  if "$PG_ISREADY" -h localhost -p 5432 -q 2>/dev/null; then break; fi
  sleep 0.5
done
if ! "$PG_ISREADY" -h localhost -p 5432 -q 2>/dev/null; then
  error "PostgreSQL 启动超时，查日志：$PG_LOG"
  exit 1
fi
info "PostgreSQL 已就绪（localhost:5432）"

# ---- 4. 自动释放旧后端端口，允许重复执行脚本重启 ----
stop_existing_backend

# ---- 5. 启动 Spring Boot ----
LAN_IP="$(detect_lan_ip)"
info "启动 Spring Boot（绑定 ${APP_BIND_ADDRESS}:${APP_PORT}，APP_DEV_TOKEN=true）"
info "就绪后可访问："
info "  - Swagger UI:  http://localhost:$APP_PORT/swagger-ui.html"
info "  - Health:      http://localhost:$APP_PORT/actuator/health"
info "  - Dev token:   POST http://localhost:$APP_PORT/auth/dev/token"
if [ -n "$LAN_IP" ]; then
  info "  - 真机 LAN:    http://$LAN_IP:$APP_PORT/actuator/health"
  info "    iOS 真机联调配置：LAN_IP=$LAN_IP ./scripts/ios-device-lan-dev.sh apply"
else
  warn "未能检测到局域网 IP；真机联调时可手动传 LAN_IP 给 scripts/ios-device-lan-dev.sh。"
fi
info "重复执行 ./scripts/dev-start.sh 会自动重启后端"
info "Ctrl+C 停止后端（PG 保持运行；要全停执行 ./scripts/dev-stop.sh）"
echo ""

export APP_DEV_TOKEN=true
export SERVER_ADDRESS="$APP_BIND_ADDRESS"
exec ./gradlew bootRun
