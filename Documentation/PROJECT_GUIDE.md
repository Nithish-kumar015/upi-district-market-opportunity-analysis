# UPI District Market Opportunity Analysis

## Business scenario

This project models a fictional payments company whose regional growth team reviews public district-level UPI activity to decide which areas deserve further market research. The analysis describes activity reported for the wider UPI ecosystem. It does not represent the fictional company’s own customers, transactions, revenue, or market share.

The project answers 15 distinct questions across monthly movement, state and district rankings, declines, growth streaks, transaction mix, average reported value per transaction, top-10 concentration, and a transparent district research shortlist. The questions and assumptions are in [UPI_Project_Business_Questions.docx](UPI_Project_Business_Questions.docx).

## Source and scope

- Source: [NPCI UPI district statistics, distributed by Measure of India](https://measure.thisindianlife.today/data/npci-upi-districts/)
- Source file: `Data/source/npci-upi-districts.csv`
- Coverage in this project: March–September 2026 (seven monthly periods)
- Processed grain: one row per month and state-district pair
- Processed data: 5,467 rows, 36 states/union territories, 781 distinct state-district pairs, seven fields
- Missing transaction value: 7 rows; missing transaction count: 9 rows. These are retained as missing, not converted to zero.
- Data quality review found no invalid numeric values, negative metrics, missing geography/month labels, or duplicate month/state/district keys.

This is a short, aggregated series. It cannot establish seasonality, explain why activity changed, identify merchants/customers, or prove market demand. The shortlist is a screening rule for research, not a forecast or investment recommendation.

## Project flow

```text
NPCI district CSV
        │
        ▼
Python/reshape_upi_source.py
  reshape wide metrics into district-month rows
        │
        ▼
Data/processed/upi_district_monthly.csv
        │
        ├──► Python monthly checks, concentration, shortlist, and chart
        │
        ▼
SQL Server staging table
        │
        ▼
DimMonth + DimDistrict ──► FactUPIDistrictMonthly
        │                         │
        ├──► SQL quality checks  └──► Power BI model and DAX
        │                                  │
        └──► 15 business queries           └──► three-page dashboard
```

The fact table grain is one row per month and state-district pair. `DimMonth` and `DimDistrict` each have a one-to-many relationship to `FactUPIDistrictMonthly`. The raw staging table keeps CSV values as text so that SQL can inspect and convert them explicitly. District identity is the pair of state and district; identical district names in different states are separate entities.

## Run order

1. Create/activate the project Python environment and install `Python/requirements.txt`.
2. Run `Python/reshape_upi_source.py` to create/update the processed CSV from the source CSV.
3. In the `UPI_payment_trends_analysis` SQL Server database, run `SQL/01_create_tables.sql` once.
4. Run `SQL/02_load_staging.sql`, then `SQL/04_data_quality_checks.sql` to review the imported rows.
5. Run `SQL/03_transform_dimensions_fact.sql` to populate the dimensions and fact table.
6. Run `SQL/04_data_quality_checks.sql` again to reconcile the fact table and its relationships.
7. Run `SQL/05_business_analysis.sql` for the 15 business questions.
8. Run `Python/analyze_upi_trends.py`, `Python/Analysis/q14_top10_concentration.py`, `Python/Analysis/q15_district_shortlist.py`, and `Python/Visuals/monthly_trends.py` for independent Python summaries and the static chart.
9. Open `Power_BI/upi_payment_trends_dashboard.pbix`, refresh its SQL Server data source if needed, and check the three report pages.

`SQL/02_load_staging.sql` uses the current local processed-CSV path. If the project is moved, update the path in that file and make sure the SQL Server service account can read the CSV location. In Power BI, update the server/database in the data-source settings if your SQL Server instance differs.

## SQL analyses

`SQL/05_business_analysis.sql` contains Q1–Q15. It uses T-SQL CTEs, joins, window functions, ranking, conditional logic, and aggregation. Q15 chooses the latest available month and compares it with the month three months earlier. It requires complete observed history for eligible districts and scores them using a clearly stated 40% activity, 40% recent growth, and 20% stability weighting. Stability rewards lower standard deviation in monthly percentage changes.

## Python analyses

- `reshape_upi_source.py`: reshapes the source’s wide format, preserves blank metric cells, and checks the district-month key.
- `analyze_upi_trends.py`: checks the processed file and summarizes monthly value, count, change, matched-row average value per transaction, and missing metrics.
- `Analysis/q14_top10_concentration.py`: independently calculates top-10 district value and count concentration by month.
- `Analysis/q15_district_shortlist.py`: independently reproduces the SQL shortlist logic and prints the top 20.
- `Visuals/monthly_trends.py`: saves a four-panel monthly chart in this folder as `python_monthly_trends.png`.

The code derives the project root from each script’s location, so moving the project does not require editing Python paths.

## Power BI report

The saved report is `Power_BI/upi_payment_trends_dashboard.pbix`.

- **Overview & Trends:** KPI cards, month/state/district slicers, and the monthly transaction-value trend.
- **State Performance:** top 10 states by reported transaction value, with MonthStart and StateName slicers.
- **District Analysis:** MonthStart and DistrictName slicers with top 10 districts by reported transaction value.

Core DAX measures cover total transaction value, total transaction count, average value per transaction using rows with both metrics present, previous available month value, month-over-month value change and percentage, and month-over-month count percentage. The month comparison uses the prior available month with fact data under the current geography filters.

## Reproducibility notes

- The project uses T-SQL, Python with NumPy and pandas, Matplotlib, Power BI, and DAX.
- The SQL table setup is idempotent for an existing table. Staging import skips an already-populated staging table; clear/rebuild it deliberately before reloading a replacement source file.
- The raw and processed CSVs are kept separate so the source download remains available for audit.
- Values and counts are district-reported monthly totals, not transaction-level records.


