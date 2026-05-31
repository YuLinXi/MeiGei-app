#!/usr/bin/env bash
# MeiGei 后端本地一键停止脚本
# 用法：./scripts/dev-stop.sh [--keep-pg]   （不要用 sh）
#   - 默认同时停 Spring Boot（8001）与 PostgreSQL
#   - 加 --keep-pg 只停后端，保留 PG

if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

PG_BIN="/opt/homebrew/opt/postgresql@16/bin/pg_ctl"
PG_DATA="/opt/homebrew/var/postgresql@16"
APP_PORT="${PORT:-8001}"
KEEP_PG=false
[ "${1:-}" = "--keep-pg" ] && KEEP_PG=true

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }

# ---- 停后端 ----
PIDS=$(lsof -ti:"$APP_PORT" 2>/dev/null || true)
if [ -n "$PIDS" ]; then
  info "停止后端进程：$PIDS"
  kill $PIDS 2>/dev/null || true
  sleep 2
  REMAIN=$(lsof -ti:"$APP_PORT" 2>/dev/null || true)
  if [ -n "$REMAIN" ]; then
    warn "未优雅退出，强制 kill -9"
    kill -9 $REMAIN 2>/dev/null || true
  fi
  info "端口 $APP_PORT 已释放"
else
  info "端口 $APP_PORT 无进程占用"
fi

# ---- 停 PG ----
if $KEEP_PG; then
  info "--keep-pg 指定，保留 PostgreSQL"
  exit 0
fi
if [ -x "$PG_BIN" ] && "$PG_BIN" -D "$PG_DATA" status > /dev/null 2>&1; then
  info "停止 PostgreSQL..."
  "$PG_BIN" -D "$PG_DATA" stop
  info "PostgreSQL 已停止"
else
  info "PostgreSQL 未运行"
fi
