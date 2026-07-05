-- 热身标记从 set_type 中拆出，set_type 只保留结构类型（working/drop）。
ALTER TABLE workout_set
    ADD COLUMN is_warmup boolean NOT NULL DEFAULT false;

UPDATE workout_set
SET is_warmup = true,
    set_type = 'working'
WHERE set_type = 'warmup';
