CREATE TABLE checkin_reaction_push_receipt (
    id         uuid PRIMARY KEY,
    checkin_id uuid NOT NULL REFERENCES team_checkin(id) ON DELETE CASCADE,
    user_id    uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL,
    CONSTRAINT uq_checkin_reaction_push_receipt UNIQUE (checkin_id, user_id)
);

CREATE INDEX idx_reaction_push_receipt_user ON checkin_reaction_push_receipt (user_id);

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

INSERT INTO checkin_reaction_push_receipt (id, checkin_id, user_id, created_at)
SELECT
    _dontlift_uuid_from_text('checkin-reaction-push-receipt:' || r.checkin_id::text || ':' || r.user_id::text),
    r.checkin_id,
    r.user_id,
    r.created_at
FROM checkin_reaction r
JOIN team_checkin c ON c.id = r.checkin_id
WHERE r.user_id <> c.user_id
ON CONFLICT DO NOTHING;

DROP FUNCTION _dontlift_uuid_from_text(text);
