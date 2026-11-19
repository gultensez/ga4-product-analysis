# Product analytics on GA4 event data in BigQuery

Ten documented SQL queries that take raw GA4 event export data and answer the
questions a product team actually asks: where users drop out of a flow, who comes
back, which segments behave differently, and whether the underlying tracking can be
trusted in the first place.

Built against Google's public GA4 sample dataset, which uses the same export schema
as any Firebase or GA4 property, so the queries transfer to live app data with only
the table name changed.

---

## Dataset

`bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

Three months of obfuscated GA4 event export from the Google Merchandise Store,
2020-11-01 to 2021-01-31, one table per day. Google notes that the sample is
obfuscated and that some fields carry placeholder values, which is accounted for
in the data quality queries rather than ignored.

## Running these yourself

1. Open the [BigQuery sandbox](https://console.cloud.google.com/bigquery). No credit
   card or billing account is needed; the free tier covers everything here.
2. In Query settings, set a maximum bytes billed limit. These queries are scoped to
   one month and cost far less than the monthly free allowance, but the habit is worth
   having.
3. Paste any file from `sql/` and run it. Files 09 and 10 contain two statements each;
   run them one at a time, or highlight one and use Run selection.

---

## What is in here

| File | Question it answers |
| --- | --- |
| `01_event_inventory.sql` | Which events fire, how often, and for how many users? |
| `02_dau_new_vs_returning.sql` | How many users are active daily, and how much is new traffic? |
| `03_funnel_unordered.sql` | Where in the purchase flow do users drop out? |
| `04_funnel_ordered.sql` | How many follow the flow in the intended sequence? |
| `05_retention_cohorts.sql` | Of users acquired on a given day, who returns on D1 and D7? |
| `06_conversion_by_segment.sql` | Does any device or OS segment convert materially worse? |
| `07_ab_test_aa_check.sql` | Does the experiment assignment method produce balanced groups? |
| `08_param_type_inventory.sql` | Which event parameter uses which value type? |
| `09_tracking_qa_placeholders.sql` | What share of the data is missing or placeholder? |
| `10_tracking_qa_ecommerce.sql` | Are purchase events complete, and are any counted twice? |

Every file carries a header explaining the question, the technique, and what the
query deliberately does not claim.

---

## Findings

> Replace each bracketed placeholder with the number your run produced, then delete
> this note. Keep the sentences short and state the implication, not the SQL.

**Funnel.** Of the users who viewed an item, `[x]%` added to cart, `[x]%` of those
began checkout, and `[x]%` of those completed a purchase. The largest proportional
drop is at `[step]`, which is where `[n]` users are lost.

**Ordered versus unordered.** Enforcing sequence reduces the completed-funnel count
from `[n]` to `[n]`, meaning `[x]%` of converting users did not follow the steps in
order. `[One sentence on what that suggests about how people actually shop.]`

**Retention.** Classic D1 retention averages `[x]%` and D7 `[x]%` across cohorts.
Low, and expected for a merchandise store measured on web: purchase frequency is
inherently low, and browser cookie churn understates returning users. The shape
matters more than the level here, and the curve `[does / does not]` flatten.

**Segments.** `[Segment]` converts from cart to purchase at `[x]%` against `[x]%`
for `[segment]`. `[One sentence: is this a bug, a platform issue, or expected?]`

**A/A check.** The two randomly assigned groups converted at `[x]%` and `[x]%`, a
gap of `[x]` points on `[n]` users, so the assignment method is `[sound / suspect]`.

**Data quality.** `[x]%` of events carry a placeholder traffic source, so any
channel-level conversion analysis is incomplete by that margin. Purchase events are
`[complete / missing fields]`, and `[n]` transaction ids appear more than once,
which would overstate revenue by `[x]%` if purchases were not deduplicated.

---

## Caveats and what I would do differently with production data

**Web data measures retention badly.** `user_pseudo_id` comes from a browser cookie.
Clearing cookies, switching device or switching browser all mint a new id, and
Safari's ITP caps JavaScript-set cookies at 7 days, so a returning Safari user looks
like a new one from day 8 onward. On app data from a Firebase export the same queries
are far more reliable.

**Retention definition is not comparable by default.** These queries use classic
N-day retention, meaning active on exactly day N. Range and rolling retention both
report higher numbers for the identical product, which is the main reason published
benchmark tables disagree with each other. Any benchmark comparison has to match
definitions first.

**Cohorts are cut short on purpose.** D7 cohorts stop at 2021-01-20 because the data
ends on 2021-01-31. Including later cohorts would report false zeros and produce a
retention chart that collapses at the right edge.

**The funnel is defined, not discovered.** These steps assume a linear path. In a real
product the first job would be to confirm with the team whether a step can be skipped
by design, because an optional step always looks like a catastrophic drop-off.

**Retention is not always the right metric.** For a utility app that is opened once a
month by design, daily retention measures the wrong thing. Weekly or monthly cohorts,
and for subscription products the renewal rate, describe the business more honestly.

**Cost control is part of writing the query.** Every query filters on `_TABLE_SUFFIX`
with a constant expression so BigQuery prunes the daily tables before reading any
data. Filtering on `event_date` instead returns the same rows while scanning every
table in the dataset, and `LIMIT` reduces nothing at all.

---

## Next

A small Looker Studio dashboard over the DAU, funnel and retention queries, so the
output is readable without opening BigQuery.
