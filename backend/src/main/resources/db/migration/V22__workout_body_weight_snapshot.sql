ALTER TABLE workout
    ADD COLUMN body_weight_kg_at_completion double precision
    CHECK (body_weight_kg_at_completion IS NULL OR body_weight_kg_at_completion BETWEEN 30 AND 250);
