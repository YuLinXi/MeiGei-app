-- 训练计划严格/自适应模式 + 动作级计划来源 id。
-- workout_plan.mode：'strict'=照剧本执行、'adaptive'=活文档（实绩回写）。旧行回填 'adaptive'（默认，低门槛）。
-- workout_exercise.plan_item_id：来源 PlanItem.itemId，自适应回写的合并主键；nil=临时新增/旧数据。
ALTER TABLE workout_plan ADD COLUMN mode text NOT NULL DEFAULT 'adaptive';
ALTER TABLE workout_exercise ADD COLUMN plan_item_id uuid;
