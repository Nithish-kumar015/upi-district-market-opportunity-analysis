from pathlib import Path

import numpy as np
import pandas as pd

project_folder = Path(__file__).resolve().parents[1]

source_file = project_folder / "Data" / "source" / "npci-upi-districts.csv"
output_file = project_folder / "Data" / "processed" / "upi_district_monthly.csv"
output_file.parent.mkdir(parents=True, exist_ok=True)

# Keep values as text for the SQL staging table; preserve blanks as blanks.
wide = pd.read_csv(source_file, dtype=str, keep_default_na=False)

if "date" not in wide.columns:
    raise ValueError("The source file does not contain the expected 'date' column.")

metric_names = {
    "value": "TransactionValueRaw",
    "number of transactions": "TransactionCountRaw",
    "share of all UPI value, % (as printed)": "TransactionValueSharePctRaw",
    "share of all UPI transactions, % (as printed)": "TransactionCountSharePctRaw",
}

# Turn the thousands of district metric columns into rows.
long = wide.melt(
    id_vars="date",
    var_name="Series",
    value_name="RawValue",
)

# Each source heading is formatted like:
# District, State: metric
header_parts = long["Series"].str.rsplit(": ", n=1, expand=True)
if header_parts.shape[1] != 2:
    raise ValueError("A source column header did not match the expected format.")

geography = header_parts[0].str.rsplit(", ", n=1, expand=True)
if geography.shape[1] != 2:
    raise ValueError("Could not separate district and state from a source header.")

long["DistrictName"] = geography[0]
long["StateName"] = geography[1]
long["TargetColumn"] = header_parts[1].map(metric_names)

if long["TargetColumn"].isna().any():
    unknown = long.loc[long["TargetColumn"].isna(), "Series"].unique()
    raise ValueError(f"Unexpected metric headings: {unknown[:5]}")

# Pivot the four measures back into columns, now with one row per district-month.
monthly = long.pivot(
    index=["date", "StateName", "DistrictName"],
    columns="TargetColumn",
    values="RawValue",
).reset_index()

monthly = monthly.rename(columns={"date": "ReportMonthRaw"})
monthly.columns.name = None

expected_columns = [
    "ReportMonthRaw",
    "StateName",
    "DistrictName",
    "TransactionValueRaw",
    "TransactionCountRaw",
    "TransactionValueSharePctRaw",
    "TransactionCountSharePctRaw",
]

missing_columns = [column for column in expected_columns if column not in monthly.columns]
if missing_columns:
    raise ValueError(f"Expected output columns are missing: {missing_columns}")

monthly = monthly[expected_columns]

# Convert empty metric cells to missing values; the CSV will keep them blank.
metric_columns = expected_columns[3:]
monthly[metric_columns] = monthly[metric_columns].replace("", np.nan)

if monthly.duplicated(["ReportMonthRaw", "StateName", "DistrictName"]).any():
    raise ValueError("Duplicate district-month rows were found.")

monthly.to_csv(output_file, index=False, encoding="utf-8-sig")

print(f"Saved: {output_file}")
print(f"Rows: {len(monthly):,}")
print(f"Months: {monthly['ReportMonthRaw'].nunique()}")
print(f"Districts: {monthly[['StateName', 'DistrictName']].drop_duplicates().shape[0]:,}")
print(f"Columns: {len(monthly.columns)}")

