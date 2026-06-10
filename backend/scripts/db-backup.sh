#!/usr/bin/env bash
# 备份共享 PG 实例里的 DontLift 数据库（dontlift），压缩后保留最近 14 天。
# 数据库属于共享基础设施栈（deploy/shared-infra/db），故直接对 shared-postgres 容器执行。
# 用法：./scripts/db-backup.sh
# 建议 cron（每天 03:30）：
#   30 3 * * * cd /opt/DontLift-app/backend && ./scripts/db-backup.sh >> /var/log/dontlift-backup.log 2>&1
set -euo pipefail

PG_CONTAINER="${PG_CONTAINER:-shared-postgres}"
DB_NAME="${DB_NAME:-dontlift}"
DB_USER="${DB_USER:-dontlift}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETAIN_DAYS="${RETAIN_DAYS:-14}"
STAMP="$(date +%F_%H%M%S)"

mkdir -p "$BACKUP_DIR"

docker exec -t "$PG_CONTAINER" \
  pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_DIR/dontlift_${STAMP}.sql.gz"

echo "[$(date +%F\ %T)] 备份完成：$BACKUP_DIR/dontlift_${STAMP}.sql.gz"

# 清理过期备份
find "$BACKUP_DIR" -name 'dontlift_*.sql.gz' -mtime +"$RETAIN_DAYS" -delete
echo "[$(date +%F\ %T)] 已清理 ${RETAIN_DAYS} 天前的旧备份"
