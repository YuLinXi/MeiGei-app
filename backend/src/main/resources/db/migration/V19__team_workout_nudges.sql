ALTER TABLE team_member
    ADD COLUMN receive_workout_nudges boolean NOT NULL DEFAULT true;

CREATE TABLE team_nudge (
    id                uuid PRIMARY KEY,
    team_id           uuid NOT NULL REFERENCES team(id) ON DELETE CASCADE,
    sender_user_id    uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    recipient_user_id uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    nudge_date        date NOT NULL,
    created_at        timestamptz NOT NULL,
    CONSTRAINT ck_team_nudge_not_self CHECK (sender_user_id <> recipient_user_id),
    CONSTRAINT uq_team_nudge_daily UNIQUE (team_id, sender_user_id, recipient_user_id, nudge_date)
);

CREATE INDEX idx_team_nudge_sender_date
    ON team_nudge (sender_user_id, nudge_date, recipient_user_id);

CREATE INDEX idx_team_nudge_recipient_date
    ON team_nudge (recipient_user_id, nudge_date);
