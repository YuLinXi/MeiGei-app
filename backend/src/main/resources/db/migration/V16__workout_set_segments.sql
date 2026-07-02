-- 递减组分段：set 本身仍是逻辑组，segments 存该组内的重量/次数流水。
-- 旧记录默认空数组，客户端按普通组兼容。
ALTER TABLE workout_set
    ADD COLUMN segments jsonb NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE workout_set
    ADD CONSTRAINT ck_workout_set_segments_array
        CHECK (jsonb_typeof(segments) = 'array');
