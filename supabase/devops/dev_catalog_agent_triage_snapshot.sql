-- DEV-ONLY Catalog Governance Agent daily work packet smoke test.
--
-- Run only against Season-dev (`gyuedxycbnqljryenapx`) while the agent is
-- being developed. Do not run against staging unless the agent branch is
-- explicitly promoted.

SELECT
  current_database() AS database_name,
  current_user AS role_name,
  now() AS checked_at;

-- Small packet for quick inspection.
SELECT public.get_catalog_agent_triage_snapshot(
  p_limit := 10,
  p_source_domain := NULL,
  p_include_non_new := false
) AS catalog_agent_triage_snapshot;

-- Summary-only view of the packet size and policy marker.
WITH packet AS (
  SELECT public.get_catalog_agent_triage_snapshot(
    p_limit := 25,
    p_source_domain := NULL,
    p_include_non_new := false
  ) AS payload
)
SELECT
  payload #>> '{metadata,source}' AS source,
  (payload #>> '{metadata,item_count}')::integer AS item_count,
  payload #>> '{metadata,environment_policy}' AS environment_policy,
  payload #>> '{policy,core_principle}' AS core_principle
FROM packet;
