#!/usr/bin/env bash
# 在「本地 Mac」执行：rsync 推送 backend/ 到服务器，再远程触发 server-bootstrap.sh。
# 前置：能免密 ssh 登录服务器（建议用 root）。
# 用法：./deploy/local-deploy.sh <ssh_user>@<server_ip>
set -euo pipefail

TARGET="${1:?用法: $0 <ssh_user>@<server_ip>}"
REMOTE_DIR="/opt/DontLift-app/backend"
HERE="$(cd "$(dirname "$0")/.." && pwd)"   # 指向 backend/

echo "==> 确保远程目录存在并可写"
ssh "$TARGET" 'sudo mkdir -p /opt/DontLift-app && sudo chown -R $(id -un):$(id -gn) /opt/DontLift-app'

echo "==> rsync 推送 backend/（排除构建产物与机密）"
rsync -avz --delete \
  --exclude '.gradle' --exclude 'build' --exclude '.idea' \
  --exclude '.env.prod' --exclude 'backups' --exclude 'secrets' \
  "$HERE/" "$TARGET:$REMOTE_DIR/"

echo "==> 远程执行 server-bootstrap.sh"
ssh "$TARGET" "bash $REMOTE_DIR/deploy/server-bootstrap.sh"

echo "==> 完成。如需从本地验证，可建 SSH 隧道后 curl："
echo "    ssh -L 8080:localhost:8080 $TARGET   # 另需服务器临时映射，或直接看上面 health 结果"
