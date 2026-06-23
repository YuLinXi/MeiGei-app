-- 同步增量 pull 需要包含软删墓碑，不能只依赖 deleted_at IS NULL 的局部索引。
CREATE INDEX idx_custom_ex_user_updated ON custom_exercise (user_id, updated_at);
CREATE INDEX idx_plan_user_updated ON workout_plan (user_id, updated_at);
CREATE INDEX idx_workout_user_updated ON workout (user_id, updated_at);

-- 删除训练时按 (user_id, workout_id) 移除 Team 打卡。
CREATE INDEX idx_checkin_user_workout ON team_checkin (user_id, workout_id);
