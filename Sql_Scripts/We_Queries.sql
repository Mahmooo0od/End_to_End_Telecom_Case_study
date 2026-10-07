CREATE DATABASE Telecom_Assessment;
GO


-- __________ Task1_Solution_______________

SET STATISTICS IO, TIME ON;

WITH Distinct_Customers AS (
    
    SELECT [CUSTOMER_ID#] AS CUSTOMER_ID FROM dbo.customer
    UNION
    
    SELECT CUSTOMER_ID FROM dbo.Consumption
    
),
Aggregated_Consumption AS (
    SELECT 
        CUSTOMER_ID,
        SUM(TRY_CAST(DAILY_CONSUMPTION_MB AS FLOAT)) AS Total_Consumption
    FROM dbo.Consumption
    GROUP BY CUSTOMER_ID
),
Aggregated_Payments AS (
    SELECT 
        c.[CUSTOMER_ID#] AS CUSTOMER_ID,
        SUM(ISNULL(TRY_CAST(p.RENT_REVENUE AS FLOAT), 0) + 
            ISNULL(TRY_CAST(p.OUT_BUNDLE_REVENUE AS FLOAT), 0) + 
            ISNULL(TRY_CAST(p.IN_BUNDLE_REVENUE AS FLOAT), 0) + 
            ISNULL(TRY_CAST(p.ADDON_REVENUE AS FLOAT), 0) + 
            ISNULL(TRY_CAST(p.DEVICES_REVENUE AS FLOAT), 0) + 
            ISNULL(TRY_CAST(p.CREATION_FEES_REVENUE AS FLOAT), 0)) AS Total_Payments
    FROM dbo.Payments p
    INNER JOIN dbo.customer c ON p.SUBSCRIBER_ID = c.[SUBSCRIBER_ID#]
    GROUP BY c.[CUSTOMER_ID#]
),
Aggregated_Calls AS (
    SELECT 
        c.[CUSTOMER_ID#] AS CUSTOMER_ID,
        COUNT(cl.CALL_ID) AS Total_Calls
    FROM dbo.calls cl
    INNER JOIN dbo.customer c ON cl.[SERVICE_NUMBER#] = c.[SERVICE_NUMBER#]
    GROUP BY c.[CUSTOMER_ID#]
)
SELECT 
    dc.CUSTOMER_ID,
    ISNULL(ac.Total_Consumption, 0) AS Total_Consumption,
    ISNULL(ap.Total_Payments, 0) AS Total_Payments,
    ISNULL(call_agg.Total_Calls, 0) AS Total_Calls
FROM Distinct_Customers dc
LEFT JOIN Aggregated_Consumption ac ON dc.CUSTOMER_ID = ac.CUSTOMER_ID
LEFT JOIN Aggregated_Payments ap ON dc.CUSTOMER_ID = ap.CUSTOMER_ID
LEFT JOIN Aggregated_Calls call_agg ON dc.CUSTOMER_ID = call_agg.CUSTOMER_ID;

SET STATISTICS IO, TIME OFF;


-- ___________ More Optimizied_Solution ___________

SET STATISTICS IO, TIME ON;

WITH Aggregated_Consumption AS (
    SELECT 
        CUSTOMER_ID,
        SUM(TRY_CAST(DAILY_CONSUMPTION_MB AS FLOAT)) AS Total_Consumption
    FROM dbo.Consumption
    GROUP BY CUSTOMER_ID
),
Distinct_Customers AS (
    SELECT DISTINCT [CUSTOMER_ID#] AS CUSTOMER_ID 
    FROM dbo.customer
    UNION ALL
    SELECT CUSTOMER_ID FROM Aggregated_Consumption
),
Aggregated_Payments AS (
    SELECT 
        c.[CUSTOMER_ID#] AS CUSTOMER_ID,
        SUM(ISNULL(TRY_CAST(p.RENT_REVENUE AS FLOAT), 0) + 
            ISNULL(TRY_CAST(p.OUT_BUNDLE_REVENUE AS FLOAT), 0) + 
            ISNULL(TRY_CAST(p.DEVICES_REVENUE AS FLOAT), 0) + 
            ISNULL(TRY_CAST(p.CREATION_FEES_REVENUE AS FLOAT), 0)) AS Total_Payments
    FROM dbo.Payments p
    INNER JOIN dbo.customer c ON p.SUBSCRIBER_ID = c.[SUBSCRIBER_ID#]
    GROUP BY c.[CUSTOMER_ID#]
),
Aggregated_Calls AS (
    SELECT 
        c.[CUSTOMER_ID#] AS CUSTOMER_ID,
        COUNT(cl.CALL_ID) AS Total_Calls
    FROM dbo.calls cl
    INNER JOIN dbo.customer c ON cl.[SERVICE_NUMBER#] = c.[SERVICE_NUMBER#]
    GROUP BY c.[CUSTOMER_ID#]
)
SELECT 
    dc.CUSTOMER_ID,
    ISNULL(ac.Total_Consumption, 0) AS Total_Consumption,
    ISNULL(ap.Total_Payments, 0) AS Total_Payments,
    ISNULL(call_agg.Total_Calls, 0) AS Total_Calls
FROM Distinct_Customers dc
LEFT JOIN Aggregated_Consumption ac ON dc.CUSTOMER_ID = ac.CUSTOMER_ID
LEFT JOIN Aggregated_Payments ap ON dc.CUSTOMER_ID = ap.CUSTOMER_ID
LEFT JOIN Aggregated_Calls call_agg ON dc.CUSTOMER_ID = call_agg.CUSTOMER_ID;

SET STATISTICS IO, TIME OFF;

-- __________________________ 

/*
 1. Group first. Consumption is aggregated by CUSTOMER_ID before the union,
     so the union sees one row per customer instead of one row per day.
  2. UNION ALL instead of UNION, which skips the distinct step.
     Only safe because Consumption customers are not in dbo.customer.
     If that stops being true, rows will duplicate.
  3. Indexes on the join / group columns (Consumption, customer, Payments, calls).

  Measured with SET STATISTICS IO, TIME (before -> after, all changes together):
    Consumption reads   158,174 -> 57,774   (-63%)
    customer reads          684 ->    426   (-38%)
    Payments reads        2,950 ->  2,284   (-23%)
    calls reads             234 ->    196   (-16%)
    CPU                10,375 ms -> 9,046 ms (-13%)
    Elapsed             2,988 ms -> 2,865 ms (-4%)
    Rows                19,887 -> 19,887 (same result)

	*/

-- _____ Recomended indexs to use ___ We can test every sigle one by reading Statistics before & after ___ and choose the best Situation

SET STATISTICS IO, TIME ON;

CREATE NONCLUSTERED INDEX IX_Consumption_Customer
ON dbo.Consumption (CUSTOMER_ID)
INCLUDE (DAILY_CONSUMPTION_MB);

CREATE NONCLUSTERED INDEX IX_Customer_CustomerID
ON dbo.customer ([CUSTOMER_ID#])
INCLUDE ([SUBSCRIBER_ID#], [SERVICE_NUMBER#]);

CREATE NONCLUSTERED INDEX IX_Payments_Subscriber
ON dbo.Payments (SUBSCRIBER_ID)
INCLUDE (RENT_REVENUE, OUT_BUNDLE_REVENUE, IN_BUNDLE_REVENUE,
         ADDON_REVENUE, DEVICES_REVENUE, CREATION_FEES_REVENUE);

CREATE NONCLUSTERED INDEX IX_Calls_Service
ON dbo.calls ([SERVICE_NUMBER#])
INCLUDE (CALL_ID);


--__________ if i was in Teradata i will confirm The best time ever by avoiding Data Skew

/*
  Teradata notes.... avoiding data skew

  1) Pick a primary index (PI) with many distinct.. evenly spread values 
     CUSTOMER_ID or SUBSCRIBER_ID is fine... Never a status or class column
     (SUBSCRIBER_STATUS has 2 values.. CUSTOMER_CLASS has 7): every row with the
     same value hashes to the same AMP, so one AMP does most of the work

  2) Check for skew before building on a table.. not after the query is slow ...
       SELECT HASHAMP(HASHBUCKET(HASHROW(CUSTOMER_ID))) AS amp_no, COUNT(*)
       FROM Consumption GROUP BY 1 ORDER BY 2 DESC;
     If the biggest AMP holds far more rows than the average ..the PI is a bad choice

  3) Watch NULLs and placeholder values in PI and join columns... All NULLs land
     on one AMP (GROUP_ID# in dbo.customer is about 93% NULL).. and so do
     defaults like 0 or -1.. Filter them out or handle them separately before joining

  4. Give intermediate tables the same PI as the column they are joined on
     (CUSTOMER_ID), aggregate before joining.. and collect statistics on the PI
     and join columns... That keeps joins AMP-local and avoids redistributing
     a big table
*/