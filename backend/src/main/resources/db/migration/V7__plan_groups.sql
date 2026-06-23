-- 计划分组：独立同步实体，支持分组排序与空分组保留。
CREATE TABLE workout_plan_group (
    id         uuid PRIMARY KEY,
    user_id    uuid NOT NULL REFERENCES app_user(id),
    name       text NOT NULL,
    sort_order int NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    version    int NOT NULL DEFAULT 0
);

-- 计划归属与组内排序。group_id 不加外键，容忍离线同步乱序和分组墓碑。
ALTER TABLE workout_plan ADD COLUMN group_id uuid;
ALTER TABLE workout_plan ADD COLUMN sort_order int NOT NULL DEFAULT 0;

CREATE INDEX idx_plan_group_user_order
    ON workout_plan_group (user_id, sort_order, updated_at)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_plan_user_group_order
    ON workout_plan (user_id, group_id, sort_order, updated_at)
    WHERE deleted_at IS NULL;
