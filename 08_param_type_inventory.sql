-- 08 | Event parameter inventory: which key uses which value type
--
-- Question answered:
--   For every event parameter in the export, is the value stored as a string, an
--   integer, a float or a double?
--
-- Why this is the first query to run on an unfamiliar property:
--   event_params is an ARRAY of STRUCTs, and each value is itself a STRUCT with four
--   typed slots of which exactly one is populated. Reading the wrong slot returns
--   NULL silently with no error. A whole column of unexplained NULLs is almost always
--   this mistake rather than missing data, and this query is how you rule it out in
--   one step instead of guessing per parameter.
--
-- Technique:
--   CROSS JOIN UNNEST (the comma in the FROM clause) explodes the array so that each
--   parameter becomes its own row. That is the right choice here because the
--   parameters themselves are the unit of analysis. Note that row counts are no
--   longer event counts after this join, so COUNT(*) here means "parameters", not
--   "events".

SELECT
  p.key,
  COUNT(*)                                       AS occurrences,
  COUNTIF(p.value.string_value IS NOT NULL)      AS as_string,
  COUNTIF(p.value.int_value    IS NOT NULL)      AS as_int,
  COUNTIF(p.value.float_value  IS NOT NULL)      AS as_float,
  COUNTIF(p.value.double_value IS NOT NULL)      AS as_double
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
UNNEST(event_params) AS p
WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20210131'
GROUP BY p.key
ORDER BY occurrences DESC;
