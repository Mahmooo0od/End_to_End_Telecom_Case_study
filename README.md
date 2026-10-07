# WE Telecom: Customer Value, Engagement & Risk

**BI Practical Assessment – short README.** Full detail (SQL, data model, DAX, data-quality log) is in `Detailed_ReadMe.md`.
Data runs to 20 May 2025; the report is anchored on **30 Apr 2025**, the last complete month. Amounts are in the data's own units (assumed EGP).

> **Scope warning.** This analysis covers the **9,995 subscribers in the `Customer` table**, which have payments, calls, plan and status. The customers in `Consumption` (about 9.9K) are a **different population**: none of them appear in `Customer`, so their value, risk and segment cannot be measured. All findings apply to the Customer-table population only and must not be extrapolated to all 19.9K customers seen across tables.

## 1. Assumptions
1. **Population:** `Customer` table only. `Consumption` and `Mobile_App` are loaded but not used in any measure or visual.
2. **Total Revenue = Rent + Devices + Creation fees (54.45M).** Out-bundle and tax are zero on every row, and `RENT = IN_BUNDLE + ADDON` on every row, so adding all six columns would double count (+98%).
3. **Active Customer** = status `Active` **and** at least one payment in the last 3 complete months (1 Feb – 30 Apr 2025).
4. **Trends use complete months only.** May-25 is partial and excluded from trends.
5. **`Suspended` is the churn proxy.** Status is one current snapshot with no history.
6. **Plan = current plan**, not the plan at payment time.
7. **Units:** dashboard counts subscribers (9,995); SQL and RFM count customers (9,993). The difference is two customers with two subscribers.
8. AI outputs (segments, scores) are static exports from the notebook (scored 21 May 2025); re-run it to refresh.

## 2. KPI choices (Task 4)
Facts never join to each other, only through `Customer`, so filtering by customer, plan or date cannot double count.

| Group | Key measures | Why |
|---|---|---|
| Base | Total Customers, **Active Customers**, Active %, Suspended, Suspension Rate, Dormant | Who exists, who really pays, who is lost or silent. "Dormant" = status Active minus Active Customers |
| Value | Total Revenue, **ARPU**, Add-on Attach Rate, Top-10% Revenue Share | ARPU is the key lever because growth is ARPU-led |
| Trend | MoM %, YoY %, Volume-vs-ARPU bridge | Shows *why* revenue changed, not just that it did |
| Share | Revenue / Customer / Suspended Share % | Where money and risk concentrate. Uses `ALLSELECTED` / `REMOVEFILTERS` on the axis column, so shares stay correct under a Subscription Plan filter |
| Engagement | Calls per 100 Customers, Repeat Caller % | Service-contact intensity |
| Opportunity & Risk | Upsell Candidates, Upsell Potential (adjustable rate), Expected Revenue at Risk (60d), Model Recall Top10 | Sizes the opportunity and the exposure |

## 3. Main business insights
**Headline.** Monthly revenue rose from 1.19M (Jan-23) to 2.90M (Apr-25). Paying customers grew +32% but ARPU grew +84% (190 to 348). In Apr-25 vs Apr-24, **78% of growth came from ARPU, 22% from volume**. Growth is price/mix-led; the cause (tariff changes) is an inference because there is no price history.

**1. Growth: the base is parked on the entry tier.**
- *Finding:* 99.1% of customers are on 30 Mbps (ARPU **245**); 50-80 Mbps pays **762** and 100+ Mbps **1,552**, yet together they are under 1% of the base. 4,757 active Class A/B+ customers are upgrade candidates.
- *Driver:* one plan family holds 71% of customers and there is no visible migration path. Fiber (GPON) earns more (302 vs 253 VDSL) with fewer calls (107 vs 191 per 100 customers).
- *Size:* about **335K/month** at an assumed 10% conversion (an upper bound; the rate is an input, not measured).
- *Action:* upgrade campaign starting with the 1,039 Class A customers, with a holdout group to measure real conversion.

**2. Risk: suspensions concentrate in weaker classes.**
- *Finding:* 548 suspended (5.48%). Classes B, C+ and C are **44.5% of customers but 75% of suspensions**. Minya (10.4%), Qena (8.8%) and Beni Suef (8.5%) run 1.7-2.1x above Cairo (5.0%).
- *Exposure:* about **113K/month** of revenue tied to suspended accounts.
- *Driver:* most likely affordability (not proven; consistent with ARPU rising). Technology does not explain it, and callers are suspended *less* (4.3% vs 6.2%).
- *Action:* pilot instalment plans and payment reminders for classes B, C+, C, starting in the three governorates, with a control group.

**3. Risk (data and operations): "Active" does not mean paying.**
- *Finding:* 676 Active-status customers have not paid in 3 months. **73%** sit in the 46-series plan families (6% of customers, 2% of revenue). Of the 676: 317 never paid, 104 paid late in May, 255 genuinely stopped.
- *Driver:* old or migrated plan families whose status was not maintained.
- *Action:* audit the 46-series (reactivate or close). Call the 64 customers who lapsed 3-6 months ago first (highest value).

**Segmentation (Task 7, RFM + K-Means):** Champions 3,323 (33.2% of customers, 51.4% of revenue: protect) · Potential Loyalists 4,391 (43.9%, 42.0%: grow) · New Customers 1,211 (12.1%, 3.0%: onboard) · At Risk 707 (7.1%, 3.6%: win back) · No payments 363 (3.6%: audit). One third of customers produce half the revenue, so retention spend should be targeted.

**AI use case (Task 8):** 60-day payment-lapse early warning, time-based split, point-in-time features. It beats a simple recency rule (PR-AUC **0.26** vs 0.15; Recall@Top10% **63.5%** vs 43.2%). 76% of expected revenue at risk sits in Loyalists and New Customers, not in "At Risk". It supports a human worklist and never triggers automatic action: about 4 in 5 flagged subscribers would not have lapsed, and it cannot say *why* a customer may leave or *what* would work.

## 4. Important limitations
- **Consumption customers are not in `Customer`:** no usage-based insight and no statement on their value or risk. *Needs:* a customer-key mapping or payments/plan/status for them.
- **No price history:** price-led growth is inferred, not proven. *Needs:* tariff change log.
- **Status is a snapshot:** churn over time cannot be measured. *Needs:* status history.
- **Calls are mostly 2021-22, payments 2023-25:** calls are an engagement attribute, never aligned by month with payments.
- **Small samples:** higher speed tiers (87 customers), governorates (14-27 suspended each). Results are indicative.
- **Model precision is about 19% and probabilities drift:** actual lapse rose from 2.4% to 3.9% while the model predicted about 2%. Ranking works; probabilities need recalibration.
- **Mobile App** is not analysed, so there is no digital-engagement indicator.

## 5. Recommended actions (priority order)
1. Upgrade campaign for Class A, then B+, active 30 Mbps customers (4,757), with a holdout group.
2. Instalment and reminder pilot for classes B, C+, C, starting in Minya, Qena and Beni Suef.
3. Weekly retention worklist from the High-risk band, sorted by expected revenue at risk, with a control group.
4. Audit the 46-series plans and clean up or reactivate the 676 non-paying "Active" accounts.
5. Recalibrate the model and monitor drift monthly (PSI, calibration, PR-AUC).
6. Close the data gaps: price log, status history, consumption-to-customer mapping.

## 6. Explaining an inconclusive finding to a non-technical manager
*Example: the driver behind a consumption drop.*

> "We can see that usage fell, and where. What we cannot see is why: the customers in the usage data have no plan, payment or status information, so I cannot tell whether it is a network issue, a price change or a seasonal effect. I would not act on a guess. If you can get me the price-change dates and a link between usage and customer records, I can answer with confidence. Meanwhile, a small low-cost test on one group is safer than a large change."

The principle: separate what is **proven**, what is **likely**, and what is **unknown**; say what data would settle it; recommend a small reversible next step.

## 7. Dashboard pages
**Executive Overview:** how big, how valuable, what changed.
![Executive Overview](Screenshots/Page_1.jpg)

**Growth Opportunities:** where the upside is.
![Growth Opportunities](screenshots/2_growth_opportunities.jpg)

**Risk Analysis:** who is suspended or dormant, and why.
![Risk Analysis](screenshots/3_risk_analysis.jpg)

**Segmentation & AI:** who the customers are and where revenue is at risk.
![Segmentation & AI](screenshots/4_segmentation_ai.jpg)
