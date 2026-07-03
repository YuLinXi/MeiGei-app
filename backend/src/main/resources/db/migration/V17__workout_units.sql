-- 一级训练单元索引：用于保留单动作/超级组结构。动作与组明细仍存规范化子表。
ALTER TABLE workout
    ADD COLUMN units jsonb NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE workout
    ADD CONSTRAINT ck_workout_units_array
        CHECK (jsonb_typeof(units) = 'array');
