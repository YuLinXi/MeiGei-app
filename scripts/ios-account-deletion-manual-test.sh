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
iOS 账号删除与 Team owner 转移回归手测脚本

前置条件：
1. 后端已跑到最新 Flyway 迁移，包含 team.owner_transferred_at 字段。
2. 准备账号 A（Team owner）与账号 B（成员），二者同在 Team A。
3. 账号 B 至少发过一条 Team checkin，账号 A 可看到该动态。

场景 1：删除账号确认文案
1. 账号 A 打开「我的」页，点击“删除账号”。
2. 观察二次确认文案。
预期：文案说明本人训练数据会永久删除；多人 Team 将保留并自动转移队长；不再写“解散多人 Team”。

场景 2：owner 删号后成员历史保留
1. 账号 A 确认删除账号。
2. 使用账号 B 重新进入 Team A。
预期：Team A 仍存在；账号 B 之前的 checkin/reaction 仍在 feed 中；账号 A 自己的 checkin/reaction 不再出现。

场景 3：新 owner 接管提示
1. 账号 B 首次进入被转移后的 Team A 详情页。
预期：顶部显示“已接管 Team”提示；点击“知道了”后该设备不再重复显示。

场景 4：普通成员删号不影响 Team
1. 另建 Team C，账号 A 为 owner，账号 B 为普通成员。
2. 账号 B 删除账号。
3. 账号 A 进入 Team C。
预期：Team C 仍由账号 A 管理；其他成员历史保留；账号 B 本人的 checkin/reaction 被删除。

可选执行：
./scripts/ios-account-deletion-manual-test.sh --build
CHECKLIST
