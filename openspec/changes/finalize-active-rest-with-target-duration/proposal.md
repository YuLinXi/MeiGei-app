## Why

用户完成最后一组后可能在休息倒计时尚未结束时直接结束训练。当前结束流程直接清空计时器，导致最后一组没有稳定的休息回填结果。

## What Changes

- 结束训练时若仍有活动休息，按该段休息当前设置的目标总时长完成回填。
- 继续沿用现有 `actualRestSeconds`、同步结构和计时停止流程。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `workout-tracking`: 明确结束训练中断最后一段休息时的回填规则。

## Impact

- iOS 休息计时器、训练结束流程及相关单元测试。
- 不涉及后端、数据库迁移、同步契约或新依赖。
