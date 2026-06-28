-- 补齐 V12 旧共享计划回填中的重量字段清理，避免已迁移快照残留 weightKg/weight。

UPDATE team_plan_share_version v
SET items = cleaned.items
FROM (
    SELECT
        id,
        COALESCE(
            jsonb_agg(item - 'suggestedWeightKg' - 'suggestedWeight' - 'weightKg' - 'weight' ORDER BY ord),
            '[]'::jsonb
        ) AS items
    FROM team_plan_share_version
    CROSS JOIN LATERAL jsonb_array_elements(items) WITH ORDINALITY AS arr(item, ord)
    WHERE jsonb_typeof(items) = 'array'
    GROUP BY id
) cleaned
WHERE v.id = cleaned.id;
