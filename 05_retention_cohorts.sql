-- 05 | Day-1 and Day-7 retention by acquisition cohort
--
-- Question answered:
--   Of the users first seen on a given day, what share came back exactly 1 and
--   exactly 7 days later?
--
-- Definition used (this matters):
--   Classic N-day retention, meaning active on exactly day N. The two other common
--   definitions, range retention (active at any point between day 1 and day N) and
--   rolling retention (active on day N or later), both produce substantially higher
--   numbers for the same product. Any comparison against a published benchmark is
--   meaningless unless the definition matches.
--
-- Why the cohort window is cut short:
--   Cohorts are capped at 2021-01-20 because the dataset ends on 2021-01-31. A cohort
--   formed on 2021-01-28 has no day 7 inside the data, so including it would report a
--   false zero and produce a retention chart that collapses at the right edge. This is
--   the most common error in hand-built retention queries.
--
-- Expected result on this dataset:
--   Low, and legitimately so. This is a merchandise store, not a daily-use product,
--   and web cookie churn understates returns. The method is the deliverable here,
--   not the number.

WITH first_day AS (
  SELECT
    user_pseudo_id,
    DATE(TIMESTAMP_MICROS(user_first_touch_timestamp)) AS cohort_day
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131'
  GROUP BY user_pseudo_id, cohort_day
),
activity AS (
  SELECT DISTINCT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS active_day
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20210131'
)
SELECT
  f.cohort_day,
  COUNT(DISTINCT f.user_pseudo_id) AS cohort_size,
  ROUND(100 * COUNT(DISTINCT IF(DATE_DIFF(a.active_day, f.cohort_day, DAY) = 1,
                                f.user_pseudo_id, NULL))
        / COUNT(DISTINCT f.user_pseudo_id), 1) AS d1_pct,
  ROUND(100 * COUNT(DISTINCT IF(DATE_DIFF(a.active_day, f.cohort_day, DAY) = 7,
                                f.user_pseudo_id, NULL))
        / COUNT(DISTINCT f.user_pseudo_id), 1) AS d7_pct
FROM first_day f
JOIN activity a USING (user_pseudo_id)
WHERE f.cohort_day BETWEEN DATE '2020-12-01' AND DATE '2021-01-20'
GROUP BY f.cohort_day
ORDER BY f.cohort_day;
