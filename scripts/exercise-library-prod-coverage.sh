#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-root@124.222.79.121}"
TMP_DIR="$(mktemp -d -t dontlift-exercise-coverage.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

WORKOUT_CSV="$TMP_DIR/workout_refs.csv"
PLAN_CSV="$TMP_DIR/plan_refs.csv"

ssh "$HOST" "docker exec -i shared-postgres psql -v ON_ERROR_STOP=1 -U dontlift -d dontlift -q" > "$WORKOUT_CSV" <<'SQL'
COPY (
  SELECT
    CASE WHEN we.builtin_exercise_code IS NULL THEN 'custom' ELSE 'builtin' END AS kind,
    COALESCE(we.builtin_exercise_code, '') AS code,
    we.exercise_name AS exercise_name,
    COUNT(DISTINCT we.workout_id) AS workout_count,
    COUNT(ws.id) AS set_count
  FROM workout_exercise we
  JOIN workout w ON w.id = we.workout_id
  LEFT JOIN workout_set ws ON ws.workout_exercise_id = we.id
  WHERE w.deleted_at IS NULL
  GROUP BY kind, code, we.exercise_name
  ORDER BY workout_count DESC, set_count DESC, we.exercise_name
) TO STDOUT WITH CSV HEADER;
SQL

ssh "$HOST" "docker exec -i shared-postgres psql -v ON_ERROR_STOP=1 -U dontlift -d dontlift -q" > "$PLAN_CSV" <<'SQL'
COPY (
  WITH plan_items AS (
    SELECT item
    FROM workout_plan p
    CROSS JOIN LATERAL jsonb_array_elements(p.items) AS item
    WHERE p.deleted_at IS NULL
  )
  SELECT
    CASE
      WHEN item ? 'builtinExerciseCode' AND NULLIF(item->>'builtinExerciseCode','') IS NOT NULL THEN 'builtin'
      WHEN item ? 'customExerciseId' AND NULLIF(item->>'customExerciseId','') IS NOT NULL THEN 'custom'
      ELSE 'snapshot'
    END AS kind,
    COALESCE(item->>'builtinExerciseCode', '') AS code,
    COALESCE(item->>'exerciseName', item->>'displayExerciseName', '') AS exercise_name,
    COUNT(*) AS plan_item_count
  FROM plan_items
  GROUP BY kind, code, exercise_name
  ORDER BY plan_item_count DESC, exercise_name
) TO STDOUT WITH CSV HEADER;
SQL

node "$(dirname "$0")/exercise-library-v1.mjs" coverage "$WORKOUT_CSV" "$PLAN_CSV"
