-- 10 | Data quality: purchase event integrity
--
-- Question answered:
--   Can the revenue numbers be trusted?
--
-- Why these two checks specifically:
--   Purchase tracking fails in two recognisable ways. Either the event arrives without
--   the fields that make it countable (no transaction id, no revenue, empty item list),
--   or the same purchase arrives more than once, usually because the confirmation page
--   fires the event again on reload or on a back-navigation. The second failure inflates
--   revenue silently and is the reason analytics revenue and finance revenue disagree.
--
-- What to do with the result:
--   A non-zero duplicate count means every revenue figure in the product analytics
--   stack is overstated until purchase events are deduplicated by transaction id.
--   That is a release-blocking finding, not a footnote.

-- 10a | Are purchase events complete?
SELECT
  COUNT(*)                                                              AS purchase_events,
  COUNTIF(ecommerce.transaction_id IS NULL OR ecommerce.transaction_id = '') AS no_transaction_id,
  COUNTIF(ecommerce.purchase_revenue IS NULL)                           AS no_revenue,
  COUNTIF(ecommerce.purchase_revenue = 0)                               AS zero_revenue,
  COUNTIF(ARRAY_LENGTH(items) = 0)                                      AS empty_item_list
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20210131'
  AND event_name = 'purchase';

-- 10b | Is the same transaction reported more than once?
SELECT
  ecommerce.transaction_id,
  COUNT(*) AS times_reported
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20210131'
  AND event_name = 'purchase'
  AND ecommerce.transaction_id IS NOT NULL
GROUP BY ecommerce.transaction_id
HAVING times_reported > 1
ORDER BY times_reported DESC
LIMIT 50;
