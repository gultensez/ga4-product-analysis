-- 04 | Purchase funnel, order enforced
--
-- Question answered:
--   How many users move through the purchase flow in the intended sequence?
--
-- Technique:
--   Instead of boolean flags, take the first timestamp of each step per user, then
--   require each step to happen strictly after the previous one. Comparisons against
--   NULL evaluate to NULL, which COUNTIF does not count, so users who skipped a step
--   drop out automatically without any extra IS NOT NULL guard.
--
-- How to read the result:
--   Compare these numbers with 03_funnel_unordered.sql. The gap between the two is a
--   measure of how closely users follow the intended path. A large gap usually means
--   either that the flow is non-linear by design (a "buy now" button that skips the
--   cart) or that users browse in loops rather than progressing.

WITH user_timings AS (
  SELECT
    user_pseudo_id,
    MIN(IF(event_name = 'view_item',      event_timestamp, NULL)) AS t_view_item,
    MIN(IF(event_name = 'add_to_cart',    event_timestamp, NULL)) AS t_add_to_cart,
    MIN(IF(event_name = 'begin_checkout', event_timestamp, NULL)) AS t_begin_checkout,
    MIN(IF(event_name = 'purchase',       event_timestamp, NULL)) AS t_purchase
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20210131'
  GROUP BY user_pseudo_id
)
SELECT
  COUNTIF(t_view_item IS NOT NULL) AS viewed_item,
  COUNTIF(t_add_to_cart > t_view_item) AS then_added_to_cart,
  COUNTIF(t_begin_checkout > t_add_to_cart
          AND t_add_to_cart > t_view_item) AS then_began_checkout,
  COUNTIF(t_purchase > t_begin_checkout
          AND t_begin_checkout > t_add_to_cart
          AND t_add_to_cart > t_view_item) AS then_purchased
FROM user_timings;
