#!/usr/bin/env bash
# 例行发版更新（在「本地 Mac」从仓库根目录执行）：只重建 DontLift app 容器，不碰共享 PG / Caddy。
# 流程：迁移前备份 DB → rsync 源码（保护机密与备份，不删服务器多余文件）→ 远程重建 app（Flyway 启动时自动迁移）
#       → 校验 /actuator/health=UP → 断言 Flyway 已应用本地最新迁移。
#
# 与 local-deploy.sh 的区别：local-deploy.sh 会跑整个 server-bootstrap.sh（重装 Docker 检查、覆盖
# /opt/stacks 的 Caddyfile、重启共享 PG），适合首次/重建基础设施；例行更新用本脚本更小步、更安全。
#
# 前置：能免密 ssh 登录服务器（建议 root）。
# 用法：./backend/deploy/release-update.sh [ssh_user@server_ip] [health_url]
set -euo pipefail

TARGET="${1:-root@124.222.79.121}"
HEALTH_URL="${2:-https://dontlift.peipadada.com/actuator/health}"
REMOTE_DIR="/opt/DontLift-app/backend"
HERE="$(cd "$(dirname "$0")/.." && pwd)"   # 指向 backend/
EXPECTED_MIGRATION_VERSION="$(
  find "$HERE/src/main/resources/db/migration" -maxdepth 1 -type f -name 'V*__*.sql' -print \
    | sed -E 's#.*/V([0-9]+)__.*#\1#' \
    | sort -n \
    | tail -1
)"

log(){ printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

log "目标：$TARGET   远程目录：$REMOTE_DIR"
log "本次后端改动（相对上一发版 tag）"
PREVIOUS_TAG="$(git -C "$HERE/.." describe --tags --abbrev=0 2>/dev/null || true)"
if [ -n "$PREVIOUS_TAG" ]; then
  git -C "$HERE/.." log --oneline "$PREVIOUS_TAG"..HEAD -- backend/ | head -20 || true
else
  git -C "$HERE/.." log --oneline -- backend/ | head -5 || true
fi

# ── 1. 迁移前备份（安全网；失败即中止，绝不带着无备份做迁移）──
log "迁移前备份生产 DB（dontlift）"
ssh "$TARGET" "cd $REMOTE_DIR && ./scripts/db-backup.sh"

# ── 2. rsync 同步源码 ──────────────────────────────────
# 不用 --delete（更保守，绝不误删服务器侧文件）；显式排除机密、备份、构建产物、git。
log "rsync 推送 backend/ 源码（排除机密/备份/构建产物）"
rsync -rlptz \
  --exclude '.env.prod' --exclude 'secrets/' --exclude 'backups/' \
  --exclude 'build/' --exclude '.gradle/' --exclude '.git/' --exclude '.idea/' \
  "$HERE/" "$TARGET:$REMOTE_DIR/"

# ── 3. 远程重建并启动 app（Flyway 启动时自动跑新增迁移）──
# 构建在服务器进行；Dockerfile 已内置阿里云 Maven + 腾讯云 Gradle 镜像加速。
log "远程重建并启动 dontlift-app（首次拉基础镜像/编译较久）"
ssh "$TARGET" "cd $REMOTE_DIR && docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build"

# ── 4. 校验 health（经公网 HTTPS，走完整 Caddy→app 链路）──
log "等待就绪并校验 $HEALTH_URL"
ok=""
for i in $(seq 1 60); do
  if curl -fsS "$HEALTH_URL" 2>/dev/null | grep -q '"status":"UP"'; then
    log "✅ 健康检查通过：status=UP"
    ok=1; break
  fi
  sleep 5
done
if [ -z "$ok" ]; then
  log "⚠️ 超时未就绪。排查：ssh $TARGET 'cd $REMOTE_DIR && docker compose -f docker-compose.prod.yml logs --tail=120 app'"
  exit 1
fi

# ── 5. 校验 Flyway 已应用本地最新迁移 ────────────────────
log "校验 Flyway 已应用本地最新迁移 V$EXPECTED_MIGRATION_VERSION"
applied="$(ssh "$TARGET" "docker exec shared-postgres psql -U dontlift -d dontlift -tAc \
  \"SELECT success FROM flyway_schema_history WHERE version = '$EXPECTED_MIGRATION_VERSION' ORDER BY installed_rank DESC LIMIT 1;\"" | tr -d '[:space:]')"
if [ "$applied" != "t" ]; then
  log "⚠️ 未确认 Flyway V$EXPECTED_MIGRATION_VERSION success=true，最近迁移如下"
  ssh "$TARGET" "docker exec shared-postgres psql -U dontlift -d dontlift -tAc \
    \"SELECT version || '  ' || description || '  success=' || success FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 5;\""
  exit 1
fi
log "Flyway V$EXPECTED_MIGRATION_VERSION 已成功应用"
ssh "$TARGET" "docker exec shared-postgres psql -U dontlift -d dontlift -tAc \
  \"SELECT version || '  ' || description || '  success=' || success FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 5;\""

log "🎉 发版更新完成。"
