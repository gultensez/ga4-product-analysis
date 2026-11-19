-- 03 | Purchase funnel, unordered
--
-- Question answered:
--   Of the users who reach each stage of the purchase flow, how many reach the next?
--
-- Technique, and why it is two layers:
--   The raw table holds one row per event, so a user who viewed twelve products has
--   twelve view_item rows. A funnel counts people, not events. The CTE collapses all
--   of a user's rows into a single row of boolean flags with LOGICAL_OR ("did this
--   user ever do X"), and the outer query counts how many users have each flag set.
--
-- What this query does NOT claim:
--   LOGICAL_OR only asks whether an event happened, not whether it happened in order.
--   A user who added to cart and then browsed another product is counted at both
--   stages. There is also no session boundary: viewing on Monday and buying on Friday
--   counts as one conversion. See 04_funnel_ordered.sql for the stricter version and
--   compare the two results.

WITH user_steps AS (
  SELECT
    user_pseudo_id,
    LOGICAL_OR(event_name = 'session_start')  AS s1_session,
    LOGICAL_OR(event_name = 'view_item')      AS s2_view_item,
    LOGICAL_OR(event_name = 'add_to_cart')    AS s3_add_to_cart,
    LOGICAL_OR(event_name = 'begin_checkout') AS s4_begin_checkout,
    LOGICAL_OR(event_name = 'purchase')       AS s5_purchase
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20210131'
  GROUP BY user_pseudo_id
)
SELECT
  COUNTIF(s1_session)        AS session_start,
  COUNTIF(s2_view_item)      AS view_item,
  COUNTIF(s3_add_to_cart)    AS add_to_cart,
  COUNTIF(s4_begin_checkout) AS begin_checkout,
  COUNTIF(s5_purchase)       AS purchase,
  ROUND(100 * COUNTIF(s3_add_to_cart)    / NULLIF(COUNTIF(s2_view_item), 0), 1)      AS view_to_cart_pct,
  ROUND(100 * COUNTIF(s4_begin_checkout) / NULLIF(COUNTIF(s3_add_to_cart), 0), 1)    AS cart_to_checkout_pct,
  ROUND(100 * COUNTIF(s5_purchase)       / NULLIF(COUNTIF(s4_begin_checkout), 0), 1) AS checkout_to_purchase_pct,
  ROUND(100 * COUNTIF(s5_purchase)       / NULLIF(COUNTIF(s1_session), 0), 2)        AS overall_conversion_pct
FROM user_steps;
