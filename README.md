# UPI District Market Opportunity Analysis

A portfolio analytics project using **T-SQL, Python (pandas and NumPy), Power BI, and DAX** to help a fictional payments company decide which districts merit further market research.

The dataset describes UPI activity reported across the wider ecosystem. It is not the fictional company’s customer, transaction, revenue, or market-share data.

## Business questions

The analysis examines monthly changes and declines, state and district rankings, average reported value per transaction, top-10 district concentration, and a transparent district research shortlist. The full 15-question brief and assumptions are in [Documentation/UPI_Project_Business_Questions.docx](Documentation/UPI_Project_Business_Questions.docx).

## Data

- Source: [NPCI UPI district statistics, distributed by Measure of India](https://measure.thisindianlife.today/data/npci-upi-districts/)
- Coverage: March–September 2026 (7 reporting months)
- Processed grain: one row per month and state-district pair
- Processed data: 5,467 rows, 36 states/union territories, and 781 state-district pairs
- Missing reported metrics are retained as missing, not treated as zero.

## Project flow

```text
Source CSV
   → Python reshape and validation
   → Processed month-district CSV
   → SQL Server staging table
   → DimMonth + DimDistrict → FactUPIDistrictMonthly
   → SQL quality checks and 15 business analyses
   → Python summaries, shortlist, and chart
   → Power BI model, DAX measures, and interactive report
```

The SQL model uses a fact table at month-and-district grain with month and district dimensions. T-SQL uses joins, CTEs, window functions, rankings, and aggregations. Python independently summarizes monthly trends, top-10 concentration, and the district shortlist.

## Dashboard pages

- **Overview & Trends:** headline measures and monthly activity, with MonthStart, StateName, and DistrictName filters.
- **State Performance:** state rankings with MonthStart and StateName filters.
- **District Analysis:** district rankings with MonthStart and DistrictName filters.

The DAX measures calculate reported transaction value and count, average value per transaction where both metrics are available, previous available month, and month-over-month changes.

## Run order

1. Install the packages listed in [Python/requirements.txt](Python/requirements.txt).
2. Run `Python/reshape_upi_source.py` to create the processed CSV.
3. In SQL Server, run `SQL/01_create_tables.sql`, `SQL/02_load_staging.sql`, `SQL/04_data_quality_checks.sql`, `SQL/03_transform_dimensions_fact.sql`, `SQL/04_data_quality_checks.sql`, then `SQL/05_business_analysis.sql`.
4. Run `Python/analyze_upi_trends.py`, the scripts under `Python/Analysis/`, and `Python/Visuals/monthly_trends.py`.
5. Open [Power_BI/upi_payment_trends_dashboard.pbix](Power_BI/upi_payment_trends_dashboard.pbix). Update the SQL Server data source if your server differs.

`SQL/02_load_staging.sql` contains the original local CSV path; update it if the project is moved and ensure the SQL Server service account can read the file. See [Documentation/PROJECT_GUIDE.md](Documentation/PROJECT_GUIDE.md) for the detailed workflow and limitations.

## Scope and limitations

This is a short aggregated series, so it cannot establish seasonality, explain causes, identify customer behavior, or forecast future demand. The shortlist is an exploratory research screen, not a forecast or investment recommendation.
