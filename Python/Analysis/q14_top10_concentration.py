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

# Convert metric text to numbers. Blank cells stay missing.
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

# Summarize each district and month.
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
)

# Rank by value and count separately.
value_ranked = district_month.sort_values(
    ["MonthStart", "TransactionValue", "StateName", "DistrictName"],
    ascending=[True, False, True, True],
    na_position="last",
).copy()
value_ranked["ValueRank"] = (
    value_ranked.groupby("MonthStart").cumcount() + 1
)

count_ranked = district_month.sort_values(
    ["MonthStart", "TransactionCount", "StateName", "DistrictName"],
    ascending=[True, False, True, True],
    na_position="last",
).copy()
count_ranked["CountRank"] = (
    count_ranked.groupby("MonthStart").cumcount() + 1
)

# Calculate monthly totals for each metric.
monthly_totals = (
    district_month.groupby("MonthStart", as_index=False)
    .agg(
        TotalTransactionValue=(
            "TransactionValue",
            lambda values: values.sum(min_count=1),
        ),
        TotalTransactionCount=(
            "TransactionCount",
            lambda values: values.sum(min_count=1),
        ),
    )
)

# Sum the top 10 districts, using each metric's own ranking.
top10_value = (
    value_ranked.loc[value_ranked["ValueRank"] <= 10]
    .groupby("MonthStart", as_index=False)
    .agg(
        Top10TransactionValue=(
            "TransactionValue",
            lambda values: values.sum(min_count=1),
        )
    )
)

top10_count = (
    count_ranked.loc[count_ranked["CountRank"] <= 10]
    .groupby("MonthStart", as_index=False)
    .agg(
        Top10TransactionCount=(
            "TransactionCount",
            lambda values: values.sum(min_count=1),
        )
    )
)

concentration = (
    monthly_totals
    .merge(top10_value, on="MonthStart", how="left")
    .merge(top10_count, on="MonthStart", how="left")
    .sort_values("MonthStart")
)

concentration["Top10ValueSharePct"] = np.divide(
    concentration["Top10TransactionValue"].to_numpy(),
    concentration["TotalTransactionValue"].to_numpy(),
    out=np.full(len(concentration), np.nan),
    where=(
        concentration["TotalTransactionValue"].notna().to_numpy()
        & (concentration["TotalTransactionValue"].to_numpy() != 0)
    ),
) * 100

concentration["Top10CountSharePct"] = np.divide(
    concentration["Top10TransactionCount"].to_numpy(),
    concentration["TotalTransactionCount"].to_numpy(),
    out=np.full(len(concentration), np.nan),
    where=(
        concentration["TotalTransactionCount"].notna().to_numpy()
        & (concentration["TotalTransactionCount"].to_numpy() != 0)
    ),
) * 100

print("Python top-10 district concentration by month:")
print(
    concentration[
        ["MonthStart", "Top10ValueSharePct", "Top10CountSharePct"]
    ].to_string(
        index=False,
        formatters={
            "Top10ValueSharePct": "{:.4f}".format,
            "Top10CountSharePct": "{:.4f}".format,
        },
    )
)
