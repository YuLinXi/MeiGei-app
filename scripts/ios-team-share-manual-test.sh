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
iOS Team 分享回归手测脚本

前置条件：
1. 后端以 APP_DEV_TOKEN=true 启动，至少准备一个测试账号。
2. 测试账号加入 Team A 与 Team B；Team feed 页面可正常加载。
3. iOS 使用 Debug 构建登录同一测试账号。

场景 1：默认不开启自动分享
1. 确认 Team A / Team B 详情中的“训练完成后自动分享”均为关闭。
2. 开始并结束一次训练。
3. 分别进入 Team A / Team B feed。
预期：两个 Team 都不出现这次训练；个人训练历史仍保留。

场景 2：首次开启 Team A 自动分享
1. 进入 Team A 详情，打开“训练完成后自动分享”。
2. 在首次确认弹窗中确认开启。
3. 再完成一次训练。
4. 查看 Team A / Team B feed。
预期：Team A 出现这次训练；Team B 不出现；摘要与组数/容量一致；训练结束时不再出现强制分享 sheet；自动分享成功提示从底部出现，不遮挡顶部返回按钮。

场景 3：关闭后不再分享
1. 回到 Team A 详情，关闭“训练完成后自动分享”。
2. 再完成一次训练。
3. 查看 Team A / Team B feed。
预期：本次训练不出现在 Team A / Team B；之前已分享的历史不会因关闭偏好自动删除。

场景 4：离线自动分享排队并同步后重试
1. 开启 Team A 自动分享，并确认该偏好已保存。
2. 断网或停止后端后完成一次训练。
3. 恢复网络或重启后端，触发一次同步完成。
预期：App 显示 Team 自动分享已排队；同步成功后 Team A 出现该训练，重复同步不产生重复 checkin。

场景 5：按 Team 撤回
1. 开启 Team A 与 Team B 自动分享后完成一次训练。
2. 进入 Team A feed，点击该训练卡片上的“撤回”。
3. 在二次确认弹窗中点击“取消”。
4. 再次点击“撤回”，在二次确认弹窗中确认。
5. 刷新 Team A / Team B feed，并检查个人训练历史。
预期：Team A 不再显示该训练及其 reaction；Team B 仍显示；个人训练历史未删除。

可选执行：
./scripts/ios-team-share-manual-test.sh --build
CHECKLIST
