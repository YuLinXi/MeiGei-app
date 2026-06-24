-- 修复既有明显未来 updated_at，避免旧设备时钟污染后续 LWW 冲突裁决。
DO $$
DECLARE
    clamp_time timestamptz := now();
    affected int;
BEGIN
    UPDATE custom_exercise
    SET updated_at = clamp_time
    WHERE updated_at > clamp_time + interval '5 minutes';
    GET DIAGNOSTICS affected = ROW_COUNT;
    RAISE NOTICE 'sync timestamp clamp custom_exercise rows=%', affected;

    UPDATE workout_plan_group
    SET updated_at = clamp_time
    WHERE updated_at > clamp_time + interval '5 minutes';
    GET DIAGNOSTICS affected = ROW_COUNT;
    RAISE NOTICE 'sync timestamp clamp workout_plan_group rows=%', affected;

    UPDATE workout_plan
    SET updated_at = clamp_time
    WHERE updated_at > clamp_time + interval '5 minutes';
    GET DIAGNOSTICS affected = ROW_COUNT;
    RAISE NOTICE 'sync timestamp clamp workout_plan rows=%', affected;

    UPDATE workout
    SET updated_at = clamp_time
    WHERE updated_at > clamp_time + interval '5 minutes';
    GET DIAGNOSTICS affected = ROW_COUNT;
    RAISE NOTICE 'sync timestamp clamp workout rows=%', affected;
END $$;
