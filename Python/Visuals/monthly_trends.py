from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


project_folder = Path(__file__).resolve().parents[2]
input_file = (
    project_folder / "Data" / "processed" / "upi_district_monthly.csv"
)
chart_file = (
    project_folder / "Documentation" / "python_monthly_trends.png"
)
chart_file.parent.mkdir(parents=True, exist_ok=True)

data = pd.read_csv(input_file, dtype=str, keep_default_na=False)

data["MonthStart"] = pd.to_datetime(
    data["ReportMonthRaw"],
    format="%Y-%m-%d",
    errors="coerce",
)

for column in ["TransactionValueRaw", "TransactionCountRaw"]:
    data[column] = pd.to_numeric(
        data[column].replace(r"^\s*$", np.nan, regex=True),
        errors="coerce",
    )

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
    )
    .sort_values("MonthStart")
)

# For average value, include only rows where both measures are present.
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
    matched_monthly[["MonthStart", "AverageValuePerTransaction"]],
    on="MonthStart",
    how="left",
)

monthly["ValueChangePct"] = (
    monthly["TotalTransactionValue"].pct_change(fill_method=None) * 100
)
monthly["CountChangePct"] = (
    monthly["TotalTransactionCount"].pct_change(fill_method=None) * 100
)

month_labels = monthly["MonthStart"].dt.strftime("%b %Y")

figure, axes = plt.subplots(2, 2, figsize=(14, 9))
figure.suptitle(
    "UPI Activity Reported by District",
    fontsize=16,
    fontweight="bold",
)

axes[0, 0].plot(
    month_labels,
    monthly["TotalTransactionValue"] / 1_000_000_000_000,
    marker="o",
    color="#176B87",
    linewidth=2.5,
)
axes[0, 0].set_title("Transaction Value")
axes[0, 0].set_ylabel("Trillion source units")
axes[0, 0].grid(axis="y", alpha=0.25)

axes[0, 1].plot(
    month_labels,
    monthly["TotalTransactionCount"] / 1_000_000_000,
    marker="o",
    color="#F08A5D",
    linewidth=2.5,
)
axes[0, 1].set_title("Transaction Count")
axes[0, 1].set_ylabel("Billions of transactions")
axes[0, 1].grid(axis="y", alpha=0.25)

axes[1, 0].plot(
    month_labels,
    monthly["AverageValuePerTransaction"],
    marker="o",
    color="#6A4C93",
    linewidth=2.5,
)
axes[1, 0].set_title("Average Value per Reported Transaction")
axes[1, 0].set_ylabel("Source value units per transaction")
axes[1, 0].grid(axis="y", alpha=0.25)

axes[1, 1].plot(
    month_labels,
    monthly["ValueChangePct"],
    marker="o",
    label="Value change %",
    color="#176B87",
    linewidth=2.5,
)
axes[1, 1].plot(
    month_labels,
    monthly["CountChangePct"],
    marker="o",
    label="Count change %",
    color="#F08A5D",
    linewidth=2.5,
)
axes[1, 1].axhline(0, color="#555555", linewidth=1)
axes[1, 1].set_title("Month-over-Month Change")
axes[1, 1].set_ylabel("Change (%)")
axes[1, 1].grid(axis="y", alpha=0.25)
axes[1, 1].legend()

for axis in axes.flat:
    axis.tick_params(axis="x", rotation=30)

figure.tight_layout(rect=[0, 0, 1, 0.96])
figure.savefig(chart_file, dpi=180, bbox_inches="tight")
plt.close(figure)

print(f"Chart saved to: {chart_file}")


