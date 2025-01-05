# SQL_Ads_Analysis

<br>

## Project Description :
In this project, I performed a series of SQL queries to analyze advertising data from four database tables:

 - facebook_ads_basic_daily
 - facebook_adset
 - facebook_campaign
 - google_ads_basic_daily
Objective: Combine advertising metrics (spend, impressions, reach, clicks, leads, value) from both Facebook and Google Ads, filter out unnecessary information, and prepare a clear dataset for further analysis.

## Main Steps :
Data Combination in a CTE

Gather data from the specified tables to obtain the target fields:
ad_date – the date of the advertisement
url_parameters – UTM parameters in the links
spend, impressions, reach, clicks, leads, value – key metrics
Handle missing (null) metric values by replacing them with 0.
UTM Parameter Parsing and Aggregation

Select ad_date and utm_campaign (extracted from url_parameters using regular expressions).
Normalize strings (convert to lowercase) and replace nan values with null.
Calculate total spend, impressions, clicks, and total conversion value.
Compute additional metrics such as CTR, CPC, CPM, and ROMI, utilizing CASE to avoid division by zero.
Generating Final Tables

Example approach: output data into multiple intermediate CTEs, then join them with additional reference tables (e.g., country_info).
Create a table for entries with no matching keys (analogous to nocountryfound in other tasks).
Period-Based Analysis

Group the data by month (extracted from the ad date).
Compare CPM, CTR, and ROMI in the current month versus the previous month (in percentages).
Outcome
These queries enable:

Gathering and cleaning scattered advertising data into a convenient structure for analysis.
Forming aggregated metrics and performance indicators (CTR, CPC, CPM, ROMI).
Quickly identifying campaigns with missing references in auxiliary tables (via nocountryfound or similar).
This project demonstrates how to use CTEs, regular expressions, and conditional operators (CASE) in SQL to handle real-world analytical tasks. You’ll find step-by-step SQL scripts implementing the above steps in this repository.


