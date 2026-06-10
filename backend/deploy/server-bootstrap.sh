#!/usr/bin/env bash
# 在「服务器」上执行的幂等部署脚本（通常由本地 deploy/local-deploy.sh 经 ssh 触发）。
# 作用：装 Docker → 建共享网络 → 生成机密 → 起共享 PostgreSQL + DontLift app → 本地验证 health。
# 不做：不开 80/443、不起 Caddy（等 ICP 备案通过后再 enable-https）。
# 幂等：重复执行安全；已生成的 .env 会复用（不会重置数据库密码）。
set -euo pipefail

REPO_DIR="${REPO_DIR:-/opt/DontLift-app/backend}"
STACKS_DIR="${STACKS_DIR:-/opt/stacks}"
BUNDLE_ID="com.yulinxi.app.DontLift"

# 非 root 则用 sudo（建议直接用 root 登录，免 sudo 交互）
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; else SUDO=""; fi
log(){ printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
# 生成定长字母数字密码（去掉 base64 的 +/= 以免在 env/SQL 里转义）
gen(){ openssl rand -base64 64 | tr -dc 'A-Za-z0-9' | cut -c1-"${1:-32}"; }

# ── 1. Docker ──────────────────────────────────────────
if ! command -v docker >/dev/null 2>&1; then
  log "安装 Docker"
  curl -fsSL https://get.docker.com | $SUDO sh
else
  log "Docker 已安装，跳过"
fi
DC="$SUDO docker"

# ── 2. 共享网络 ────────────────────────────────────────
log "创建共享网络 web / dbnet（已存在则忽略）"
$DC network create web   2>/dev/null || true
$DC network create dbnet 2>/dev/null || true

# ── 3. 同步共享基础设施配置到 /opt/stacks（不碰已有 .env）──
log "同步共享 PG / Caddy 配置到 $STACKS_DIR"
$SUDO mkdir -p "$STACKS_DIR/db" "$STACKS_DIR/edge"
$SUDO cp "$REPO_DIR/deploy/shared-infra/db/docker-compose.yml"   "$STACKS_DIR/db/"
$SUDO cp -r "$REPO_DIR/deploy/shared-infra/db/init"              "$STACKS_DIR/db/"
$SUDO cp "$REPO_DIR/deploy/shared-infra/edge/docker-compose.yml" "$STACKS_DIR/edge/"
$SUDO cp "$REPO_DIR/deploy/shared-infra/edge/Caddyfile"          "$STACKS_DIR/edge/"

# ── 4. 机密（幂等：优先复用已有，保证 DB 密码两边一致）──
DB_ENV="$STACKS_DIR/db/.env"
APP_ENV="$REPO_DIR/.env.prod"

if   [ -f "$APP_ENV" ] && grep -q '^DB_PASSWORD='        "$APP_ENV"; then DB_PW="$(grep '^DB_PASSWORD='        "$APP_ENV" | cut -d= -f2-)"
elif [ -f "$DB_ENV" ]  && grep -q '^DONTLIFT_DB_PASSWORD='  "$DB_ENV";  then DB_PW="$(grep '^DONTLIFT_DB_PASSWORD='  "$DB_ENV"  | cut -d= -f2-)"
else DB_PW="$(gen 32)"; fi

if [ ! -f "$DB_ENV" ]; then
  log "生成共享 PG 机密 $DB_ENV"
  $SUDO tee "$DB_ENV" >/dev/null <<EOF
POSTGRES_SUPERPASS=$(gen 32)
DONTLIFT_DB_PASSWORD=$DB_PW
EOF
else log "复用已有 $DB_ENV"; fi

if [ ! -f "$APP_ENV" ]; then
  log "生成 DontLift 业务机密 $APP_ENV"
  $SUDO tee "$APP_ENV" >/dev/null <<EOF
DB_PASSWORD=$DB_PW
JWT_SECRET=$(gen 48)
APP_DEV_TOKEN=false
APPLE_AUDIENCES=$BUNDLE_ID
SENTRY_DSN=
SENTRY_ENV=production
APNS_KEY_PATH=/secrets/apns.p8
APNS_KEY_ID=
APNS_TEAM_ID=
APNS_TOPIC=$BUNDLE_ID
APNS_PRODUCTION=true
EOF
else log "复用已有 $APP_ENV"; fi

# ── 5. 起共享 PostgreSQL ───────────────────────────────
log "启动共享 PostgreSQL（首次会自动建 dontlift 库 + 角色）"
( cd "$STACKS_DIR/db" && $DC compose up -d )

# ── 6. 起 DontLift app（首次编译镜像较久）────────────────
log "构建并启动 DontLift app（首次 2-5 分钟）"
( cd "$REPO_DIR" && $DC compose -f docker-compose.prod.yml --env-file .env.prod up -d --build )

# ── 7. 验证 /actuator/health（经 web 网络内部访问，不开公网端口）──
log "等待 app 就绪并验证 health"
for i in $(seq 1 60); do
  if $DC run --rm --network web busybox:latest \
       wget -qO- http://dontlift-app:8080/actuator/health 2>/dev/null | grep -q '"status":"UP"'; then
    log "✅ 后端就绪：/actuator/health = UP"
    log "下一步（备案通过后）：配 DNS dontlift.peipadada.com → 本机IP，然后 cd $STACKS_DIR/edge && docker compose up -d 起 Caddy 签 HTTPS"
    exit 0
  fi
  sleep 5
done
log "⚠️ 超时未就绪。排查：cd $REPO_DIR && $DC compose -f docker-compose.prod.yml logs app"
exit 1
