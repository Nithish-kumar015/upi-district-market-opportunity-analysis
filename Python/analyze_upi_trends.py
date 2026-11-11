from pathlib import Path

import numpy as np
import pandas as pd


project_folder = Path(__file__).resolve().parents[1]

input_file = (
    project_folder / "Data" / "processed" / "upi_district_monthly.csv"
)
data = pd.read_csv(input_file, dtype=str, keep_default_na=False)

required_columns = [
    "ReportMonthRaw",
    "StateName",
    "DistrictName",
    "TransactionValueRaw",
    "TransactionCountRaw",
]

missing_columns = [
    column for column in required_columns
    if column not in data.columns
]

if missing_columns:
    raise ValueError(f"Missing expected columns: {missing_columns}")

data["MonthStart"] = pd.to_datetime(
    data["ReportMonthRaw"],
    format="%Y-%m-%d",
    errors="coerce",
)

if data["MonthStart"].isna().any():
    raise ValueError("Some report months could not be converted to dates.")

if data.duplicated(["MonthStart", "StateName", "DistrictName"]).any():
    raise ValueError("Duplicate district-month rows were found.")

metric_columns = [
    "TransactionValueRaw",
    "TransactionCountRaw",
    "TransactionValueSharePctRaw",
    "TransactionCountSharePctRaw",
]

for column in metric_columns:
    if column not in data.columns:
        continue

    raw_values = data[column].copy()
    has_value = raw_values.str.strip().ne("")

    converted_values = pd.to_numeric(
        raw_values.replace(r"^\s*$", np.nan, regex=True),
        errors="coerce",
    )

    invalid_values = has_value & converted_values.isna()

    if invalid_values.any():
        raise ValueError(f"Invalid numeric values found in {column}.")

    data[column] = converted_values

print("\nPython source data checks:")
print(f"Rows: {len(data):,}")
print(f"Months: {data['MonthStart'].nunique()}")
print(f"First month: {data['MonthStart'].min():%Y-%m-%d}")
print(f"Last month: {data['MonthStart'].max():%Y-%m-%d}")
print(f"States: {data['StateName'].nunique()}")
district_count = data[["StateName", "DistrictName"]].drop_duplicates().shape[0]
print(f"Districts: {district_count}")
print(f"Missing transaction values: {data['TransactionValueRaw'].isna().sum()}")
print(f"Missing transaction counts: {data['TransactionCountRaw'].isna().sum()}")

value_present = data["TransactionValueRaw"].notna()
count_present = data["TransactionCountRaw"].notna()
metric_availability = np.select(
    [value_present & count_present, value_present, count_present],
    ["Both present", "Value only", "Count only"],
    default="Both missing",
)
print("Metric availability:")
print(pd.Series(metric_availability).value_counts().sort_index().to_string())
monthly = (
    data.groupby("MonthStart", as_index=False)
    .agg(
        TotalTransactionValue=(
            "TransactionValueRaw",
            lambda values: values.sum(min_count=1),
        ),
        TotalTransactionCount=(
            "TransactionCountRaw",
            lambda values: values.sum(min_count=1),
        ),
        MissingValueRows=(
            "TransactionValueRaw",
            lambda values: values.isna().sum(),
        ),
        MissingCountRows=(
            "TransactionCountRaw",
            lambda values: values.isna().sum(),
        ),
    )
    .sort_values("MonthStart")
)

# Calculate average value using only rows where both measures are present.
matched_rows = data.dropna(
    subset=["TransactionValueRaw", "TransactionCountRaw"]
)

matched_monthly = (
    matched_rows.groupby("MonthStart", as_index=False)
    .agg(
        MatchedValue=("TransactionValueRaw", "sum"),
        MatchedCount=("TransactionCountRaw", "sum"),
    )
)

matched_monthly["AverageValuePerTransaction"] = np.divide(
    matched_monthly["MatchedValue"].to_numpy(),
    matched_monthly["MatchedCount"].to_numpy(),
    out=np.full(len(matched_monthly), np.nan),
    where=matched_monthly["MatchedCount"].to_numpy() != 0,
)

monthly = monthly.merge(
    matched_monthly[
        ["MonthStart", "AverageValuePerTransaction"]
    ],
    on="MonthStart",
    how="left",
)

monthly["PreviousMonthValue"] = monthly["TotalTransactionValue"].shift(1)
monthly["PreviousMonthCount"] = monthly["TotalTransactionCount"].shift(1)

monthly["ValueChange"] = (
    monthly["TotalTransactionValue"] - monthly["PreviousMonthValue"]
)
monthly["CountChange"] = (
    monthly["TotalTransactionCount"] - monthly["PreviousMonthCount"]
)

monthly["ValueChangePct"] = np.divide(
    monthly["ValueChange"].to_numpy(),
    monthly["PreviousMonthValue"].to_numpy(),
    out=np.full(len(monthly), np.nan),
    where=(
        monthly["PreviousMonthValue"].notna().to_numpy()
        & (monthly["PreviousMonthValue"].to_numpy() != 0)
    ),
) * 100

monthly["CountChangePct"] = np.divide(
    monthly["CountChange"].to_numpy(),
    monthly["PreviousMonthCount"].to_numpy(),
    out=np.full(len(monthly), np.nan),
    where=(
        monthly["PreviousMonthCount"].notna().to_numpy()
        & (monthly["PreviousMonthCount"].to_numpy() != 0)
    ),
) * 100

print("\nMonthly UPI district-reported summary:")
print(
    monthly[
        [
            "MonthStart",
            "TotalTransactionValue",
            "TotalTransactionCount",
            "ValueChangePct",
            "CountChangePct",
            "AverageValuePerTransaction",
            "MissingValueRows",
            "MissingCountRows",
        ]
    ].to_string(index=False)
)

