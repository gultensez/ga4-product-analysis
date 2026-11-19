-- 01 | Event inventory
--
-- Question answered:
--   Which events fire, how often, and how many users trigger each one?
--
-- Why this runs first:
--   Every funnel, retention and conversion query in this repo is built on these
--   event names. On a new property this is the query to run before anything else,
--   because an event that is missing here cannot be measured anywhere else.
--
-- What to look at:
--   events_per_user tells you the nature of each event. A value close to 1 means
--   it fires once per user (first_visit). A high value means it fires repeatedly
--   (page_view, user_engagement) and must never be counted as a user count.
--
-- Cost note:
--   _TABLE_SUFFIX restricts the scan to the 31 daily tables of January 2021
--   instead of all 92 in the dataset. The filter must be a constant expression
--   or BigQuery cannot prune the tables and scans everything.

SELECT
  event_name,
  COUNT(*)                                            AS events,
  COUNT(DISTINCT user_pseudo_id)                      AS users,
  ROUND(COUNT(*) / COUNT(DISTINCT user_pseudo_id), 2) AS events_per_user
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20210131'
GROUP BY event_name
ORDER BY events DESC;
