## Context

`WorkoutLoggingView.finish()` 当前直接调用 `restTimer.stop()`。`stop()` 只清理计时状态、通知和 Live Activity，不产生 `CompletionEvent`，因此最后一段仍在进行的休息不会走既有 `actualRestSeconds` 回填路径。

## Goals / Non-Goals

**Goals:**

- 结束训练时，为仍在进行的最后一段休息写入当前目标总时长。
- 复用既有完成事件和回填逻辑。

**Non-Goals:**

- 不改变用户主动提前结束休息时记录真实已流逝秒数的行为。
- 不改变预计休息继承、继续休息或同步协议。

## Decisions

在停止计时器前，以该段休息的 `endDate` 作为完成时刻生成现有 `CompletionEvent`。现有计算会将事件秒数限制为 `totalDuration`，随后继续由训练页统一写入 `actualRestSeconds`。这样无需新增状态或修改数据模型。

## Risks / Trade-offs

- 结束训练中断休息时记录的是目标值，不是实际已流逝值；这是本次明确的产品规则。

## Migration Plan

随 iOS 客户端发布，无数据迁移。

## Open Questions

无。
