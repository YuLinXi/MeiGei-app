CREATE TABLE checkin_reaction_push_receipt (
    id         uuid PRIMARY KEY,
    checkin_id uuid NOT NULL REFERENCES team_checkin(id) ON DELETE CASCADE,
    user_id    uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL,
    CONSTRAINT uq_checkin_reaction_push_receipt UNIQUE (checkin_id, user_id)
);

CREATE INDEX idx_reaction_push_receipt_user ON checkin_reaction_push_receipt (user_id);
