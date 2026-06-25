#!/usr/bin/env bash
# DontLift iOS 真机局域网联调配置脚本
#
# 用法（在仓库根目录执行）：
#   ./scripts/ios-device-lan-dev.sh apply    # AppConfig.localhost 切到 Mac 局域网 IP
#   ./scripts/ios-device-lan-dev.sh restore  # AppConfig.localhost 恢复为 localhost
#   ./scripts/ios-device-lan-dev.sh status   # 查看当前配置与后端 health
#
# 可用环境变量：
#   LAN_IP=192.168.1.23   手动指定 Mac 局域网 IP，跳过自动检测
#   PORT=8001             后端端口，默认 8001

if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$REPO_DIR/ios/DontLift/DontLift/Networking/AppConfig.swift"
APP_PORT="${PORT:-8001}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERR]${NC}   $*" >&2; }

usage() {
  cat <<'EOF'
用法：./scripts/ios-device-lan-dev.sh {apply|restore|status}

命令：
  apply    将 AppConfig 的 .localhost 后端地址改为 http://<Mac局域网IP>:8001
  restore  将 AppConfig 的 .localhost 后端地址恢复为 http://localhost:8001
  status   查看当前 AppConfig 地址，并检查 /actuator/health

示例：
  ./backend/scripts/dev-start.sh
  ./scripts/ios-device-lan-dev.sh apply
  # Xcode 选择已连接真机，Run DontLift
  ./scripts/ios-device-lan-dev.sh restore

环境变量：
  LAN_IP=192.168.1.23  手动指定 Mac 局域网 IP
  PORT=8001            指定后端端口，默认 8001
EOF
}

require_config() {
  if [ ! -f "$CONFIG_FILE" ]; then
    error "未找到 AppConfig.swift：$CONFIG_FILE"
    exit 1
  fi
}

is_ipv4() {
  [[ "${1:-}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
}

is_supported_url() {
  [[ "${1:-}" =~ ^http://(localhost|([0-9]{1,3}\.){3}[0-9]{1,3}):[0-9]+$ ]]
}

detect_lan_ip() {
  if [ -n "${LAN_IP:-}" ]; then
    if ! is_ipv4 "$LAN_IP"; then
      error "LAN_IP 不是 IPv4 地址：$LAN_IP"
      exit 1
    fi
    echo "$LAN_IP"
    return
  fi

  local iface=""
  iface="$(route get default 2>/dev/null | awk '/interface:/{print $2; exit}' || true)"
  if [ -n "$iface" ]; then
    local ip=""
    ip="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
    if is_ipv4 "$ip"; then
      echo "$ip"
      return
    fi
  fi

  local fallback=""
  fallback="$(ifconfig 2>/dev/null | awk '/inet / && $2 !~ /^127\./ {print $2; exit}' || true)"
  if is_ipv4 "$fallback"; then
    echo "$fallback"
    return
  fi

  error "无法自动检测 Mac 局域网 IP，请显式指定：LAN_IP=192.168.x.x $0 apply"
  exit 1
}

current_localhost_url() {
  require_config
  sed -n '/case \.localhost:/,/case \.serverIP:/p' "$CONFIG_FILE" \
    | sed -n 's/.*URL(string: "\([^"]*\)").*/\1/p' \
    | head -1
}

replace_localhost_url() {
  local new_url="$1"
  local current_url
  current_url="$(current_localhost_url)"

  if [ -z "$current_url" ]; then
    error "无法在 .localhost 分支中找到 URL(string:) 行，请先人工检查 AppConfig.swift"
    exit 1
  fi
  if ! is_supported_url "$current_url"; then
    error ".localhost 当前 URL 不是脚本支持的本地形态：$current_url"
    error "为避免误改生产/公网地址，已停止。"
    exit 1
  fi
  if ! is_supported_url "$new_url"; then
    error "目标 URL 不是脚本支持的本地形态：$new_url"
    exit 1
  fi
  if [ "$current_url" = "$new_url" ]; then
    info "AppConfig 已是目标地址：$new_url"
    return
  fi

  NEW_URL="$new_url" perl -0pi -e '
    my $new = $ENV{"NEW_URL"};
    my $count = s{(case \.localhost:\s*\n\s*return URL\(string: ")(http://(?:localhost|(?:[0-9]{1,3}\.){3}[0-9]{1,3}):[0-9]+)("\)!)}{$1$new$3}s;
    die "未能唯一替换 .localhost URL\n" unless $count == 1;
  ' "$CONFIG_FILE"

  info "AppConfig .localhost: $current_url -> $new_url"
}

health_url() {
  local base_url="$1"
  echo "${base_url%/}/actuator/health"
}

check_health() {
  local base_url="$1"
  local url
  url="$(health_url "$base_url")"
  if curl -sf --connect-timeout 2 "$url" >/dev/null 2>&1; then
    info "后端 health OK：$url"
  else
    warn "后端 health 不通：$url"
    warn "确认 Mac 与 iPhone 同一局域网、后端已启动、macOS 防火墙未拦截。"
  fi
}

cmd_apply() {
  local ip
  ip="$(detect_lan_ip)"
  local target_url="http://${ip}:${APP_PORT}"
  replace_localhost_url "$target_url"
  check_health "$target_url"
  info "现在可在 Xcode 选择已连接真机运行 DontLift。"
  info "联调结束后执行：./scripts/ios-device-lan-dev.sh restore"
}

cmd_restore() {
  local target_url="http://localhost:${APP_PORT}"
  replace_localhost_url "$target_url"
  info "已恢复模拟器/本机 localhost 联调配置。"
}

cmd_status() {
  local current_url
  current_url="$(current_localhost_url)"
  if [ -z "$current_url" ]; then
    error "无法读取当前 .localhost URL"
    exit 1
  fi

  echo "AppConfig .localhost = $current_url"
  case "$current_url" in
    http://localhost:*)
      info "当前为模拟器/本机 localhost 配置。"
      ;;
    http://*)
      info "当前为真机局域网配置。"
      ;;
  esac
  check_health "$current_url"
}

case "${1:-}" in
  apply)   cmd_apply ;;
  restore) cmd_restore ;;
  status)  cmd_status ;;
  -h|--help|help) usage ;;
  *)
    usage
    exit 1
    ;;
esac
