/*
--------------------------------------------------
  SECTION 1: Combine Facebook & Google Ads Data
--------------------------------------------------
  - cte_1: retrieves data from Facebook Ads tables
  - cte_2: retrieves data from Google Ads
*/
WITH cte_1 AS (
    SELECT 
        ad_date,
        url_parameters,
        (SELECT 'Facebook') AS media_source,
        spend,
        impressions,
        reach,
        clicks,
        leads,
        value
    FROM facebook_ads_basic_daily
    LEFT JOIN facebook_adset fa USING (adset_id)
    LEFT JOIN facebook_campaign fc USING (campaign_id)
),
cte_2 AS (
    SELECT 
        ad_date,
        url_parameters,
        (SELECT 'Google') AS media_source,
        spend,
        impressions,
        reach,
        clicks,
        leads,
        value
    FROM google_ads_basic_daily
),
/*
--------------------------------------------------
  SECTION 2: Union of Facebook & Google Data
--------------------------------------------------
  - cte_3: unions all rows from cte_1 and cte_2
*/
cte_3 AS (
    SELECT *
    FROM cte_1
    UNION ALL
    SELECT *
    FROM cte_2
),
/*
--------------------------------------------------
  SECTION 3: Clean & Transform Data
--------------------------------------------------
  - cte_4:
    - Checks url_parameters
    - If the result is 'nan' -> replace with NULL
    - Uses COALESCE(...) to replace null with 0
*/
cte_4 AS (
    SELECT 
        ad_date,
        CASE 
            WHEN LOWER(SUBSTRING(url_parameters, 'utm_campaign=([\w|\d]+)')) = 'nan' THEN NULL
            ELSE LOWER(SUBSTRING(url_parameters, 'utm_campaign=([\w|\d]+)'))
        END AS utm_campaign,
        COALESCE(spend, 0)       AS spend,
        COALESCE(impressions, 0) AS impressions,
        COALESCE(reach, 0)       AS reach,
        COALESCE(clicks, 0)      AS clicks,
        COALESCE(leads, 0)       AS leads,
        COALESCE(value, 0)       AS value
    FROM cte_3
    /*
      Using GROUP BY here might be required in some SQL dialects when dealing with 
      certain aggregation or function usage. If not needed, you can remove it.
    */
    GROUP BY 
        ad_date,
        url_parameters,
        spend,
        impressions,
        reach,
        clicks,
        leads,
        value
),
/*
--------------------------------------------------
  SECTION 4: Summarize Monthly & Calculate Metrics
--------------------------------------------------
  - cte_5:
    - Aggregates by month (date_trunc('month', ad_date))
    - Calculates totals, CTR, CPC, CPM, ROMI, etc.
    - Uses CASE to avoid division by zero
*/
cte_5 AS (
    SELECT 
        DATE_TRUNC('month', ad_date)            AS ad_month,
        utm_campaign,       
        CASE WHEN SUM(spend) > 0 THEN SUM(spend) ELSE 0 END            AS total_spend,
        CASE WHEN SUM(impressions) > 0 THEN SUM(impressions) ELSE 0 END AS tot_imp,
        CASE WHEN SUM(clicks) > 0 THEN SUM(clicks) ELSE 0 END          AS tot_clicks,
        CASE WHEN SUM(value) > 0 THEN SUM(value) END                   AS tot_value,       
        /* CPC */
        CASE 
            WHEN SUM(clicks) > 0 THEN SUM(spend) / SUM(clicks)
            ELSE 0
        END AS cpc,       
        /* CPM */
        CASE 
            WHEN SUM(impressions) > 0 THEN 1000 * SUM(spend) / SUM(impressions)
            ELSE 0
        END AS cpm,       
        /* ROMI: (Value - Spend)/Spend * 100 */
        CASE 
            WHEN SUM(spend) > 0 AND SUM(value) > 0 
                 THEN ROUND(100 * (SUM(value)::numeric - SUM(spend)) / SUM(spend), 2)
            ELSE 0
        END AS romi,        
        /* CTR */
        CASE 
            WHEN SUM(impressions) > 0 THEN ROUND(100 * SUM(clicks)::numeric / SUM(impressions), 2)
            ELSE 0
        END AS ctr
    FROM cte_4
    GROUP BY 
        ad_date,
        spend,
        impressions,
        clicks,
        value,
        utm_campaign
),
/*
--------------------------------------------------
  SECTION 5: Compare Monthly Differences (LAG)
--------------------------------------------------
  - cte_6:
    - Uses LAG(...) OVER (PARTITION BY ...) to compare current metrics vs. previous month
    - abs_diff_* — the absolute difference of the metrics
*/
cte_6 AS (
    SELECT 
        ad_month,
        utm_campaign,
        total_spend,
        tot_imp,
        tot_clicks,
        tot_value,
        cpc,
        ctr,
        LAG(ctr, 1) OVER (PARTITION BY utm_campaign ORDER BY ad_month)             AS lag_ctr,
        ABS(ctr - LAG(ctr, 1) OVER (PARTITION BY utm_campaign ORDER BY ad_month))  AS abs_diff_ctr,
        cpm,
        LAG(cpm, 1) OVER (PARTITION BY utm_campaign ORDER BY ad_month)             AS lag_cpm,
        ABS(cpm - LAG(cpm, 1) OVER (PARTITION BY utm_campaign ORDER BY ad_month))  AS abs_diff_cpm,
        romi,
        LAG(romi, 1) OVER (PARTITION BY utm_campaign ORDER BY ad_month)            AS lag_romi,
        ABS(romi - LAG(romi, 1) OVER (PARTITION BY utm_campaign ORDER BY ad_month)) AS abs_diff_romi
    FROM cte_5
    ORDER BY utm_campaign
)
/*
--------------------------------------------------
  FINAL QUERY: Display Final Results with Differences
--------------------------------------------------
  - Shows the percentage difference compared to the previous month
*/
SELECT 
    ad_month,
    utm_campaign,
    total_spend,
    tot_imp,
    tot_clicks,
    tot_value,
    ctr,
    lag_ctr,
    abs_diff_ctr, 
    CASE 
        WHEN ABS(lag_ctr) > 0 THEN ROUND(abs_diff_ctr / lag_ctr, 2) * 100
        ELSE 0
    END AS perc_diff_ctr,
    cpm,
    lag_cpm,
    abs_diff_cpm,
    (abs_diff_cpm / lag_cpm) * 100 AS perc_diff_cpm,
    romi,
    lag_romi,
    abs_diff_romi,
    CASE 
        WHEN ABS(lag_romi) > 0 THEN ROUND(abs_diff_romi / lag_romi, 2) * 100
        ELSE 0
    END AS perc_diff_romi
FROM cte_6