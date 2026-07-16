## Context

`WorkoutExercise.displaySortedSets` 当前按「热身优先、段内 `setIndex` 升序」派生展示顺序；键盘前后跳转、下一组推荐与休息策略也复用这份展示序。`WorkoutExercise.toggleWarmup(_:)` 除了切换热身状态，还会把目标组的 `setIndex` 写成当前最大值加一，因此一次分类操作同时改变了稳定组序。

训练组属于 `Workout` 同步聚合子树，`setIndex`、`setTypeRaw` 与 `isWarmup` 随 workout 整树同步。本变更不新增实体、字段或写接口，不影响身份三层、幂等键、同步信封、LWW 或软删除约定。

## Goals / Non-Goals

**Goals:**

- 热身标记只改变组的热身语义，不改变稳定 `setIndex`。
- 热身组继续整体吸顶，同段组继续按 `setIndex` 保持相对顺序。
- 正式组标热身再取消后恢复原位置，连续两次切换不产生顺序漂移。
- 旧 `setTypeRaw == "warmup"` 记录可通过一次切换正确变成正式组。
- 「加一组」预填、键盘跳转、下一组推荐和休息策略继续使用现有顺序派生，无需各自增加补丁。

**Non-Goals:**

- 不新增组内拖拽排序、位置选择器或新的持久化顺序字段。
- 不迁移无法还原原始位置的旧 `setIndex`。
- 不改变统计、同步、计划热身处方、超级组热身或递减组热身规则。

## Decisions

### D1. `setIndex` 是稳定原序，热身状态只参与展示分段

保留现有展示排序：

```text
display order = (isWarmupEffective 优先, setIndex 升序)
```

切换时不再重写 `setIndex`。这样原生热身组取消后会按其原始序进入正式段；中间正式组临时标热身再取消，则回到原正式组位置。

备选方案是取消热身时固定插入正式段头部。该方案虽然符合训练阶段边界，但误标后撤销无法恢复原位，除非新增额外位置快照，复杂度与收益不匹配。

### D2. 以有效热身状态计算切换目标

切换前先读取 `isWarmupEffective`，目标状态取反，再把 `setTypeRaw == "warmup"` 归一为结构类型 `working`。不能直接对 `isWarmup` 物理字段执行 toggle，因为旧记录可能是 `isWarmup == false` 且 `setTypeRaw == "warmup"`；直接 toggle 会在清理 raw 后仍保持热身。

不在读取路径批量迁移旧数据。用户编辑时就地归一即可，避免无关历史记录写入和同步噪声。

### D3. 不增加专用排序状态或调用方修补

`displaySortedSets` 已是展示和执行导航的共享派生入口，领域模型修正后，视图、键盘、下一组推荐与休息策略会自然得到一致顺序。调用方继续只负责 `markDirty` 和保存。

测试直接覆盖领域 helper，并验证取消热身不会改变 `lastWorkingSetValues` 的最后正式组来源。无需 UI snapshot 或端到端手势测试。

## Risks / Trade-offs

- [Risk] 旧版本已经把某些组的 `setIndex` 移到末尾，原位置不可推断。
  → Mitigation：不猜测、不迁移；新规则只保证升级后的切换不再继续漂移。
- [Risk] 排序改变会间接影响下一组推荐和休息继承。
  → Mitigation：继续以共享 `displaySortedSets` 为唯一展示序，并运行现有休息策略测试。
- [Risk] 旧 raw 热身记录的切换路径与新记录不同。
  → Mitigation：统一从 `isWarmupEffective` 计算目标状态，增加专门回归测试。

## Migration Plan

1. 先发布 iOS 客户端逻辑与测试；后端和数据库无需部署。
2. 已有 workout 同步数据保持兼容，下一次用户切换旧 raw 热身时自动归一该组。
3. 如需回滚，可恢复旧 toggle 行为；本变更未引入新数据格式，回滚不需要迁移。

## Open Questions

无。默认采用「分类与顺序解耦、双向切换可逆」规则。
