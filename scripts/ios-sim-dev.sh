#!/usr/bin/env bash
# DontLift iOS 模拟器联调一键脚本
#
# 解决「DEBUG 连 localhost:8001 被 ATS 拦」后的模拟器侧联调闭环：
#   boot 模拟器 → 编译(关签名) → 安装 → 启动 App，并附 simctl push 样例与 dev token helper。
#
# 用法（在仓库根目录执行）：
#   ./scripts/ios-sim-dev.sh up                 # 编译+安装+启动 App 到模拟器（自动 boot）
#   ./scripts/ios-sim-dev.sh push reaction      # 注入「表情回应」样例推送（emoji/checkinId）
#   ./scripts/ios-sim-dev.sh push checkin       # 注入「队友打卡」样例推送（teamId）
#   ./scripts/ios-sim-dev.sh token              # 调后端 /auth/dev/token 造测试用户+JWT（需后端已起）
#   ./scripts/ios-sim-dev.sh status             # 看后端/模拟器状态
#
# 前置：后端需先起（另开终端跑 ./backend/scripts/dev-start.sh，它已注入 APP_DEV_TOKEN=true）。
# 可用环境变量覆盖：SIM_DEVICE（默认 "iPhone 17 Pro"）、PORT（默认 8001）。
#
# 必须真机、本脚本不覆盖的：真实 APNs 远程投递、Watch Smart Stack、TestFlight 灰度。
# simctl push 只验证「客户端收到推送后的路由/处理」，不经过后端 Pushy→APNs 真链路。

if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi
set -euo pipefail

# ---- 配置 ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IOS_DIR="$REPO_DIR/ios/DontLift"
SCHEME="DontLift"
BUNDLE_ID="com.yulinxi.app.DontLift"
SIM_DEVICE="${SIM_DEVICE:-iPhone 17 Pro}"
APP_PORT="${PORT:-8001}"
DERIVED="$IOS_DIR/build/sim-dd"
APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/DontLift.app"

# ---- 颜色 ----
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERR]${NC}   $*" >&2; }

# ---- 确保目标模拟器已 boot ----
ensure_sim() {
  if ! xcrun simctl list devices available | grep -q "$SIM_DEVICE ("; then
    error "未找到可用模拟器：${SIM_DEVICE}（用 SIM_DEVICE=... 覆盖，或 xcrun simctl list devices 查看）"
    exit 1
  fi
  local state
  state="$(xcrun simctl list devices | grep "$SIM_DEVICE (" | head -1 | sed -E 's/.*\((Booted|Shutdown|[A-Za-z]+)\).*/\1/')"
  if [ "$state" != "Booted" ]; then
    info "boot 模拟器：$SIM_DEVICE"
    xcrun simctl boot "$SIM_DEVICE" >/dev/null 2>&1 || true
  else
    info "模拟器已 boot：$SIM_DEVICE"
  fi
  open -a Simulator >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$SIM_DEVICE" -b >/dev/null 2>&1 || true
}

backend_up() { curl -sf "http://localhost:$APP_PORT/actuator/health" >/dev/null 2>&1; }

cmd_up() {
  ensure_sim
  info "编译（Debug / iphonesimulator / 关签名）..."
  xcodebuild -project "$IOS_DIR/DontLift.xcodeproj" -scheme "$SCHEME" \
    -sdk iphonesimulator -destination "platform=iOS Simulator,name=$SIM_DEVICE" \
    -configuration Debug -derivedDataPath "$DERIVED" \
    CODE_SIGNING_ALLOWED=NO build | tail -3
  if [ ! -d "$APP_PATH" ]; then error "未找到产物：$APP_PATH"; exit 1; fi
  info "安装到模拟器..."
  xcrun simctl install "$SIM_DEVICE" "$APP_PATH"
  info "启动 App（${BUNDLE_ID}）..."
  xcrun simctl launch "$SIM_DEVICE" "$BUNDLE_ID" >/dev/null
  if backend_up; then
    info "后端在线（localhost:${APP_PORT}）；App 内 DEBUG 可走 dev 登录。"
  else
    warn "后端未在线：另开终端跑 ./backend/scripts/dev-start.sh，否则登录/同步连不上。"
  fi
}

cmd_push() {
  local kind="${1:-}"
  local payload
  payload="$(mktemp -t dontlift-push).apns"
  case "$kind" in
    reaction)
      cat > "$payload" <<'JSON'
{
  "aps": { "alert": { "title": "收到表情回应", "body": "队友给你的打卡点了 💪" }, "sound": "default" },
  "checkinId": "demo-checkin-0000-0000-000000000000",
  "emoji": "muscle"
}
JSON
      ;;
    checkin)
      cat > "$payload" <<'JSON'
{
  "aps": { "alert": { "title": "队友打卡", "body": "有人刚完成了今天的训练" }, "sound": "default" },
  "teamId": "demo-team-0000-0000-0000-000000000000"
}
JSON
      ;;
    *)
      error "用法：$0 push reaction|checkin"; exit 1 ;;
  esac
  ensure_sim
  info "向 ${BUNDLE_ID} 注入「${kind}」样例推送（仅验客户端路由，不经真实 APNs）..."
  xcrun simctl push "$SIM_DEVICE" "$BUNDLE_ID" "$payload"
  rm -f "$payload"
  info "已发送。App 应据 userInfo 路由：reaction→.dontliftReactionReceived / checkin→.dontliftCheckinReceived"
}

cmd_token() {
  if ! backend_up; then error "后端未在线（localhost:${APP_PORT}）：先跑 ./backend/scripts/dev-start.sh"; exit 1; fi
  info "POST /auth/dev/token（造测试用户 + JWT，需 APP_DEV_TOKEN=true 启动的后端）"
  curl -sf -X POST "http://localhost:$APP_PORT/auth/dev/token" | (command -v jq >/dev/null && jq . || cat)
  echo ""
}

cmd_status() {
  echo "模拟器：$SIM_DEVICE"
  xcrun simctl list devices | grep "$SIM_DEVICE (" | head -1 || true
  if backend_up; then info "后端：在线（localhost:${APP_PORT}）"; else warn "后端：离线（跑 ./backend/scripts/dev-start.sh）"; fi
}

case "${1:-}" in
  up)     cmd_up ;;
  push)   shift; cmd_push "${1:-}" ;;
  token)  cmd_token ;;
  status) cmd_status ;;
  *)
    echo "用法：$0 {up|push reaction|push checkin|token|status}"
    echo "  up      编译+安装+启动 App 到模拟器"
    echo "  push    注入样例推送（reaction/checkin）"
    echo "  token   调 /auth/dev/token 造测试用户"
    echo "  status  查后端/模拟器状态"
    exit 1 ;;
esac
