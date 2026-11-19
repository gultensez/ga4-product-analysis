-- 02 | Daily active users, split into new and returning
--
-- Question answered:
--   How many users are active each day, and how much of that is first-time traffic?
--
-- Why it matters:
--   A DAU line that climbs while being almost entirely new users means acquisition
--   is working and the product is not. The split is more informative than the total,
--   which is why this query reports both rather than a single number.
--
-- Technique:
--   event_date is stored as a STRING ('20210115'), so PARSE_DATE converts it.
--   user_first_touch_timestamp is in microseconds, so TIMESTAMP_MICROS converts it.
--   Both patterns recur throughout the GA4 export schema.
--
-- Known limitation:
--   This is web data. user_pseudo_id comes from a browser cookie, so clearing
--   cookies, switching browser or switching device creates a new id. Safari's ITP
--   caps JavaScript-set cookies at 7 days, which inflates the new-user count.
--   The same query on app data (Firebase export) is far more reliable.

WITH daily AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date)                   AS day,
    user_pseudo_id,
    DATE(TIMESTAMP_MICROS(user_first_touch_timestamp)) AS first_seen
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20210131'
)
SELECT
  day,
  COUNT(DISTINCT user_pseudo_id)                             AS dau,
  COUNT(DISTINCT IF(day = first_seen, user_pseudo_id, NULL)) AS new_users,
  COUNT(DISTINCT IF(day > first_seen, user_pseudo_id, NULL)) AS returning_users
FROM daily
GROUP BY day
ORDER BY day;
