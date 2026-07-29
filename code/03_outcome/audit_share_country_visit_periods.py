"""Audit SHARE wave 4 and wave 6 interview periods by country.

This is a source audit only. It reads selected columns from the Gateway
harmonized SHARE file and does not modify raw data or construct outcomes.
"""

from __future__ import annotations

import json
import logging
import platform
import sys
from pathlib import Path

import pandas as pd
import pyreadstat


RUN_DATE = "2026-07-28"
SCRIPT_PATH = Path(__file__).resolve()
PROJECT_ROOT = SCRIPT_PATH.parents[2]
RAW_PATH = PROJECT_ROOT.parent / "sql" / "share harmonised" / "GH_SHARE_g.dta"
RESULT_DIR = PROJECT_ROOT / "results" / "share_country_visit_period_audit"
LOG_DIR = PROJECT_ROOT / "logs"


REQUIRED_COLUMNS = [
    "mergeid",
    "country",
    "isocountry",
    "r4iwy",
    "r4iwm",
    "r6iwy",
    "r6iwm",
    "r4iwstat",
    "r6iwstat",
]


def configure_logging() -> Path:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log_path = LOG_DIR / f"share_country_visit_period_audit_{RUN_DATE}.log"
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[logging.FileHandler(log_path, encoding="utf-8"), logging.StreamHandler()],
        force=True,
    )
    return log_path


def normalize_label_map(value_labels: dict) -> dict:
    """Normalize pyreadstat value-label keys for numeric pandas values."""
    out = {}
    for key, value in value_labels.items():
        try:
            out[int(float(key))] = str(value)
        except (TypeError, ValueError):
            out[str(key)] = str(value)
    return out


def clean_component(series: pd.Series) -> pd.Series:
    return pd.to_numeric(series, errors="coerce")


def make_visit_date(year: pd.Series, month: pd.Series) -> tuple[pd.Series, pd.Series]:
    year_num = clean_component(year)
    month_num = clean_component(month)
    component_valid = (
        year_num.notna()
        & month_num.notna()
        & year_num.between(1900, 2100)
        & month_num.between(1, 12)
    )
    date = pd.to_datetime(
        {
            "year": year_num.where(component_valid),
            "month": month_num.where(component_valid),
            "day": pd.Series(1, index=year.index),
        },
        errors="coerce",
    )
    return date, component_valid & date.notna()


def month_span(start: pd.Timestamp, end: pd.Timestamp) -> int | None:
    if pd.isna(start) or pd.isna(end):
        return None
    return int((end.year - start.year) * 12 + end.month - start.month + 1)


def fmt_date(value: pd.Timestamp) -> str:
    return "" if pd.isna(value) else value.strftime("%Y-%m")


def main() -> None:
    log_path = configure_logging()
    RESULT_DIR.mkdir(parents=True, exist_ok=True)

    logging.info("START SHARE country visit-period audit")
    logging.info("Raw source: %s", RAW_PATH)
    if not RAW_PATH.exists():
        raise FileNotFoundError(f"Missing raw input: {RAW_PATH}")

    df, meta = pyreadstat.read_dta(
        str(RAW_PATH),
        usecols=REQUIRED_COLUMNS,
        apply_value_formats=False,
    )
    missing_columns = sorted(set(REQUIRED_COLUMNS) - set(df.columns))
    if missing_columns:
        raise ValueError(f"Missing required columns: {missing_columns}")
    logging.info("Loaded %d rows and %d selected columns", len(df), len(df.columns))

    country_labels = normalize_label_map(meta.variable_value_labels.get("country", {}))
    iso_labels = normalize_label_map(meta.variable_value_labels.get("isocountry", {}))

    df["country_id"] = pd.to_numeric(df["country"], errors="coerce")
    df["isocountry_num"] = pd.to_numeric(df["isocountry"], errors="coerce")
    df["r4_status_num"] = pd.to_numeric(df["r4iwstat"], errors="coerce")
    df["r6_status_num"] = pd.to_numeric(df["r6iwstat"], errors="coerce")
    df["r4_date"], df["r4_date_valid"] = make_visit_date(df["r4iwy"], df["r4iwm"])
    df["r6_date"], df["r6_date_valid"] = make_visit_date(df["r6iwy"], df["r6iwm"])
    df["r4_respondent_visit"] = df["r4_status_num"].eq(1)
    df["r6_respondent_visit"] = df["r6_status_num"].eq(1)
    df["r4_valid_visit"] = df["r4_respondent_visit"] & df["r4_date_valid"]
    df["r6_valid_visit"] = df["r6_respondent_visit"] & df["r6_date_valid"]
    df["paired_valid_visit"] = df["r4_valid_visit"] & df["r6_valid_visit"]
    df["interval_months"] = pd.NA
    paired = df["paired_valid_visit"]
    df.loc[paired, "interval_months"] = (
        (df.loc[paired, "r6_date"].dt.year - df.loc[paired, "r4_date"].dt.year) * 12
        + df.loc[paired, "r6_date"].dt.month
        - df.loc[paired, "r4_date"].dt.month
    ).astype("Int64")

    # Keep the date ranges tied to actual completed respondent interviews.
    rows = []
    monthly_rows = []
    pair_rows = []
    for (country_id, iso_num), group in df.groupby(
        ["country_id", "isocountry_num"], dropna=False, sort=True
    ):
        country_label = country_labels.get(country_id, "UNKNOWN")
        iso_label = iso_labels.get(iso_num, "UNKNOWN")
        base = group[group["r4_valid_visit"]]
        follow = group[group["r6_valid_visit"]]
        pair = group[group["paired_valid_visit"]]

        def date_stats(subset: pd.DataFrame, prefix: str) -> dict:
            if subset.empty:
                return {
                    f"{prefix}_n": 0,
                    f"{prefix}_min": "",
                    f"{prefix}_max": "",
                    f"{prefix}_span_months": None,
                    f"{prefix}_unique_months": 0,
                    f"{prefix}_year_min": None,
                    f"{prefix}_year_max": None,
                }
            start = subset[f"{prefix}_date"].min()
            end = subset[f"{prefix}_date"].max()
            return {
                f"{prefix}_n": int(len(subset)),
                f"{prefix}_min": fmt_date(start),
                f"{prefix}_max": fmt_date(end),
                f"{prefix}_span_months": month_span(start, end),
                f"{prefix}_unique_months": int(subset[f"{prefix}_date"].dt.to_period("M").nunique()),
                f"{prefix}_year_min": int(subset[f"{prefix}_date"].dt.year.min()),
                f"{prefix}_year_max": int(subset[f"{prefix}_date"].dt.year.max()),
            }

        interval = pd.to_numeric(pair["interval_months"], errors="coerce")
        row = {
            "country_id": int(country_id) if pd.notna(country_id) else None,
            "country": country_label,
            "isocountry": int(iso_num) if pd.notna(iso_num) else None,
            "isocountry_label": iso_label,
            "source_rows": int(len(group)),
            "r4_status_respondent_n": int(group["r4_respondent_visit"].sum()),
            "r4_date_any_valid_n": int(group["r4_date_valid"].sum()),
            "r6_status_respondent_n": int(group["r6_respondent_visit"].sum()),
            "r6_date_any_valid_n": int(group["r6_date_valid"].sum()),
            "paired_valid_n": int(len(pair)),
            "paired_interval_min_months": int(interval.min()) if interval.notna().any() else None,
            "paired_interval_median_months": float(interval.median()) if interval.notna().any() else None,
            "paired_interval_max_months": int(interval.max()) if interval.notna().any() else None,
            "paired_negative_interval_n": int((interval < 0).sum()),
            "paired_interval_48_month_n": int((interval == 48).sum()),
            "paired_interval_not_48_month_n": int((interval.notna() & (interval != 48)).sum()),
        }
        row.update(date_stats(base, "r4"))
        row.update(date_stats(follow, "r6"))
        rows.append(row)

        for stage, subset, date_col in [("r4_2011_baseline", base, "r4_date"), ("r6_2015_followup", follow, "r6_date")]:
            if not subset.empty:
                monthly = (
                    subset.assign(year=subset[date_col].dt.year, month=subset[date_col].dt.month)
                    .groupby(["year", "month"], as_index=False)
                    .size()
                    .rename(columns={"size": "n"})
                )
                for record in monthly.to_dict("records"):
                    monthly_rows.append(
                        {
                            "country_id": row["country_id"],
                            "country": country_label,
                            "isocountry": row["isocountry"],
                            "stage": stage,
                            "year": int(record["year"]),
                            "month": int(record["month"]),
                            "n": int(record["n"]),
                        }
                    )

        for _, record in pair[["mergeid", "r4_date", "r6_date", "interval_months"]].iterrows():
            pair_rows.append(
                {
                    "mergeid": record["mergeid"],
                    "country_id": row["country_id"],
                    "country": country_label,
                    "isocountry": row["isocountry"],
                    "r4_visit_month": fmt_date(record["r4_date"]),
                    "r6_visit_month": fmt_date(record["r6_date"]),
                    "interval_months": int(record["interval_months"]),
                }
            )

    summary = pd.DataFrame(rows).sort_values(["country_id"], na_position="last")
    monthly = pd.DataFrame(monthly_rows).sort_values(
        ["stage", "country_id", "year", "month"]
    )
    pairs = pd.DataFrame(pair_rows).sort_values(["country_id", "mergeid"])

    field_definitions = pd.DataFrame(
        [
            {
                "stage": "r4_2011_baseline",
                "field_name": "r4iwy",
                "field_label": "r4iwy:w4 r interview year",
                "status_field": "r4iwstat",
                "status_label": "1.resp, alive",
                "interpretation": "Completed respondent interview year; month field r4iwm.",
            },
            {
                "stage": "r4_2011_baseline",
                "field_name": "r4iwm",
                "field_label": "r4iwm:w4 r interview month",
                "status_field": "r4iwstat",
                "status_label": "1.resp, alive",
                "interpretation": "Completed respondent interview month; year field r4iwy.",
            },
            {
                "stage": "r6_2015_followup",
                "field_name": "r6iwy",
                "field_label": "r6iwy:w6 r interview year",
                "status_field": "r6iwstat",
                "status_label": "1.resp, alive",
                "interpretation": "Completed respondent interview year; month field r6iwm.",
            },
            {
                "stage": "r6_2015_followup",
                "field_name": "r6iwm",
                "field_label": "r6iwm:w6 r interview month",
                "status_field": "r6iwstat",
                "status_label": "1.resp, alive",
                "interpretation": "Completed respondent interview month; year field r6iwy.",
            },
            {
                "stage": "both",
                "field_name": "country",
                "field_label": "Country identifier",
                "status_field": "",
                "status_label": "",
                "interpretation": "SHARE country identifier with value labels.",
            },
            {
                "stage": "both",
                "field_name": "isocountry",
                "field_label": "UN numerical country code",
                "status_field": "",
                "status_label": "",
                "interpretation": "Country cross-check only; country is the grouping field.",
            },
        ]
    )

    summary_path = RESULT_DIR / f"share_country_visit_period_summary_{RUN_DATE}.csv"
    monthly_path = RESULT_DIR / f"share_country_visit_period_monthly_{RUN_DATE}.csv"
    pairs_path = RESULT_DIR / f"share_country_visit_period_pairs_{RUN_DATE}.csv"
    fields_path = RESULT_DIR / f"share_country_visit_period_field_definitions_{RUN_DATE}.csv"
    metadata_path = RESULT_DIR / f"share_country_visit_period_metadata_{RUN_DATE}.json"
    report_path = RESULT_DIR / f"share_country_visit_period_audit_report_{RUN_DATE}.md"

    summary.to_csv(summary_path, index=False)
    monthly.to_csv(monthly_path, index=False)
    pairs.to_csv(pairs_path, index=False)
    field_definitions.to_csv(fields_path, index=False)

    metadata = {
        "run_date": RUN_DATE,
        "raw_source": str(RAW_PATH),
        "source_rows": int(len(df)),
        "selected_columns": REQUIRED_COLUMNS,
        "country_count": int(summary["country_id"].nunique()),
        "baseline_valid_respondent_dates": int(df["r4_valid_visit"].sum()),
        "followup_valid_respondent_dates": int(df["r6_valid_visit"].sum()),
        "paired_valid_dates": int(df["paired_valid_visit"].sum()),
        "baseline_year_values": sorted(df.loc[df["r4_valid_visit"], "r4_date"].dt.year.unique().tolist()),
        "followup_year_values": sorted(df.loc[df["r6_valid_visit"], "r6_date"].dt.year.unique().tolist()),
        "python": sys.version,
        "platform": platform.platform(),
        "pandas": pd.__version__,
        "pyreadstat": getattr(pyreadstat, "__version__", "unknown"),
    }
    metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")

    overall_base = df[df["r4_valid_visit"]]["r4_date"]
    overall_follow = df[df["r6_valid_visit"]]["r6_date"]
    overall_interval = pd.to_numeric(df.loc[df["paired_valid_visit"], "interval_months"], errors="coerce")
    report = f"""# SHARE country-specific visit-period audit

Run date: {RUN_DATE}. The raw Gateway harmonized file was read with selected columns only; no raw data or mortality outcomes were modified.

## Scope and fields

- Source: `{RAW_PATH}`
- Country grouping: `country` (29 labeled SHARE countries); `isocountry` is retained as a cross-check.
- Baseline: wave 4, 2011 interview year/month, `r4iwy`/`r4iwm`, restricted to `r4iwstat == 1` for completed respondent interviews.
- Follow-up: wave 6, 2015 interview year/month, `r6iwy`/`r6iwm`, restricted to `r6iwstat == 1`.
- A month is represented by its first calendar day because the Gateway fields contain year and month but no interview day.

## Overall findings

- Source rows: **{len(df):,}**.
- Valid wave-4 respondent interview months: **{int(df['r4_valid_visit'].sum()):,}**; observed range **{fmt_date(overall_base.min())} to {fmt_date(overall_base.max())}**; years observed: **{', '.join(str(int(x)) for x in sorted(overall_base.dt.year.unique()))}**.
- Valid wave-6 respondent interview months: **{int(df['r6_valid_visit'].sum()):,}**; observed range **{fmt_date(overall_follow.min())} to {fmt_date(overall_follow.max())}**; years observed: **{', '.join(str(int(x)) for x in sorted(overall_follow.dt.year.unique()))}**.
- Respondents with valid dates in both waves: **{int(df['paired_valid_visit'].sum()):,}**; paired interval range **{int(overall_interval.min())} to {int(overall_interval.max())} months**, median **{overall_interval.median():.1f} months**.
- The nominal 2011-to-2015 interval is not identical for every respondent: the country table reports the number at exactly 48 months and the number outside 48 months.

## Interpretation boundary

The table describes fieldwork timing and the resulting variation in the calendar interval between wave 4 and wave 6. It does not define the final mortality censoring date, impute missing interview dates, or estimate country effects.

The 2010 and 2012 wave-4 values are retained as observed source values. They should not be silently recoded to 2011; if the analysis requires a fixed 2011 baseline, those records need an explicit inclusion rule decided by Claude/PI.

## Outputs

- Country summary: `{summary_path}`
- Country-month distribution: `{monthly_path}`
- Paired respondent intervals: `{pairs_path}`
- Field definitions: `{fields_path}`
- Run metadata: `{metadata_path}`
- Log: `{log_path}`
"""
    report_path.write_text(report, encoding="utf-8")
    logging.info("Wrote summary: %s", summary_path)
    logging.info("Wrote monthly distribution: %s", monthly_path)
    logging.info("Wrote paired intervals: %s", pairs_path)
    logging.info("Wrote report: %s", report_path)
    logging.info("DONE")


if __name__ == "__main__":
    main()
