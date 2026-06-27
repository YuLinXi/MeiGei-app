CREATE INDEX idx_checkin_team_date_created_at
ON team_checkin (team_id, checkin_date DESC, created_at DESC);
