-- 训练计划整体备注 + Team 分享版本备注快照
ALTER TABLE workout_plan ADD COLUMN note text;
ALTER TABLE team_plan_share_version ADD COLUMN plan_note_snapshot text;
