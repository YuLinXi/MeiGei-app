## 1. iOS 端数据模型与统计口径

- [x] 1.1 为 `WorkoutUnitKind` 增加 `dropSet`，并提供普通组、递减组、超级组三选一的领域 helper 和 invariant 校验
- [x] 1.2 将热身语义从 `WorkoutSetType.warmup` 迁移为独立 `isWarmup` 标记，并保留旧 raw 值读取兜底
- [x] 1.3 更新 `WorkoutSet.countsForStats`、`statEntries`、`summaryWeightReps` 等 helper，使递减组按有效 segments 计 N 组且热身整体排除
- [x] 1.4 更新普通组、超级组、递减组的完成状态和热身状态辅助方法，确保超级组热身按整轮同步
- [x] 1.5 更新本地 fixtures、测试数据和模型解码路径，移除旧“普通 set 内递减组”产品语义

## 2. iOS 端训练录入 UI

- [x] 2.1 将训练页底部入口改为「结构菜单图标 + 添加动作」，结构菜单二级提供「递减组 / 超级组」
- [x] 2.2 移除普通动作卡内「递减组」快速添加入口，以及组级菜单中的「改为递减组 / 改回普通组」
- [x] 2.3 移除超级组「解除超级组」入口，保留同类型内的编辑、增减组和删除能力
- [x] 2.4 实现递减组训练单元卡片：动作选择、segments 录入、整体完成、整体删除、整体热身、组后休息
- [x] 2.5 更新超级组卡片热身交互，使某一组热身时两个成员 set 同步标记
- [x] 2.6 更新训练结束确认、完成摘要和详情页，组数展示使用统一统计 entry 数量

## 3. iOS 端计划与自适应回写

- [x] 3.1 为 `PlanUnitKind` 增加 `dropSet`，并定义递减组计划单元的动作、segments、热身和摘要字段
- [x] 3.2 更新计划详情底部入口为「结构菜单图标 + 添加动作」，递减组/超级组从二级菜单创建
- [x] 3.3 移除计划处方编辑里的普通组/递减组互相切换入口，改为创建后类型不可变
- [x] 3.4 更新从计划开始训练逻辑：普通组、递减组、超级组按同类型生成训练单元并真实落值
- [x] 3.5 更新自适应模式历史预填和完成后回写：只回写同类型实绩，递减组按 segments 数量计组
- [x] 3.6 更新保存为计划、Fork 和 Team 分享计划的递减组结构保留与重量清空逻辑

## 4. iOS 端展示面与派生数据

- [x] 4.1 更新训练首页周统计、总组数、总次数、训练量、PR 和历史曲线，统一使用新 `statEntries`
- [x] 4.2 更新训练详情、动作详情、PR 展示和历史摘要，使递减组热身不破 PR，递减组正式 segments 可破 PR
- [x] 4.3 更新训练分享海报，递减组展示内部组摘要且组数按有效 segments 计算
- [x] 4.4 更新 Team checkin summary 解析与详情展示，保留 `dropSet` 训练单元、segments 和热身标记
- [x] 4.5 更新可访问性文案和中文 UI 文案，将超级组相关“轮”统一为“组”，递减组/普通组/超级组序号颜色保持一致

## 5. 后端与同步

- [x] 5.1 检查 Workout 聚合 DTO 和后端实体，确保训练单元 `dropSet`、`isWarmup` 与 segments 可原样 push/pull
- [x] 5.2 如 schema 需要，新增 Flyway 迁移保存 `is_warmup` 或对应 JSON 字段，保持默认 false
- [x] 5.3 更新 Team checkin summary 生成逻辑，组数按统一统计 entry 口径计算，并透传递减组结构
- [x] 5.4 更新 Team 分享计划脱敏逻辑，递减组计划单元和旧 payload 内所有重量字段都被清空
- [x] 5.5 增加后端测试覆盖 Workout 同步、Team summary 组数和 Team 计划递减组脱敏

## 6. 验证

- [x] 6.1 运行 `openspec validate --changes reframe-drop-set-as-training-unit --strict`
- [x] 6.2 运行后端 `./gradlew test`
- [x] 6.3 运行 iOS simulator build，确认 SwiftData 模型、同步 DTO 和训练 UI 编译通过
- [x] 6.4 手动验证普通组、递减组、超级组新增路径、热身标记、删除路径和不可互转
- [x] 6.5 手动验证递减组 3 个有效 segments 在首页、完成页、详情、海报、Team 中都计为 3 组
