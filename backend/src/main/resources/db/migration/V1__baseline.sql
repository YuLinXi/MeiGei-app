-- MeiGei 基线 schema（详见 openspec/changes/meigei-mvp/data-model.md）
-- 约定：主键 UUID v7 由应用层生成（PG16 无原生 uuidv7()）；同步信封 created_at/updated_at/deleted_at/version；
-- 软删除走 deleted_at IS NULL；枚举用 text + CHECK；被引用侧用软指针不设 FK。

-- ============================================================
-- 1. 账户与同步域
-- ============================================================

CREATE TABLE app_user (
    id                uuid PRIMARY KEY,
    display_name      text,
    first_login_email text,
    created_at        timestamptz NOT NULL,
    updated_at        timestamptz NOT NULL,
    deleted_at        timestamptz,
    version           int NOT NULL DEFAULT 0
);

CREATE TABLE user_identity (
    id               uuid PRIMARY KEY,
    user_id          uuid NOT NULL REFERENCES app_user(id),
    provider         text NOT NULL CHECK (provider IN ('apple')),
    provider_user_id text NOT NULL,
    email            text,
    created_at       timestamptz NOT NULL,
    updated_at       timestamptz NOT NULL,
    CONSTRAINT uq_identity_provider UNIQUE (provider, provider_user_id)
);
CREATE INDEX idx_identity_user ON user_identity (user_id);

CREATE TABLE idempotency_key (
    id              uuid PRIMARY KEY,
    user_id         uuid NOT NULL REFERENCES app_user(id),
    idem_key        text NOT NULL,
    request_hash    text,
    response_status int,
    response_body   jsonb,
    created_at      timestamptz NOT NULL,
    CONSTRAINT uq_idem UNIQUE (user_id, idem_key)
);

CREATE TABLE device_token (
    id          uuid PRIMARY KEY,
    user_id     uuid NOT NULL REFERENCES app_user(id),
    apns_token  text NOT NULL,
    environment text NOT NULL CHECK (environment IN ('sandbox', 'production')),
    created_at  timestamptz NOT NULL,
    updated_at  timestamptz NOT NULL,
    CONSTRAINT uq_apns_token UNIQUE (apns_token)
);
CREATE INDEX idx_device_user ON device_token (user_id);

-- ============================================================
-- 2. 训练域
-- ============================================================

CREATE TABLE custom_exercise (
    id             uuid PRIMARY KEY,
    user_id        uuid NOT NULL REFERENCES app_user(id),
    name           text NOT NULL,
    primary_muscle text NOT NULL,
    equipment_type text,
    created_at     timestamptz NOT NULL,
    updated_at     timestamptz NOT NULL,
    deleted_at     timestamptz,
    version        int NOT NULL DEFAULT 0
);
CREATE INDEX idx_custom_ex_user ON custom_exercise (user_id) WHERE deleted_at IS NULL;

CREATE TABLE workout_plan (
    id                uuid PRIMARY KEY,
    user_id           uuid NOT NULL REFERENCES app_user(id),
    name              text NOT NULL,
    items             jsonb NOT NULL DEFAULT '[]'::jsonb,
    forked_from       uuid,
    shared_to_team_id uuid,
    created_at        timestamptz NOT NULL,
    updated_at        timestamptz NOT NULL,
    deleted_at        timestamptz,
    version           int NOT NULL DEFAULT 0
);
CREATE INDEX idx_plan_user ON workout_plan (user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_plan_team ON workout_plan (shared_to_team_id) WHERE shared_to_team_id IS NOT NULL;

CREATE TABLE workout (
    id         uuid PRIMARY KEY,
    user_id    uuid NOT NULL REFERENCES app_user(id),
    plan_id    uuid,
    title      text,
    started_at timestamptz NOT NULL,
    ended_at   timestamptz,
    note       text,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    version    int NOT NULL DEFAULT 0
);
CREATE INDEX idx_workout_user_date ON workout (user_id, started_at DESC) WHERE deleted_at IS NULL;

CREATE TABLE workout_exercise (
    id                    uuid PRIMARY KEY,
    workout_id            uuid NOT NULL REFERENCES workout(id) ON DELETE CASCADE,
    user_id               uuid NOT NULL,
    builtin_exercise_code text,
    custom_exercise_id    uuid,
    exercise_name         text NOT NULL,
    primary_muscle        text,
    order_index           int NOT NULL,
    note                  text,
    CONSTRAINT ck_ex_ref CHECK (
        (builtin_exercise_code IS NOT NULL) <> (custom_exercise_id IS NOT NULL)
    )
);
CREATE INDEX idx_we_workout ON workout_exercise (workout_id);
CREATE INDEX idx_we_user_builtin ON workout_exercise (user_id, builtin_exercise_code);
CREATE INDEX idx_we_user_custom ON workout_exercise (user_id, custom_exercise_id);

CREATE TABLE workout_set (
    id                  uuid PRIMARY KEY,
    workout_exercise_id uuid NOT NULL REFERENCES workout_exercise(id) ON DELETE CASCADE,
    set_index           int NOT NULL,
    weight_kg           numeric(6, 2),
    reps                int,
    completed           boolean NOT NULL DEFAULT false,
    note                text
);
CREATE INDEX idx_set_exercise ON workout_set (workout_exercise_id);

-- ============================================================
-- 3. Team 域（服务端权威）
-- ============================================================

CREATE TABLE team (
    id            uuid PRIMARY KEY,
    name          text NOT NULL,
    owner_user_id uuid NOT NULL REFERENCES app_user(id),
    invite_code   text NOT NULL,
    created_at    timestamptz NOT NULL,
    updated_at    timestamptz NOT NULL,
    deleted_at    timestamptz,
    version       int NOT NULL DEFAULT 0,
    CONSTRAINT uq_invite_code UNIQUE (invite_code)
);

CREATE TABLE team_member (
    id        uuid PRIMARY KEY,
    team_id   uuid NOT NULL REFERENCES team(id),
    user_id   uuid NOT NULL REFERENCES app_user(id),
    role      text NOT NULL CHECK (role IN ('owner', 'member')),
    joined_at timestamptz NOT NULL,
    CONSTRAINT uq_team_user UNIQUE (team_id, user_id)
);
CREATE INDEX idx_member_user ON team_member (user_id);

CREATE TABLE team_checkin (
    id           uuid PRIMARY KEY,
    team_id      uuid NOT NULL REFERENCES team(id),
    user_id      uuid NOT NULL REFERENCES app_user(id),
    workout_id   uuid NOT NULL,
    checkin_date date NOT NULL,
    summary      jsonb NOT NULL,
    created_at   timestamptz NOT NULL,
    CONSTRAINT uq_checkin UNIQUE (team_id, user_id, workout_id)
);
CREATE INDEX idx_checkin_team_date ON team_checkin (team_id, checkin_date DESC);

CREATE TABLE checkin_reaction (
    id         uuid PRIMARY KEY,
    checkin_id uuid NOT NULL REFERENCES team_checkin(id) ON DELETE CASCADE,
    user_id    uuid NOT NULL REFERENCES app_user(id),
    emoji      text NOT NULL CHECK (emoji IN ('muscle', 'fire', 'clap', 'heart')),
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    CONSTRAINT uq_reaction UNIQUE (checkin_id, user_id)
);
CREATE INDEX idx_reaction_checkin ON checkin_reaction (checkin_id);
