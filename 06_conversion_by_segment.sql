-- 06 | Funnel conversion broken down by device and operating system
--
-- Question answered:
--   Does any segment convert materially worse than the others?
--
-- Why segmentation comes before any product hypothesis:
--   An aggregate funnel hides the cause. If one platform or one OS version is far
--   worse than the rest, the likely explanation is a bug or a platform-specific
--   usability problem, which is fixable. If every segment looks alike, the loss is
--   intrinsic to the flow or to user intent, which is a different kind of work.
--   Running this before proposing a redesign is the difference between a hypothesis
--   and a guess.
--
-- Note on ANY_VALUE:
--   A user can appear on more than one device across sessions. ANY_VALUE picks one
--   arbitrarily, which is acceptable for a first cut but would need a defined rule
--   (first device, or last device before purchase) in production reporting.
--
-- HAVING filters out thin segments, because a 100% conversion rate off 3 users is
-- noise, not a finding.

WITH user_steps AS (
  SELECT
    user_pseudo_id,
    ANY_VALUE(device.category)         AS device_category,
    ANY_VALUE(device.operating_system) AS operating_system,
    LOGICAL_OR(event_name = 'view_item')   AS viewed,
    LOGICAL_OR(event_name = 'add_to_cart') AS added_to_cart,
    LOGICAL_OR(event_name = 'purchase')    AS purchased
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20210131'
  GROUP BY user_pseudo_id
)
SELECT
  device_category,
  operating_system,
  COUNTIF(viewed) AS viewers,
  ROUND(100 * COUNTIF(added_to_cart) / NULLIF(COUNTIF(viewed), 0), 1)        AS view_to_cart_pct,
  ROUND(100 * COUNTIF(purchased)     / NULLIF(COUNTIF(added_to_cart), 0), 1) AS cart_to_purchase_pct
FROM user_steps
GROUP BY device_category, operating_system
HAVING viewers > 300
ORDER BY viewers DESC;
