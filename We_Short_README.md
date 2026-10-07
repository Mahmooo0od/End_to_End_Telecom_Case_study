# WE Telecom – BI Assessment README

**Files:** `Telecom_Assessment.pbix` · `We_Quries.sql` · `Customer_Segmentation_and_AI_Churn_Risk_.ipynb`
**Data window:** Jan-2023 to 20-May-2025. May-2025 is partial, so trends stop at Apr-2025.

## 1. Assumptions
1. **Scope:** the `customer` table (9,995 customers) is the source of truth. All KPIs, segments and the AI model cover customers that have a customer record and payments. Customers that appear **only in `Consumption`** (about 9,890 extra rows in the Task 1 result, 19,887 in total) have no plan, status, payments or calls, so they are not analysed for value or risk.
2. **Revenue** = RENT + OUT_BUNDLE + DEVICES + CREATION_FEES. IN_BUNDLE + ADDON = RENT (verified) and tax = 0, so adding them again would double count.
3. **Active customer** = not suspended **and** paid within the recent window **[state your window here, e.g. 90 days]**. This reconciles: 8,771 active + 548 suspended + 676 dormant = 9,995.
4. **Lapse** (used as a churn proxy) = no payment for 60 days. There is no cancellation date in the data.
5. **Calls** are treated as an engagement / support-demand proxy (their exact meaning is not documented).
6. The upgrade rate in the Growth page is a user-set assumption, not a measured value.

## 2. Model and KPI choices (Task 3–4)
Star schema: dimensions (`Customer`, `Subscription_Plan`, `Calendar`, `Calls date`, `Dim_Segment`) filter separate fact tables (`Payments`, `Calls`, `Consumption`, `Mobile_App`, `Churn_Scores`). Facts are never joined to each other, and customers are counted with `DISTINCTCOUNT`, so nothing is double counted.

| KPI | Definition | Why |
|---|---|---|
| Total / Active Customers, Active % | See assumption 3 | Base for all ratios |
| Suspended Customers, Suspension Rate | Suspended ÷ total | Core risk KPI |
| Total Revenue, ARPU | Revenue ÷ paying customers | Value per customer; separates price from volume |
| Volume vs ARPU effect | ΔCustomers × prior ARPU; ΔARPU × current customers | Explains *why* revenue changed |
| Share % (revenue, customers, suspensions) | Item ÷ ALLSELECTED total | Concentration; stays correct under a Subscription Plan filter |
| Calls per 100 customers | Calls ÷ customers × 100 | Engagement proxy |
| Expected Revenue at Risk | Σ risk score × avg monthly rent | Prioritises retention by value |

## 3. Main insights
**1. Growth – price-led growth with upsell room.** Customers +32% but ARPU +84% since Jan-23; 78% of year-on-year revenue growth is ARPU. 99% of customers are on 30 Mbps (ARPU ~245) while 50–80 Mbps earns ~762 and 100+ Mbps ~1,552. *Driver:* almost the whole base is on one tier, so a tariff increase (not mix shift) is the likely cause. *Action:* pilot an upgrade offer to the 4,757 candidates (47.6% of base) and measure the real take-up (10% assumed = ~476 upgrades, ~335K/month).

**2. Risk – suspensions are concentrated.** 548 suspended (5.48%, ~113K monthly revenue) plus 676 active-but-not-paying. Classes B–D hold 75% of suspensions with 45% of customers; Minya, Qena and Beni Suef suspend 1.7–2.1x more than Cairo. The "46-series" plans are 6% of customers, 73% of dormant accounts and 2% of revenue, and 317 of the 676 dormant accounts never paid at all. *Driver:* weaker payment capacity plus an activation problem on 46-series plans. *Action:* fix or close never-paid 46-series accounts; earlier reminders and flexible payment for classes B–C and the high-suspension governorates.

**3. Value and risk – revenue is concentrated, risk sits in "healthy" segments.** Champions are 33% of customers and 51% of revenue. 76% of expected revenue at risk (55.98K) sits in Potential Loyalists and New Customers, not in "At Risk". The top-10% risk list reaches 63.5% of real lapsers (PR-AUC 0.26 vs 0.03 random). Actual lapse rose from 2.4% to 3.9% while the model predicted ~2%. *Action:* monthly retention worklist (top 10% by revenue at risk) with a control group, and recalibrate the model.

**Segments (Task 7, RFM + K-Means):** Champions 3,323 (33.25%) · Potential Loyalists 4,391 (43.93%) · New 1,211 (12.12%) · At Risk 707 (7.07%) · no payment history 363 (3.63%). Actions: protect, grow, onboard, win back, investigate.

**AI use case (Task 8):** 60-day payment-lapse early warning. Time-based split with a 60-day embargo, point-in-time features (leakage control), PR-AUC and Recall@Top10%, PSI/calibration monitoring. It prioritises a human worklist; it never triggers automatic action, because most flagged customers (~4 in 5) would not have lapsed and the model cannot tell *why* or *what will work*.

## 4. Important limitations
- Consumption-only customers cannot be linked to revenue, plan or risk. A customer master covering them (or a mapping key) is needed.
- No tariff history: the price explanation is by elimination, not proven. No customer-class history (small leakage risk in the model).
- Lapse is a proxy for churn; status is a single snapshot with no history.
- Governorate and technology groups are small (e.g. GPON, Minya, Qena), so treat those results as hypotheses.
- Consumption and Mobile App are in the model but not part of the main story because of the population gap.
- SQL Task 2 gains are mostly I/O (Consumption reads -63%); elapsed time improved only ~4%. `UNION ALL` is safe only while the two customer sets do not overlap.

## 5. Recommended actions
1. Clean up never-paid 46-series accounts.
2. Run the monthly top-10% retention worklist with a control group.
3. Pilot the speed-upgrade offer and measure real take-up.
4. Recalibrate or retrain the churn model and monitor drift monthly.
5. Close data gaps: customer master for Consumption customers, tariff history, class history, meaning of Calls.

## 6. Explaining an inconclusive finding to a non-technical manager
*Example: the driver behind a consumption drop.*

"We know for sure that usage fell by X% and that it is concentrated in these plans. What we do not know is why, because our data shows that it happened but not the reason. The most likely explanations are a price or plan change, a network or measurement issue, or customers using another provider, and today we cannot tell them apart. To settle it we need one more piece of information, such as tariff change dates or network outage logs. Until then I recommend a small, low-cost test on one group instead of an expensive action based on a guess."
