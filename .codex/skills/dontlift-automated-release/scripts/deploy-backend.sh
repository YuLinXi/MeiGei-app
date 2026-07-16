#!/usr/bin/env bash
# GitHub Actions 后端部署包装器：复用现行 release-update.sh，并在无 migration 变更时提供应用镜像回滚。
set -euo pipefail

TARGET="${PROD_SSH_TARGET:?缺少 PROD_SSH_TARGET}"
HEALTH_URL="${PROD_HEALTH_URL:?缺少 PROD_HEALTH_URL}"
RELEASE_ID="${RELEASE_ID:?缺少 RELEASE_ID}"
MIGRATION_CHANGED="${MIGRATION_CHANGED:-true}"
REMOTE_DIR="/opt/DontLift-app/backend"
ROLLBACK_IMAGE="dontlift-app:rollback-${RELEASE_ID}"

old_image="$(ssh "$TARGET" "docker inspect --format='{{.Image}}' dontlift-app")"
ssh "$TARGET" "docker image tag '$old_image' '$ROLLBACK_IMAGE'"

if bash backend/deploy/release-update.sh "$TARGET" "$HEALTH_URL"; then
  printf '后端部署完成；保留回滚镜像 %s 供本次发布观察期使用\n' "$ROLLBACK_IMAGE"
  exit 0
fi

printf '新后端部署失败，检查当前公网 health\n' >&2
if curl --fail --silent --max-time 15 "$HEALTH_URL" | grep -q '"status":"UP"'; then
  printf '线上仍为 UP，旧容器可能未被替换；保留失败状态和日志，不重复部署\n' >&2
  exit 1
fi

if [ "$MIGRATION_CHANGED" = "true" ]; then
  printf '本次包含 migration，不能证明旧应用与新 schema 兼容，停止自动回滚\n' >&2
  exit 1
fi

printf '无 migration 变更，恢复上一应用镜像 %s\n' "$ROLLBACK_IMAGE" >&2
ssh "$TARGET" "cat > /tmp/dontlift-rollback-${RELEASE_ID}.yml <<'YAML'
services:
  app:
    image: $ROLLBACK_IMAGE
YAML
cd '$REMOTE_DIR' && docker compose \
  -f docker-compose.prod.yml \
  -f /tmp/dontlift-rollback-${RELEASE_ID}.yml \
  --env-file .env.prod up -d --no-build --force-recreate app"

for attempt in $(seq 1 30); do
  if curl --fail --silent --max-time 10 "$HEALTH_URL" | grep -q '"status":"UP"'; then
    printf '上一应用镜像已恢复，原发布仍标记失败\n' >&2
    exit 1
  fi
  sleep 5
done

printf '上一应用镜像恢复后仍未通过 health，需要人工事故处理\n' >&2
exit 1
