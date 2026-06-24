#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${1:-}" == "--build" ]]; then
  (
    cd "$ROOT_DIR/ios/DontLift"
    xcodebuild -project DontLift.xcodeproj -scheme DontLift \
      -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
      -configuration Debug CODE_SIGNING_ALLOWED=NO build
  )
fi

cat <<'CHECKLIST'
iOS Live Activity / Watch Smart Stack 条件验收脚本

前置条件：
1. iPhone 真机已安装当前构建，并已允许通知。
2. 准备一段进行中训练，能触发 30-120 秒组间休息。
3. Watch 条件测试仅在 iOS 18+ iPhone 配对 watchOS 11+ Apple Watch 时执行。

场景 1：iPhone 锁屏 Live Activity 必测
1. 在 App 内开始组间休息。
2. 锁屏 iPhone。
预期：锁屏 Live Activity 显示剩余时间与下一个动作；倒计时以墙钟继续，不因锁屏暂停。

场景 2：Dynamic Island 必测（支持机型）
1. 在支持 Dynamic Island 的 iPhone 上开始组间休息。
2. 返回桌面或切到其他 App。
预期：灵动岛显示倒计时；点击“结束”后 Live Activity 立即消失，App 内 FAB/弹窗同步收起。

场景 3：本地通知与前台提醒必测
1. 后台或锁屏等待休息自然结束。
预期：收到本地通知并有声音。
2. App 前台再次开始短休息并等待结束。
预期：前台播放短提示音并触发触觉；不与本地通知重复响两声。

场景 4：Watch Smart Stack 条件测试
1. 若有 iOS 18+ / watchOS 11+ 配对设备，开始组间休息并保持连接。
2. 观察 Apple Watch Smart Stack。
预期：平台转呈时可看到休息 Live Activity 并可提前结束；若未出现，记录系统版本、连接状态与时间，不判定为失败。

可选执行：
./scripts/ios-live-activity-watch-manual-test.sh --build
CHECKLIST
