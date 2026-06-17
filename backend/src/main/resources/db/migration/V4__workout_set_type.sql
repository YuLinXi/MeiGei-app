-- 组类型（正式组/热身组）：workout_set 加 set_type 列。
-- 旧行回填 'working'（历史组天然全为正式组，与客户端默认一致）。
-- 判据 set_type != 'warmup' 为「正式组」，统计/PR/曲线据此排除热身组。
ALTER TABLE workout_set ADD COLUMN set_type text NOT NULL DEFAULT 'working';
