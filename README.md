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
2020-11-01 to 2021-01-31. 4.3M events, 270K users, one table per day. Google notes
that the sample is obfuscated and that some fields carry placeholder values, which
is accounted for in the data quality queries rather than ignored.

Unless stated otherwise, figures below cover January 2021.

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

### The funnel loses almost everyone before the product page

| Step | Users | Pass rate |
| --- | --- | --- |
| session_start | 93,552 | |
| view_item | 19,629 | 21.0% |
| add_to_cart | 3,832 | 19.5% |
| begin_checkout | 1,924 | 50.2% |
| purchase | 1,069 | 55.6% |

End to end, 1.14% of users with a session bought something. The two largest
proportional drops are both at the top: 79% of sessions never reach a product page
and 80% of product viewers never add anything, which is 73,923 and 15,797 users
respectively.

**The biggest drop is not automatically the biggest opportunity.** The funnel is
multiplicative, so a 10% relative improvement at any single step lifts overall
conversion by the same 10%, wherever that step sits. The real question is not which
number looks worst but which one is cheapest to move. Here the top of the funnel is
the more promising target, not because the drop is largest, but because 79% of
sessions never seeing a product suggests a traffic quality or landing experience
problem rather than a merchandising one, and those are usually addressable without
touching the product.

### One of the funnel steps is not a real step

Breaking the checkout stage down further:

| Step | Users | Pass rate |
| --- | --- | --- |
| begin_checkout | 1,924 | |
| add_shipping_info | 1,924 | 100.0% |
| add_payment_info | 1,395 | 72.5% |
| purchase | 1,069 | 76.6% |

`add_shipping_info` has exactly the same user count as `begin_checkout`, so it is not
a decision point at all; it fires alongside checkout rather than recording a user
action. Treating it as a funnel step would report a flawless 100% pass rate and hide
where the loss actually sits, which is the payment step. Of the 855 users lost after
beginning checkout, 529 drop before entering payment details and 326 after.

This is the reason a funnel should be defined with the engineers who instrumented it
rather than assembled from event names that sound sequential.

### No segment explains the drop-off

Across seven device and OS segments, `view_item` to `add_to_cart` ranges from 18.6%
to 22.2%, and `add_to_cart` to `purchase` from 23.4% to 30.7%. Nothing is an outlier.
The loss is therefore intrinsic to the flow or to visitor intent, not a
platform-specific bug, which rules out the cheapest class of explanation before any
redesign is proposed.

Mobile is marginally better than desktop at the cart stage, not worse: iOS 30.5% and
Android 30.7% against 26.6% for desktop web.

By country, purchase conversion ranges from 0.74% (India, mobile) to 1.52% (France,
desktop), with the US at 1.05% desktop and 1.21% mobile. India is the clear low
outlier on both device types while being the third largest traffic source, and is the
one segment worth a dedicated look.

### Growth is entirely acquisition

Across the first ten days of January, between 86% and 89% of daily active users were
first-time visitors, every single day. The returning count rises and falls with total
traffic rather than accumulating, so the active base is not compounding. Over the
month, 88,830 of 93,552 users triggered `first_visit`.

A DAU line like this looks like growth and is really throughput. Any slowdown in
acquisition spend would show up in active users almost immediately.

### Retention is low, and the curve does not settle

December cohorts: D1 between 4.0% and 7.1% (mean around 5.3%), D7 between 0.6% and
1.1% (mean around 0.8%).

Published mobile benchmarks put the median app near 21-25% on D1 and 8-9% on D7, but
that comparison is not fair in two directions. This is web data, where `user_pseudo_id`
is a browser cookie that resets on clearing, device switching and Safari's 7-day ITP
cap, so genuine returns are undercounted. It is also a merchandise store, where
buying a branded t-shirt twice in a week is not a behaviour anyone has.

The shape carries more signal than the level, and this curve keeps falling rather than
flattening onto a retained core. For this category that is expected rather than
alarming, but it does mean retention is the wrong headline metric for the business.
Purchase frequency and revenue per cohort would describe it better.

### The A/A check passed, and showed why it is needed

Two randomly assigned groups, no treatment applied:

| Variant | Users | Conversions | Rate |
| --- | --- | --- | --- |
| A | 47,261 | 547 | 1.157% |
| B | 47,529 | 522 | 1.098% |

That is a 5.4% relative difference produced by nothing at all. A two-proportion
z-test gives z = 0.86, p = 0.39, so the split is sound.

The more useful number falls out of the same arithmetic: at this baseline and sample
size, the minimum detectable effect at 80% power and 95% confidence is roughly a 17%
relative lift. Any A/B test run on a population this size that reports a smaller
difference is reporting noise. Knowing that before launching an experiment is what
stops a team from shipping a change on the strength of a 5% "win".

### Data quality

Three issues worth flagging before any of the above is quoted as fact:

- `operating_system` reads "Web" for 11,203 of 19,149 segmented users (58.5%), so the
  actual OS is unavailable for most traffic and OS-level analysis covers only the
  remaining 41%. A further 481 users carry the `<Other>` placeholder.
- Daily active users do not fully decompose into new plus returning. Between 26 and 79
  users per day, roughly 1-2%, have a `user_first_touch_timestamp` later than the day
  they were active, which cannot happen. Consistent with the documented obfuscation
  here, but in a live property it would point to broken first-touch assignment.
- `purchase` fires 1,204 times for 1,069 distinct buyers. That is either repeat
  purchasing or duplicate events, and the two have opposite implications for revenue.
  `10_tracking_qa_ecommerce.sql` separates them, and should be run before any revenue
  figure is published.

---

## Warnings and what I would do differently with production data

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

**The funnel is defined, not discovered.** The `add_shipping_info` result above is the
evidence: a step that passes 100% of users is not measuring a user decision. In a live
product the first task would be to walk the event list with the engineers who
instrumented it and establish which events represent choices and which fire
automatically.

**Retention is not always the right metric.** For a utility product opened once a
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
