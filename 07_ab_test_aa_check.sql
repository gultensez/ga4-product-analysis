-- 07 | A/A sanity check on the experiment assignment method
--
-- Question answered:
--   If I split this population into two groups with no treatment applied, do the two
--   groups report the same conversion rate?
--
-- Why an A/A test:
--   This dataset contains no real experiment, so instead of inventing one, this query
--   validates the assignment mechanism itself. Running an A/A test before a real A/B
--   test is standard practice: if two identical groups already differ, any difference
--   the real test reports is not trustworthy. A meaningful gap here would point to
--   broken assignment, a biased hash, or a sample too small to detect the effect size
--   you care about.
--
-- Technique:
--   FARM_FINGERPRINT is deterministic, so a given user always lands in the same
--   bucket. That property is what makes it usable for real variant assignment, where
--   a user flipping between variants across sessions would invalidate the test.
--
-- What is deliberately not here:
--   No p-value. A significance test needs a stated minimum detectable effect and a
--   pre-declared sample size, decided before the experiment runs, not computed
--   afterwards to see whether the result clears a threshold.

WITH assignment AS (
  SELECT
    user_pseudo_id,
    IF(MOD(ABS(FARM_FINGERPRINT(user_pseudo_id)), 2) = 0, 'A', 'B') AS variant,
    LOGICAL_OR(event_name = 'purchase') AS converted
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20210131'
  GROUP BY user_pseudo_id, variant
)
SELECT
  variant,
  COUNT(*)         AS users,
  COUNTIF(converted) AS conversions,
  ROUND(100 * COUNTIF(converted) / COUNT(*), 3) AS conversion_pct
FROM assignment
GROUP BY variant
ORDER BY variant;
