#!/usr/bin/env bash
# MeiGei 后端本地一键启动脚本
# 用法：./scripts/dev-start.sh   （不要用 sh ./scripts/dev-start.sh）
#   - 自动检测并启动 PostgreSQL 16（已运行则跳过）
#   - 设置 JDK 21
#   - 注入 APP_DEV_TOKEN=true 便于本机免 Apple 登录
#   - 前台运行 bootRun，Ctrl+C 仅停后端，PG 保持运行（要全停用 dev-stop.sh）

# 防御：若被 sh / dash 误调用（无 BASH_VERSION），自动用 bash 重启自身
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

# ---- 路径配置（按本机 Homebrew 安装位置）----
JDK_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
PG_BIN="/opt/homebrew/opt/postgresql@16/bin/pg_ctl"
PG_DATA="/opt/homebrew/var/postgresql@16"
PG_LOG="/tmp/pg_meigei.log"
APP_PORT="${PORT:-8001}"

# ---- 颜色输出 ----
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERR]${NC}   $*" >&2; }

# ---- 切到 backend/ 根目录（脚本在 backend/scripts/ 下）----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$BACKEND_DIR"

# ---- 1. 校验 JDK 21 ----
if [ ! -d "$JDK_HOME" ]; then
  error "未找到 JDK 21：$JDK_HOME"
  error "请先 brew install openjdk@21"
  exit 1
fi
export JAVA_HOME="$JDK_HOME"
info "JAVA_HOME = $JAVA_HOME"

# ---- 2. 校验 gradlew ----
if [ ! -x "./gradlew" ]; then
  error "未找到可执行的 ./gradlew（当前目录：${BACKEND_DIR}）"
  exit 1
fi

# ---- 3. 启动 PostgreSQL（幂等）----
if [ ! -x "$PG_BIN" ]; then
  error "未找到 pg_ctl：$PG_BIN"
  error "请先 brew install postgresql@16"
  exit 1
fi
if "$PG_BIN" -D "$PG_DATA" status > /dev/null 2>&1; then
  info "PostgreSQL 16 已在运行"
else
  info "启动 PostgreSQL 16（日志：${PG_LOG}）..."
  "$PG_BIN" -D "$PG_DATA" -l "$PG_LOG" start
fi
# 等待端口可连
for i in {1..20}; do
  if pg_isready -h localhost -p 5432 -q 2>/dev/null; then break; fi
  sleep 0.5
done
if ! pg_isready -h localhost -p 5432 -q 2>/dev/null; then
  error "PostgreSQL 启动超时，查日志：$PG_LOG"
  exit 1
fi
info "PostgreSQL 已就绪（localhost:5432）"

# ---- 4. 校验端口未被占用 ----
if lsof -ti:"$APP_PORT" > /dev/null 2>&1; then
  error "端口 $APP_PORT 已被占用，先执行：./scripts/dev-stop.sh"
  exit 1
fi

# ---- 5. 启动 Spring Boot ----
info "启动 Spring Boot（端口 ${APP_PORT}，APP_DEV_TOKEN=true）"
info "就绪后可访问："
info "  - Swagger UI:  http://localhost:$APP_PORT/swagger-ui.html"
info "  - Health:      http://localhost:$APP_PORT/actuator/health"
info "  - Dev token:   POST http://localhost:$APP_PORT/auth/dev/token"
info "Ctrl+C 停止后端（PG 保持运行；要全停执行 ./scripts/dev-stop.sh）"
echo ""

export APP_DEV_TOKEN=true
exec ./gradlew bootRun
