from pathlib import Path

import numpy as np
import pandas as pd


project_folder = Path(__file__).resolve().parents[2]
input_file = (
    project_folder / "Data" / "processed" / "upi_district_monthly.csv"
)

data = pd.read_csv(input_file, dtype=str, keep_default_na=False)

data["MonthStart"] = pd.to_datetime(
    data["ReportMonthRaw"],
    format="%Y-%m-%d",
    errors="coerce",
)

if data["MonthStart"].isna().any():
    raise ValueError("Some report months could not be converted to dates.")

if data.duplicated(["MonthStart", "StateName", "DistrictName"]).any():
    raise ValueError("Duplicate district-month rows were found.")

# Convert metric text to numbers while preserving blanks as missing values.
for column in ["TransactionValueRaw", "TransactionCountRaw"]:
    raw_values = data[column].copy()
    has_value = raw_values.str.strip().ne("")

    converted_values = pd.to_numeric(
        raw_values.replace(r"^\s*$", np.nan, regex=True),
        errors="coerce",
    )

    if (has_value & converted_values.isna()).any():
        raise ValueError(f"Invalid numeric values found in {column}.")

    data[column] = converted_values

# Summarize each district for each month.
district_month = (
    data.groupby(
        ["MonthStart", "StateName", "DistrictName"],
        as_index=False,
    )
    .agg(
        TransactionValue=(
            "TransactionValueRaw",
            lambda values: values.sum(min_count=1),
        ),
        TransactionCount=(
            "TransactionCountRaw",
            lambda values: values.sum(min_count=1),
        ),
    )
    .sort_values(["StateName", "DistrictName", "MonthStart"])
    .reset_index(drop=True)
)

# Find each district's previous month and calculate monthly percentage changes.
district_groups = district_month.groupby(["StateName", "DistrictName"])

district_month["PreviousMonth"] = district_groups["MonthStart"].shift(1)
district_month["PreviousValue"] = district_groups["TransactionValue"].shift(1)
district_month["PreviousCount"] = district_groups["TransactionCount"].shift(1)

month_number = (
    district_month["MonthStart"].dt.year * 12
    + district_month["MonthStart"].dt.month
)
previous_month_number = (
    district_month["PreviousMonth"].dt.year * 12
    + district_month["PreviousMonth"].dt.month
)
consecutive_months = (month_number - previous_month_number) == 1

valid_value_change = (
    consecutive_months
    & district_month["TransactionValue"].notna()
    & district_month["PreviousValue"].notna()
    & district_month["PreviousValue"].ne(0)
)
district_month["ValueChangePct"] = np.divide(
    100 * (
        district_month["TransactionValue"].to_numpy()
        - district_month["PreviousValue"].to_numpy()
    ),
    district_month["PreviousValue"].to_numpy(),
    out=np.full(len(district_month), np.nan),
    where=valid_value_change.to_numpy(),
)

valid_count_change = (
    consecutive_months
    & district_month["TransactionCount"].notna()
    & district_month["PreviousCount"].notna()
    & district_month["PreviousCount"].ne(0)
)
district_month["CountChangePct"] = np.divide(
    100 * (
        district_month["TransactionCount"].to_numpy()
        - district_month["PreviousCount"].to_numpy()
    ),
    district_month["PreviousCount"].to_numpy(),
    out=np.full(len(district_month), np.nan),
    where=valid_count_change.to_numpy(),
)

# Use the latest month and the month three months before it for recent growth.
latest_month = district_month["MonthStart"].max()
start_month = latest_month - pd.DateOffset(months=3)
month_count = district_month["MonthStart"].nunique()

if start_month not in set(district_month["MonthStart"]):
    raise ValueError("The dataset does not contain the recent-growth start month.")

start_values = (
    district_month.loc[
        district_month["MonthStart"] == start_month,
        ["StateName", "DistrictName", "TransactionValue", "TransactionCount"],
    ]
    .rename(
        columns={
            "TransactionValue": "StartValue",
            "TransactionCount": "StartCount",
        }
    )
)

latest_values = (
    district_month.loc[
        district_month["MonthStart"] == latest_month,
        ["StateName", "DistrictName", "TransactionValue", "TransactionCount"],
    ]
    .rename(
        columns={
            "TransactionValue": "LatestValue",
            "TransactionCount": "LatestCount",
        }
    )
)

district_metrics = (
    district_month.groupby(["StateName", "DistrictName"], as_index=False)
    .agg(
        ObservedMonths=("MonthStart", "nunique"),
        ValidValueChangeMonths=("ValueChangePct", "count"),
        ValidCountChangeMonths=("CountChangePct", "count"),
        ValueVolatilityPct=("ValueChangePct", "std"),
        CountVolatilityPct=("CountChangePct", "std"),
    )
    .merge(start_values, on=["StateName", "DistrictName"], how="inner")
    .merge(latest_values, on=["StateName", "DistrictName"], how="inner")
)

# Keep districts with complete metric history for the period.
required_changes = month_count - 1
eligible = district_metrics.loc[
    district_metrics["ObservedMonths"].eq(month_count)
    & district_metrics["ValidValueChangeMonths"].eq(required_changes)
    & district_metrics["ValidCountChangeMonths"].eq(required_changes)
    & district_metrics["StartValue"].notna()
    & district_metrics["StartCount"].notna()
    & district_metrics["LatestValue"].notna()
    & district_metrics["LatestCount"].notna()
].copy()

if eligible.empty:
    raise ValueError("No districts meet the complete-history requirement.")

eligible["ValueGrowthPct"] = (
    100 * (eligible["LatestValue"] - eligible["StartValue"])
    / eligible["StartValue"]
)
eligible["CountGrowthPct"] = (
    100 * (eligible["LatestCount"] - eligible["StartCount"])
    / eligible["StartCount"]
)

# SQL PERCENT_RANK uses (rank - 1) / (row count - 1).
def sql_percent_rank(values, ascending):
    ranks = values.rank(method="min", ascending=ascending)
    row_count = len(values)

    if row_count <= 1:
        return pd.Series(0.0, index=values.index)

    return (ranks - 1) / (row_count - 1)


eligible["ActivityScore"] = (
    1 - sql_percent_rank(eligible["LatestValue"], ascending=False)
    + 1 - sql_percent_rank(eligible["LatestCount"], ascending=False)
) / 2

eligible["GrowthScore"] = (
    1 - sql_percent_rank(eligible["ValueGrowthPct"], ascending=False)
    + 1 - sql_percent_rank(eligible["CountGrowthPct"], ascending=False)
) / 2

eligible["StabilityScore"] = (
    1 - sql_percent_rank(eligible["ValueVolatilityPct"], ascending=True)
    + 1 - sql_percent_rank(eligible["CountVolatilityPct"], ascending=True)
) / 2

eligible["ShortlistScore"] = 100 * (
    0.40 * eligible["ActivityScore"]
    + 0.40 * eligible["GrowthScore"]
    + 0.20 * eligible["StabilityScore"]
)

eligible["ActivityScorePct"] = eligible["ActivityScore"] * 100
eligible["GrowthScorePct"] = eligible["GrowthScore"] * 100
eligible["StabilityScorePct"] = eligible["StabilityScore"] * 100

shortlist = eligible.sort_values(
    ["ShortlistScore", "LatestValue", "StateName", "DistrictName"],
    ascending=[False, False, True, True],
).head(20)

print(f"Recent growth period: {start_month:%Y-%m} to {latest_month:%Y-%m}")
print(f"Eligible districts: {len(eligible):,}")
print("Top 20 districts under the SQL-aligned shortlist rule:")

print(
    shortlist[
        [
            "StateName",
            "DistrictName",
            "LatestValue",
            "LatestCount",
            "ValueGrowthPct",
            "CountGrowthPct",
            "ValueVolatilityPct",
            "CountVolatilityPct",
            "ActivityScorePct",
            "GrowthScorePct",
            "StabilityScorePct",
            "ShortlistScore",
        ]
    ].to_string(
        index=False,
        formatters={
            "LatestValue": "{:,.2f}".format,
            "LatestCount": "{:,.0f}".format,
            "ValueGrowthPct": "{:.6f}".format,
            "CountGrowthPct": "{:.6f}".format,
            "ValueVolatilityPct": "{:.6f}".format,
            "CountVolatilityPct": "{:.6f}".format,
            "ActivityScorePct": "{:.6f}".format,
            "GrowthScorePct": "{:.6f}".format,
            "StabilityScorePct": "{:.6f}".format,
            "ShortlistScore": "{:.6f}".format,
        },
    )
)
