ALTER TABLE team ADD COLUMN owner_transferred_at timestamptz;
ALTER TABLE team ADD COLUMN owner_transferred_from_user_id uuid;
