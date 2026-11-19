-- 09 | Data quality: missing parameters and placeholder values
--
-- Question answered:
--   What share of the data is unusable before any analysis starts?
--
-- Why this belongs in a product analytics repo at all:
--   Every conversion rate downstream inherits whatever is broken here. If a fifth of
--   traffic-source values are placeholders, channel attribution is wrong by that much
--   and no amount of careful funnel work fixes it. Reporting the number alongside the
--   analysis is the difference between a figure a team can act on and one they have
--   to re-check.
--
-- Note on this specific dataset:
--   Google documents that the sample is obfuscated and that some fields carry
--   placeholder values including <Other>, NULL and empty strings. So the share found
--   here reflects the obfuscation, not a real tracking defect at the source. The
--   query is written the way it would be written against a live property.
--
-- A note on reading an empty result:
--   The missing-parameter check below returns zeros on this dataset, because the
--   sample has been cleaned. Zero is a result, not a failure. If a query like this
--   returns no rows at all, strip filters from the bottom up (HAVING first, then
--   WHERE) to find which condition removed them.

-- 9a | Required parameters present on every event?
SELECT
  event_name,
  COUNT(*) AS events,
  COUNTIF((SELECT value.int_value
           FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NULL) AS missing_session_id,
  COUNTIF((SELECT value.string_value
           FROM UNNEST(event_params) WHERE key = 'page_location') IS NULL) AS missing_page_location
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20210131'
GROUP BY event_name
ORDER BY events DESC;

-- 9b | Placeholder and blank values in the dimensions used for segmentation
SELECT
  COUNT(*) AS total_events,
  COUNTIF(geo.country IS NULL OR geo.country IN ('', '(not set)'))                       AS country_blank,
  COUNTIF(geo.country = '<Other>')                                                       AS country_other,
  COUNTIF(traffic_source.source IS NULL OR traffic_source.source IN ('', '(not set)'))   AS source_blank,
  COUNTIF(traffic_source.source = '<Other>')                                             AS source_other,
  COUNTIF(device.operating_system IS NULL OR device.operating_system = '')               AS os_blank
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20210131';
