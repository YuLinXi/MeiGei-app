-- Team 计划分享闭环：分享线索、不可变版本快照、最小化反馈事件。
-- Team 域为服务端权威；个人计划仍是 workout_plan 同步实体。

ALTER TABLE workout_plan ADD COLUMN forked_from_share_version_id uuid;
ALTER TABLE workout ADD COLUMN source_share_id uuid;
ALTER TABLE workout ADD COLUMN source_share_version_id uuid;
ALTER TABLE workout ADD COLUMN source_plan_name_snapshot text;

CREATE TABLE team_plan_share (
    id                uuid PRIMARY KEY,
    team_id           uuid NOT NULL REFERENCES team(id),
    owner_user_id     uuid NOT NULL REFERENCES app_user(id),
    source_plan_id    uuid,
    title             text NOT NULL,
    latest_version_id uuid,
    created_at        timestamptz NOT NULL,
    updated_at        timestamptz NOT NULL,
    deleted_at        timestamptz,
    version           int NOT NULL DEFAULT 0
);

CREATE INDEX idx_team_plan_share_team
    ON team_plan_share (team_id, updated_at DESC)
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX uq_team_plan_share_source_active
    ON team_plan_share (team_id, owner_user_id, source_plan_id)
    WHERE source_plan_id IS NOT NULL AND deleted_at IS NULL;

CREATE TABLE team_plan_share_version (
    id                 uuid PRIMARY KEY,
    share_id           uuid NOT NULL REFERENCES team_plan_share(id) ON DELETE CASCADE,
    version_number     int NOT NULL,
    plan_name_snapshot text NOT NULL,
    mode               text NOT NULL DEFAULT 'adaptive' CHECK (mode IN ('strict', 'adaptive')),
    items              jsonb NOT NULL DEFAULT '[]'::jsonb,
    created_at         timestamptz NOT NULL,
    CONSTRAINT uq_team_plan_share_version UNIQUE (share_id, version_number)
);

CREATE INDEX idx_team_plan_share_version_share
    ON team_plan_share_version (share_id, version_number DESC);

CREATE TABLE team_plan_share_event (
    id          uuid PRIMARY KEY,
    team_id     uuid NOT NULL REFERENCES team(id),
    share_id    uuid NOT NULL REFERENCES team_plan_share(id) ON DELETE CASCADE,
    version_id  uuid NOT NULL REFERENCES team_plan_share_version(id) ON DELETE CASCADE,
    user_id     uuid NOT NULL REFERENCES app_user(id),
    event_type  text NOT NULL CHECK (event_type IN ('fork', 'direct_start', 'complete')),
    workout_id  uuid,
    event_date  date,
    created_at  timestamptz NOT NULL
);

CREATE INDEX idx_team_plan_share_event_share_type
    ON team_plan_share_event (share_id, event_type, user_id);

CREATE INDEX idx_team_plan_share_event_week
    ON team_plan_share_event (share_id, event_type, event_date)
    WHERE event_type = 'complete';

CREATE UNIQUE INDEX uq_team_plan_share_event_workout
    ON team_plan_share_event (version_id, event_type, user_id, workout_id)
    WHERE workout_id IS NOT NULL;

-- 迁移旧 workout_plan.shared_to_team_id 语义为 v1 分享版本。
CREATE OR REPLACE FUNCTION _dontlift_uuid_from_text(input text) RETURNS uuid
LANGUAGE sql IMMUTABLE AS $$
    SELECT (
        substr(md5(input), 1, 8) || '-' ||
        substr(md5(input), 9, 4) || '-' ||
        substr(md5(input), 13, 4) || '-' ||
        substr(md5(input), 17, 4) || '-' ||
        substr(md5(input), 21, 12)
    )::uuid
$$;

INSERT INTO team_plan_share (
    id, team_id, owner_user_id, source_plan_id, title, latest_version_id,
    created_at, updated_at, deleted_at, version
)
SELECT
    _dontlift_uuid_from_text('team-plan-share:' || p.id::text),
    p.shared_to_team_id,
    p.user_id,
    p.id,
    p.name,
    _dontlift_uuid_from_text('team-plan-share-version:' || p.id::text || ':1'),
    p.created_at,
    p.updated_at,
    NULL,
    0
FROM workout_plan p
WHERE p.shared_to_team_id IS NOT NULL
  AND p.deleted_at IS NULL
ON CONFLICT DO NOTHING;

INSERT INTO team_plan_share_version (
    id, share_id, version_number, plan_name_snapshot, mode, items, created_at
)
SELECT
    _dontlift_uuid_from_text('team-plan-share-version:' || p.id::text || ':1'),
    _dontlift_uuid_from_text('team-plan-share:' || p.id::text),
    1,
    p.name,
    COALESCE(NULLIF(p.mode, ''), 'adaptive'),
    CASE
        WHEN jsonb_typeof(p.items) = 'array' THEN (
            SELECT COALESCE(jsonb_agg(item - 'suggestedWeightKg' - 'suggestedWeight' ORDER BY ord), '[]'::jsonb)
            FROM jsonb_array_elements(p.items) WITH ORDINALITY AS arr(item, ord)
        )
        ELSE '[]'::jsonb
    END,
    p.updated_at
FROM workout_plan p
WHERE p.shared_to_team_id IS NOT NULL
  AND p.deleted_at IS NULL
ON CONFLICT DO NOTHING;

DROP FUNCTION _dontlift_uuid_from_text(text);
