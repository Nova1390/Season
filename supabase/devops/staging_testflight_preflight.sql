-- STAGING-ONLY preflight checklist before TestFlight upload.
-- Run against the staging project (`czdsnnsizyhldiurlmxd`) with a read-capable role.

-- 1) Confirm connection context.
SELECT
  current_database() AS database_name,
  current_user AS role_name,
  now() AS checked_at;

-- 2) Recipe source distribution. TestFlight staging should be curated,
-- with Giallo Zafferano as the selected public recipe source.
SELECT
  coalesce(nullif(trim(source_name), ''), '(missing)') AS source_name,
  coalesce(nullif(trim(source_type), ''), '(missing)') AS source_type,
  count(*)::bigint AS recipe_count
FROM public.recipes
GROUP BY 1, 2
ORDER BY recipe_count DESC, source_name;

-- 3) Sources that violate the current TestFlight content policy.
SELECT
  id,
  title,
  source_name,
  source_url,
  source_type,
  created_at
FROM public.recipes
WHERE lower(coalesce(source_name, '')) LIKE '%themealdb%'
   OR lower(coalesce(source_url, '')) LIKE '%themealdb%'
   OR lower(coalesce(source_type, '')) LIKE '%seed%'
ORDER BY created_at DESC, title;

-- 4) Ingredient resolution coverage for Giallo Zafferano recipes.
WITH expanded AS (
  SELECT
    r.id AS recipe_id,
    r.title,
    r.source_name,
    ingredient.value AS ingredient_json
  FROM public.recipes r
  CROSS JOIN LATERAL jsonb_array_elements(r.ingredients) AS ingredient(value)
  WHERE lower(coalesce(r.source_name, '')) LIKE '%giallozafferano%'
     OR lower(coalesce(r.source_url, '')) LIKE '%giallozafferano%'
),
classified AS (
  SELECT
    recipe_id,
    title,
    ingredient_json,
    nullif(trim(ingredient_json ->> 'ingredient_id'), '') AS ingredient_id,
    nullif(trim(ingredient_json ->> 'produce_id'), '') AS produce_id,
    nullif(trim(ingredient_json ->> 'basic_ingredient_id'), '') AS basic_ingredient_id,
    nullif(trim(coalesce(
      ingredient_json ->> 'name',
      ingredient_json ->> 'custom_name',
      ingredient_json ->> 'rawIngredientLine',
      ingredient_json ->> 'raw_ingredient_line'
    )), '') AS display_name
  FROM expanded
)
SELECT
  count(*)::bigint AS ingredient_rows,
  count(*) FILTER (WHERE ingredient_id IS NOT NULL)::bigint AS canonical_rows,
  count(*) FILTER (WHERE ingredient_id IS NULL AND (produce_id IS NOT NULL OR basic_ingredient_id IS NOT NULL))::bigint AS legacy_rows,
  count(*) FILTER (WHERE ingredient_id IS NULL AND produce_id IS NULL AND basic_ingredient_id IS NULL)::bigint AS unresolved_rows
FROM classified;

-- 5) Top unresolved Giallo Zafferano ingredient texts to fix before deploy.
WITH expanded AS (
  SELECT
    r.id AS recipe_id,
    r.title,
    ingredient.value AS ingredient_json
  FROM public.recipes r
  CROSS JOIN LATERAL jsonb_array_elements(r.ingredients) AS ingredient(value)
  WHERE lower(coalesce(r.source_name, '')) LIKE '%giallozafferano%'
     OR lower(coalesce(r.source_url, '')) LIKE '%giallozafferano%'
),
classified AS (
  SELECT
    recipe_id,
    title,
    nullif(trim(ingredient_json ->> 'ingredient_id'), '') AS ingredient_id,
    nullif(trim(ingredient_json ->> 'produce_id'), '') AS produce_id,
    nullif(trim(ingredient_json ->> 'basic_ingredient_id'), '') AS basic_ingredient_id,
    nullif(trim(coalesce(
      ingredient_json ->> 'name',
      ingredient_json ->> 'custom_name',
      ingredient_json ->> 'rawIngredientLine',
      ingredient_json ->> 'raw_ingredient_line'
    )), '') AS display_name
  FROM expanded
)
SELECT
  coalesce(display_name, '(missing ingredient text)') AS ingredient_text,
  count(*)::bigint AS occurrences,
  array_agg(DISTINCT title ORDER BY title) FILTER (WHERE title IS NOT NULL) AS example_recipe_titles
FROM classified
WHERE ingredient_id IS NULL
  AND produce_id IS NULL
  AND basic_ingredient_id IS NULL
GROUP BY 1
ORDER BY occurrences DESC, ingredient_text
LIMIT 50;

-- 6) Catalog app-readiness summary exposed to the app.
SELECT *
FROM public.ingredient_catalog_app_readiness_summary;

-- 7) Open catalog observation/candidate pressure.
SELECT
  status,
  count(*)::bigint AS observation_count,
  sum(occurrence_count)::bigint AS total_occurrences
FROM public.custom_ingredient_observations
GROUP BY status
ORDER BY total_occurrences DESC NULLS LAST, status;

-- 8) Staging autopilot scheduler status.
DO $$
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS _staging_autopilot_scheduler_status (
    jobid bigint,
    jobname text,
    schedule text,
    active boolean,
    status text
  ) ON COMMIT DROP;

  DELETE FROM _staging_autopilot_scheduler_status;

  IF to_regclass('cron.job') IS NULL THEN
    RAISE NOTICE 'cron.job relation not found; staging autopilot scheduler is not installed/enabled';
    INSERT INTO _staging_autopilot_scheduler_status (
      jobid,
      jobname,
      schedule,
      active,
      status
    )
    VALUES (
      NULL,
      'staging_catalog_autopilot_v2_q6h',
      NULL,
      false,
      'cron.job relation not found'
    );
  ELSE
    EXECUTE $query$
      INSERT INTO _staging_autopilot_scheduler_status (
        jobid,
        jobname,
        schedule,
        active,
        status
      )
      SELECT
        j.jobid,
        j.jobname,
        j.schedule,
        j.active,
        'configured'::text
      FROM cron.job j
      WHERE j.jobname = 'staging_catalog_autopilot_v2_q6h'
    $query$;
  END IF;
END $$;

SELECT *
FROM _staging_autopilot_scheduler_status;
