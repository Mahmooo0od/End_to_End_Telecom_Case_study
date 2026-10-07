# WE Telecom: Customer Value, Engagement & Risk
 
**BI Practical Assessment (Power BI, SQL, Analytics): README**
 
Data runs to 20 May 2025. The report is anchored on 30 Apr 2025, the last complete month. The data does not state a currency, so amounts are shown in the data's own units (assumed EGP).
 
---
 
## 1. Executive summary
 
**Question.** Revenue is growing. Is the growth healthy, where is the opportunity, and where is the risk?
 
**Headline.** Monthly recurring revenue rose from 1.19M (Jan-23) to 2.90M (Apr-25), about 2.4x. Paying customers grew only 32% (6.3K to 8.3K) while ARPU grew 84% (190 to 348). In Apr-25 vs Apr-24, **78% of the revenue growth came from ARPU and 22% from customer volume** (bridge: 1.96M, +0.21M volume, +0.73M ARPU, 2.90M). Growth is price/mix-led. The cause (tariff changes) is an inference, because the data has no price history.
 
**Three insights** (details in section 8):
 
1. **Growth.** 99.1% of customers sit on the 30 Mbps entry tier, and 4,757 active Class A/B+ customers are realistic upgrade candidates, worth about 335K per month at an assumed 10% conversion.
2. **Risk.** Suspensions are concentrated in the weaker classes (B, C+, C): 45% of customers but 75% of suspensions. About 113K per month of revenue is tied to suspended accounts.
3. **Risk (data and operations).** 676 "Active" customers have not paid in 3 complete months. 73% of them sit in a small group of plan families (the 46-series) that holds 6% of customers and 2% of revenue.
> **Scope warning (read first).** This analysis covers the **9,995 subscribers in `Customer.csv`**. These customers have payments, calls, plan and network data. The customers in the `Consumption` table are a **different population**: none of them appear in `Customer` (about 9.9K customers, see 4.1). They have no payments, plan, class or status, so value, risk and segmentation cannot be measured for them. All findings apply to the Customer-table population only. They must not be extrapolated to the full 19.9K customers seen across tables.
 
---
 
## 2. Assumptions
 
| # | Assumption | Why it matters |
|---|---|---|
| A1 | Population = customers in `Customer.csv` (9,995 subscribers). Consumption and Mobile_App customers are out of scope. | See scope warning. No cross-population conclusions. |
| A2 | Unit of count: dashboard = **subscriber** (9,995). SQL and RFM = **customer** (9,993 distinct `CUSTOMER_ID#`, 9,630 with payments). | Two customers hold two subscribers, so counts can differ by 1 or 2. |
| A3 | **Total Revenue = Rent + Devices + Creation fees.** Out-bundle and Tax are zero in every row. `RENT_REVENUE = IN_BUNDLE + ADDON` on every row (verified), so adding them again double counts. | Total = 54.45M. Adding all six columns gives 107.8M (+98%). |
| A4 | **Active Customer** = status `Active` AND at least one payment in the last 3 complete months (1 Feb to 30 Apr 2025). | Status alone (94.5% Active) does not separate paying from non-paying customers. |
| A5 | Trend visuals use complete months only. May-25 is partial (data stops on 20 May) and is excluded from trends but kept in totals. | Avoids a fake drop in the last month. |
| A6 | `Suspended` is the churn proxy. Status is a single current snapshot with no history. | Churn over time cannot be measured. |
| A7 | Plan = the customer's **current** plan, not the plan at payment time. | Revenue of customers who changed plan is attributed to the latest plan. |
| A8 | "46-series" = plan families whose code starts with `46` (36 families, 606 customers). Calling them "legacy" is an inference from their low revenue and payment pattern. | Needs confirmation by the product team. |
| A9 | Calls are 68% from 2021 and 26% from 2022, while payments start in 2023. | Calls are used as a customer-level engagement attribute, never aligned by month with payments. |
| A10 | AI outputs (segments, scores, model-health tables) are static exports from the notebook, scored on 21 May 2025. | They do not refresh with Power BI. Re-run the notebook to update. |
 
---
 
## 3. Deliverables and reproducibility
 
| File | Content |
|---|---|
| `*.pbix` | Model, DAX layer, 4 report pages |
| `We_Quries.sql` | Tasks 1 and 2 (plus verification queries, section 4.4) |
| `Customer_Segmentation_and_AI_Churn_Risk_.ipynb` | RFM + K-Means segmentation and the churn early-warning model |
| `telecom_rfm_segments.csv`, `churn_risk_scores.csv`, `model_lift.csv`, `model_calibration.csv`, `model_metrics.csv` | Notebook outputs loaded into the model |
| `plan_before.png`, `plan_after.png` | Execution plans for Task 2 |
 
**Reproducibility.** All cleaning is done in Power Query, so a refresh repeats it. All KPIs are DAX measures. Join keys longer than 15 digits (`CUSTOMER_ID#`, 16 to 17 digits for 3,073 customers) are kept as **text**: as numbers they lose precision, and 3,120 distinct IDs collapse to 28 values. CSV files must never be opened and re-saved in Excel, which does the same damage.
 
---
 
## 4. SQL (Tasks 1 and 2)
 
### 4.1 Task 1: one row per customer
 
- **Grain:** one row per `CUSTOMER_ID`. Each fact is aggregated to customer level first (consumption by customer, payments via subscriber, calls via service number) and only then joined, so no fact-to-fact fan-out and no inflated totals.
- **Customer list** = distinct customers from `dbo.customer` plus customers found in `Consumption`.
- **Output:** 19,887 rows = 9,993 Customer-table customers + 9,894 consumption-only customers.
- **Consequence:** the two groups never overlap. Customer-table customers have consumption = 0, and consumption-only customers have payments = 0 and calls = 0 by construction. This is the data-scope limitation in the scope warning.
- **Payments formula:** `RENT + OUT_BUNDLE + DEVICES + CREATION_FEES` (A3). `IN_BUNDLE` and `ADDON` are excluded because they are already inside `RENT`.
- **Types:** keep IDs as `BIGINT` or `VARCHAR`, never `FLOAT`. Money is summed with `TRY_CAST(... AS FLOAT)`. For production use `DECIMAL(18,2)`.
### 4.2 Task 2: optimization
 
**Query chosen:** the Task 1 query itself. `Consumption` is the largest table (158,174 logical reads) and the original reads it twice: once to build the customer list (`UNION`) and once to aggregate it.
 
| Change | What it does |
|---|---|
| 1. Aggregate before the union | `Consumption` is grouped by customer once. The union then sees one row per customer instead of one per day. |
| 2. `UNION ALL` instead of `UNION` | Removes the distinct sort/hash step. Safe only because the two populations are disjoint (verified, 4.4). |
| 3. Covering indexes | On `Consumption(CUSTOMER_ID)` including the measure, `customer(CUSTOMER_ID#)`, `Payments(SUBSCRIBER_ID)` and `calls(SERVICE_NUMBER#)`. |
 
**Measured** with `SET STATISTICS IO, TIME` (before to after, all changes together):
 
| Metric | Before | After | Change |
|---|---|---|---|
| Consumption logical reads | 158,174 | 57,774 | -63% |
| customer reads | 684 | 426 | -38% |
| Payments reads | 2,950 | 2,284 | -23% |
| calls reads | 234 | 196 | -16% |
| CPU | 10,375 ms | 9,046 ms | -13% |
| Elapsed | 2,988 ms | 2,865 ms | -4% |
 
**Execution plan difference.** Before: two scans of `Consumption` plus a Distinct (hash/sort) over the union input. After: a single ordered read of the covering index feeding a Stream Aggregate, a Concatenation (no distinct), and seeks or narrow scans on the other tables. Screenshots: `plan_before.png`, `plan_after.png`.
 
**Honest reading of the gain.** The I/O reduction is large, but elapsed time improved by only about 4%. At about 3 seconds the query is CPU-bound by float aggregation, so the benefit mainly shows as the data volume grows. Referencing the same CTE twice can re-evaluate it, so a temp table is the next step if volume grows.
 
**Teradata (skew) note.** Choose a high-cardinality primary index (`CUSTOMER_ID`, `SUBSCRIBER_ID`), never a status or class column. Check skew with `HASHAMP(HASHBUCKET(HASHROW(...)))` before building. Beware NULL-heavy join columns (`GROUP_ID#` is about 93% NULL). Give intermediate tables the same PI as the join column and collect statistics.
 
### 4.3 Correctness note
 
The optimized query uses the corrected payments formula (A3). The Task 1 query must use the same formula, otherwise its `Total_Payments` is inflated by 98% and the two versions are not equivalent.
 
### 4.4 How equivalence was verified
 
1. Row counts of both versions are equal (19,887).
2. Both result sets are loaded into temp tables and compared with `EXCEPT` in both directions: **0 rows each way**.
3. The column totals are identical: total payments **54,450,361**, total calls **17,248**, total consumption equal.
4. Disjointness check behind `UNION ALL`: an inner join of distinct `customer` IDs to distinct `Consumption` IDs returns **0 rows**.
---
 
## 5. Data model (Task 3)
 
Star schema: descriptive tables on the one side, activity tables on the many side. Facts never join to each other, only through `Customer`, so one customer cannot be multiplied by another fact.
 
| Table | Type | Grain / role |
|---|---|---|
| `Customer` | Dimension | One row per subscriber (9,995). Includes network attributes (governorate, technology) and the RFM segment. |
| `Subscription_Plan_Lkp` | Dimension | One row per plan (108), with plan family, speed, price. |
| `Calender_Table`, `Dim_Calls_Date` | Dimensions | Separate calendars: payments (2023 to 2025) and calls (mostly 2021 to 2022) do not overlap. |
| `Dim_Segment` | Dimension | Segment order, meaning and recommended action. |
| `Payments` | Fact | One row per payment record (Payment_ID) per subscriber per day (362,713 rows). |
| `Calls` | Fact | One row per call (17,248). |
| `Churn_Scores` | Fact (snapshot) | One row per scored active subscriber at 21 May 2025 (8,875). |
| `RFM_Segments` | Lookup | One row per customer with payments (9,630). Source of `Customer[RFM Segment]`. |
| `Model_Lift`, `Model_Calibration`, `Model_Metrics` | Small tables | Model-health visuals. No relationships. |
| `Consumption`, `Consumption_RG_LKP`, `Mobile_App` | Loaded, **not used** | Their customers are outside the Customer table (scope warning). No measure or visual depends on them. |
| `Upsell Rate`, `Funnel Steps`, `Bridge Table`, `Calculations` | Helpers | What-if slicer, funnel and bridge steps, measure table. |
 
**Relationships** (all one-to-many, single direction, from description to activity):
`Subscription_Plan_Lkp` to `Customer`; `Customer` to `Payments` (subscriber); `Customer` to `Calls` (service number); `Calender_Table` to `Payments` (date); `Dim_Calls_Date` to `Calls` (date); `Dim_Segment` to `Customer` (segment); `Customer` to `Churn_Scores` (subscriber).
 
**Why filtering never double counts.** Customer counts come from `Customer` only. Revenue and calls come from their own facts and reach customer, plan or date through one path. There are no bidirectional filters, so no ambiguous paths. Percentage-of-total measures remove only the category column on the axis and keep the other slicers (section 6).
 
---
 
## 6. KPI and DAX layer (Task 4)
 
**Active Customer (business definition):** status `Active` AND at least one payment in the last 3 complete months before the anchor date (A4). The anchor date is the last day of the last complete month, derived from the data, so the definition moves forward automatically with each refresh. `Dormant Customers` = status Active minus Active Customers, which is the "active on paper, not paying" group.
 
| Group | Measures | Why they matter |
|---|---|---|
| Base | Total Customers, Active Customers, Active Customers %, Suspended Customers, Suspension Rate, Dormant Customers | How many customers exist, how many are really paying, how many are lost or silent. |
| Value | Total Revenue, Recurring Revenue, In-Bundle, Add-on, Devices, Creation Fees, ARPU, Revenue per Customer, Add-on Attach Rate, Top 10% Customers Revenue Share | Value per customer. ARPU is the key lever because growth is ARPU-led. |
| Trend | Revenue PM / PY, MoM %, YoY %, Latest Month Revenue and Growth %, Bridge Value | Direction and the volume vs price split. All use complete months. |
| Share | Revenue Share %, Customer Share %, Suspended Share %, Dormant Share %, Share of Base % | Concentration. They answer where the money and the risk sit. |
| Engagement | Total Calls, Calls per 100 Customers, Contact Rate %, Repeat Caller %, Technical Calls %, Suspension Rate for callers vs non-callers | Engagement and whether service contact predicts suspension (it does not, see insight 2). |
| Opportunity | Upsell Candidates, ARPU Entry / Higher / Uplift, Higher-Tier ARPU Multiple, Upsell Conversion Rate, Upsell Revenue Potential, Funnel Value | Sizing the upgrade opportunity with an adjustable assumption. |
| Risk and AI | Revenue at Risk (Monthly), Scored and High-Risk Subscribers, Expected Revenue at Risk (60d), Model Recall Top10, Champions Revenue Share % | Money tied to risk and model-health KPIs. |
| Governance | Data Through | States the data cut-off and that trends use complete months. |
 
**Percentage-of-total behaviour.** Share measures divide by the same measure with the axis column removed, either `ALLSELECTED()` or `REMOVEFILTERS(<axis column>)`. Slicers (plan, class, governorate) stay active, so the result is correct when the user filters by Subscription Plan. Top-N visuals use `REMOVEFILTERS` on the category column, otherwise shares are computed only from the bars shown and add up to 100%. Test: Revenue Share by plan family sums to 100% with and without a plan slicer.
 
---
 
## 7. Dashboard (Task 5)
 
| Page | Question | Content |
|---|---|---|
| 1. Executive Overview | How are we doing? | Revenue, customers, active %, ARPU, suspension rate. Customers vs ARPU trend. Volume-vs-ARPU bridge. Plan-family and governorate concentration. |
| 2. Growth Opportunities | Where is the upside? | Class value vs share. ARPU by speed tier. Upgrade funnel (9,995 to 4,757 to about 476 at the assumed rate, adjustable). Fiber vs DSL. |
| 3. Risk Analysis | Where do we lose money? | Suspension by class and governorate. Dormant accounts by plan-family series. Dormant accounts by time since last payment. |
| 4. Segmentation and AI | Who are our customers and who leaves next? | RFM segments, expected revenue at risk by segment and risk band, model lift and drift. |
 
Slicers: governorate and customer class (pages 1 to 3). Year is used where it applies. Page 4 has no slicers, because segments and scores are a fixed snapshot.
 
---
 
## 8. Business insights (Task 6)
 
### Insight 1 (Growth): the base is parked on the entry tier
 
- **Finding:** 99.1% of customers are on 30 Mbps with ARPU **245**. Customers on 50 to 80 Mbps pay **762** and on 100+ Mbps **1,552**, yet together they are under 1% of the base (66 and 21 customers). 4,757 active Class A/B+ customers are on 30 Mbps.
- **Likely driver:** one plan family holds 71% of customers and there is little visible migration path. Fiber customers (GPON) earn more (302 vs 253 for VDSL) and call less (107 vs 191 calls per 100 customers) but are only 7.6% of the base.
- **Size:** at 10% conversion about **335K per month** (about 11.5% of Apr-25 revenue). A conservative figure using only the 50 to 80 Mbps uplift is about 246K. Both are upper bounds, because the higher tiers have few customers.
- **Action:** run an upgrade campaign starting with the 1,039 Class A customers (they already pay 379 on 30 Mbps vs 256 for B+), with a holdout group to measure the real conversion.
### Insight 2 (Risk): suspensions concentrate in the weaker classes
 
- **Finding:** 548 customers are suspended (5.48%). Classes B, C+ and C are **44.5% of customers but 75% of suspensions**. Suspension rate is 12.9% (C), 10.7% (C+), 7.3% (B) vs 2.2% (B+). Minya (10.4%), Qena (8.8%) and Beni Suef (8.5%) run 1.7 to 2.1x above Cairo (5.0%), based on small counts (14 to 27 suspended each).
- **Estimated exposure:** about 113K per month (3.9% of Apr-25 revenue). Suspended customers are 5.5% of the base but about 2.7% of revenue.
- **Likely driver:** affordability. This is not proven, but it is consistent with ARPU +34% year on year. Technology (4.4% to 5.7%) does not explain it. Customers who contacted the call center are suspended *less* (4.3% vs 6.2%), so calls signal engagement, not churn.
- **Action:** pilot instalment plans and proactive payment reminders for B, C+ and C customers, starting in the three governorates, with a control group.
### Insight 3 (Risk, data and operations): "Active" does not mean paying
 
- **Finding:** 676 Active-status customers have not paid in 3 complete months. **73%** sit in the 46-series plan families (6% of customers, 2% of revenue). Of the 676: 317 never paid in 29 months, 104 paid in May (late payers), and 255 genuinely stopped (last known revenue about 65K per month, 91% in the 46-series).
- **Likely driver:** old or migrated plan families whose status was not maintained, or customers lost without status updates.
- **Action:** audit the 46-series families (reactivate or close). Call the 64 customers who lapsed 3 to 6 months ago first, since they are the highest-value group (average last monthly revenue 384).
---
 
## 9. Customer segmentation (Task 7)
 
**Method.** RFM (Recency, Frequency, Monetary = payments-based) on log-scaled, standardized features, then K-Means with K = 4. The notebook shows the silhouette is highest at K = 2, but K = 4 is kept for business usability. Customers with no payments (363) cannot be scored and form a fifth, separate segment. Segments are assigned at customer level and carried to subscribers. Segment labels were checked against activation dates: 88% of "New Customers" joined in the last 12 months.
 
| Segment | Customers | Share | Revenue share | Revenue per customer | Engagement (payments per customer, days since last payment) | Interpretation | Action |
|---|---|---|---|---|---|---|---|
| Champions | 3,323 | 33.2% | 51.4% | ~8,420 | 56.7, 6 days | Long-tenure (median about 5 years), frequent, high-value payers. The label reflects tenure as much as spend. | Protect: loyalty perks, priority care, early renewal. |
| Potential Loyalists | 4,391 | 43.9% | 42.0% | ~5,210 | 35.1, 19 days | Regular mid-value payers, the core of the base. | Grow: speed-upgrade and add-on offers. |
| New Customers | 1,211 | 12.1% | 3.0% | ~1,355 | 5.7, 26 days | Recent joiners, few payments, 70% in classes C/C+. | Onboard: 90-day payment reminders, easy channels. |
| At Risk | 707 | 7.1% | 3.6% | ~2,780 | 18.6, 209 days | About 7 months since last payment, half already suspended. | Win back the A/B accounts, close dead ones. |
| No payments | 363 | 3.6% | 0% | n/a | n/a | Records with no payment in the data. | Audit, then reactivate or close. |
 
**Why it is useful.** One third of customers produce half the revenue, so retention spending should be targeted instead of spread evenly. New Customers and Loyalists hold most of the *future* risk (section 10), which the "At Risk" label alone would miss. The segmentation is based on payments only, because consumption and app data do not exist for these customers (scope warning).
 
---
 
## 10. AI/ML use case (Task 8): payment-lapse early warning
 
- **Target:** a subscriber active at snapshot T (paid in the 60 days before T) makes **no payment in the next 60 days**. 60 days is clearly abnormal: payment gaps have a median of 17 days and a 99th percentile of about 61 days. `SUBSCRIBER_STATUS` is not used as the target because it is a current snapshot without history.
- **Features (8, built only from data before T):** days since last payment, payments in the last 90 days, revenue in the last 90 days, revenue trend (90d / previous 90d), add-on share, average gap between the last 6 payments, tenure in months, customer class.
- **Split:** by time, not random. Train 2023-07 to 2024-06, 60-day embargo, test 2024-08 to 2025-03 (the last month whose outcome is fully observed).
- **Metrics:** PR-AUC (the lapse is rare, so accuracy is useless) and Recall at Top 10% (tied to the retention team's capacity). Precision at Top 10% is reported alongside.
- **Leakage prevention:** point-in-time features (only rows before T) plus the time split. `SUBSCRIBER_STATUS` and `STATUS_DATE` are excluded because they are recorded after the outcome.
**Results (test period):**
 
| | Model | Simple rule (days since last payment) | Random |
|---|---|---|---|
| PR-AUC | **0.26** | 0.15 | 0.03 |
| Recall @ Top 10% | **63.5%** | 43.2% | 10% |
| Precision @ Top 10% | 19.2% | 13.1% | n/a |
 
The riskiest decile lapses at about 19%, which is 6x the average. The bottom half is below 1%. **About 4 of 5 flagged subscribers would not have lapsed**, so the score ranks attention and must not trigger automatic action.
 
**In Power BI (page 4).** 8,875 active subscribers were scored. Risk bands are set by team capacity: High = top 10% (888), Medium = next 20%, Low = the rest. **Expected Revenue at Risk (60d)** = sum of (score x average monthly revenue) = about 56K per month (1.95% of monthly revenue). The High band holds 5.6% of revenue but 61% of the expected loss, and 83% of it is in classes B, C and C+. **76% of the expected loss sits in Loyalists and New Customers, only 5% in "At Risk"** (those customers have mostly lapsed already), so the model adds information that RFM cannot. A key group is the 42 high-risk Champions.
 
**Drift monitoring (monthly).** PSI per feature (above 0.25 means investigate), calibration (mean predicted vs actual lapse rate), PR-AUC and Recall @ Top 10% on matured months (60-day lag), plus data-quality checks on every load. Findings on this data: `rev_90d` PSI is 0.63 (Investigate), since the average rent per payment rose from about 109 (2023) to about 202 (2025). The actual lapse rate rose from 2.4% to 3.9% while the model kept predicting about 2%, so ranking still works but probabilities are too optimistic. This calls for recalibration or a rolling training window.
 
**Why a prediction supports, but does not replace, a decision.** It is a probability, not a fact. It says who may leave, not why or what would work. Wrong actions cost money (needless discounts) and trust (penalties on loyal customers). The model cannot see drift or business changes. A named person must own and explain each action, and campaigns should be measured against a control group.
 
---
 
## 11. Limitations and data needed
 
| Limitation | Effect | Data needed |
|---|---|---|
| Consumption customers are not in the Customer table (about 9.9K customers). | No usage-based insight, and nothing can be said about the value or risk of those customers. | A customer-key mapping, or payments, plan and status for the consumption customers. |
| Mobile-app data is not analysed. | No digital-engagement indicator in segments or the model. | App activity linked to customer keys, with an overlap check. |
| Status is a snapshot (no history). | Churn over time and suspension trends cannot be measured. | Status-change history. |
| No price history. | The price-led growth is inferred, not proven. | Tariff and price-change log. |
| Calls (mostly 2021 to 2022) do not overlap with payments (2023 to 2025). | No month-level link between service contact and payments. | Recent call data. |
| Plan is the current plan. | Revenue can be attributed to a later plan. | Plan history per subscriber. |
| Small samples: higher speed tiers (87 customers), governorates (14 to 27 suspended). | Effect sizes are indicative, not exact. | More data, or confidence intervals. |
| The model's precision is about 19% and its probabilities drift. | Use as a prioritized worklist only. | Outcomes of retention actions to retrain on. |
| Loyalty configuration covers only 23 of 108 plans. | Not used in the analysis. | Complete configuration. |
| 77 customers have no network record. | Governorate and technology show as unknown. | Network records. |
 
---
 
## 12. Recommended actions (in priority order)
 
1. **Upgrade campaign** for Class A, then B+, active 30 Mbps customers (4,757), with a holdout group. KPI: conversion rate and ARPU uplift.
2. **Instalment and reminder pilot** for classes B, C+, C, starting in Minya, Qena and Beni Suef. KPI: suspension rate vs control.
3. **Weekly retention worklist** from the High-risk band, sorted by expected revenue at risk. Start with the 42 high-risk Champions. KPI: realized lapse rate of contacted vs not contacted.
4. **Audit the 46-series plan families** and clean or reactivate the 676 non-paying "Active" accounts.
5. **Onboarding journey for new customers** (40% of the High-risk band are New Customers).
6. **Close the data gaps** in section 11, starting with the price log, status history and the consumption-to-customer mapping.
---
 
## 13. Explaining an inconclusive finding to a non-technical manager
 
> "Revenue rose a lot, but the number of customers rose much less. The most likely reason is price changes, because the jumps happen in two specific months when customer numbers stayed flat. But we do not have the price history, so I cannot confirm it. What I can say is that growth is relying on customers paying more. It would be risky to assume that can continue without checking how customers react. If you can get me the list of price changes, I can tell you with confidence."
 
The same wording applies to a **consumption drop**: "We can see usage fell. But the customers in the usage data have no plan, payment or status information, so I cannot say which type of customer is behind the drop, or whether it is a network issue, a pricing change or a seasonal effect. Linking those customers to our customer data would let me answer that."
 
---
 
## 14. Data-quality log
 
| Issue | Handling |
|---|---|
| `C_MONTH` in Calls mixes month names and numbers. | Parsed in Power Query to one date. |
| `ADMIN_STATUS` and `OPERATION_STATUS` contain codes such as -2 and random numbers. | Grouped as "Invalid / Other" or "Not captured". |
| `OUT_BUNDLE_REVENUE` and `TAX_AMOUNT` are zero in every row. | Excluded. |
| `RENT_REVENUE = IN_BUNDLE + ADDON` on every row. | Not added together (A3). |
| 16 to 17 digit IDs lose precision as numbers. | Kept as text. |
| `ACCOUNT_ID#` has 18 digits. | Not used as a key. |
| 2 `CUSTOMER_ID#` values appear twice. | Handled as customer vs subscriber unit (A2). |
| 363 customers with no payments; 77 with no network record. | Separate segment; "Unknown" governorate. |
| 0.55% of payments are dated before activation. | Kept and noted. |
| May-25 is incomplete (data ends 20 May). | Excluded from trends. |
| `QUOTA` mixes text ("1TB") and numbers. | Converted to a number (1 TB = 1,024). |
| Typos in `SUBSCRIBER_TYPE` ("Resedential"). | Corrected in Power Query. |
| `GROUP_ID#` is about 93% empty. | Not used. |
