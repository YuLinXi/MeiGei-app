-- 每组休息回填：预计休息秒数用于后续正式组默认值继承，真实休息秒数用于训练页与历史展示。
-- 旧记录保持 NULL，客户端按 nil 兼容。
ALTER TABLE workout_set ADD COLUMN planned_rest_seconds int;
ALTER TABLE workout_set ADD COLUMN actual_rest_seconds int;

ALTER TABLE workout_set
    ADD CONSTRAINT ck_workout_set_planned_rest_seconds_nonnegative
        CHECK (planned_rest_seconds IS NULL OR planned_rest_seconds >= 0),
    ADD CONSTRAINT ck_workout_set_actual_rest_seconds_nonnegative
        CHECK (actual_rest_seconds IS NULL OR actual_rest_seconds >= 0);
