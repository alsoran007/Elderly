"""Recompute current four-year mortality events for KLoSA, SHARE, and MHAS.

Raw files are read only.  The primary window follows the project decision log:
baseline year through baseline year + 4 (KLoSA 2012-2016, SHARE 2011-2015,
MHAS 2012-2016).  A month-level exact four-year sensitivity is also reported
for SHARE and MHAS because their EOL dates have month precision.
"""

from __future__ import annotations

import json
import logging
import platform
import sys
from datetime import date
from pathlib import Path

import pandas as pd
import pyreadstat


RUN_DATE = "2026-07-28"
PROJECT_ROOT = Path(__file__).resolve().parents[2]
RAW_ROOT = PROJECT_ROOT.parent / "sql"
RESULT_DIR = PROJECT_ROOT / "results" / "current_four_year_event_audit"
LOG_DIR = PROJECT_ROOT / "logs"
RESULT_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)


def configure_logging() -> Path:
    log_path = LOG_DIR / f"current_four_year_event_recompute_{RUN_DATE}.log"
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[logging.FileHandler(log_path, encoding="utf-8"), logging.StreamHandler()],
        force=True,
    )
    return log_path


def read_dta(path: Path, columns: list[str]) -> pd.DataFrame:
    if not path.exists():
        raise FileNotFoundError(path)
    df, _ = pyreadstat.read_dta(str(path), usecols=columns)
    return df


def numeric(series: pd.Series) -> pd.Series:
    return pd.to_numeric(series, errors="coerce")


def normalized_id(series: pd.Series) -> pd.Series:
    """Normalize Stata numeric IDs without changing character IDs."""
    out = series.astype("string").str.strip()
    numeric_values = pd.to_numeric(out, errors="coerce")
    numeric_mask = numeric_values.notna() & out.str.fullmatch(r"[-+]?\d+(?:\.0+)?", na=False)
    out.loc[numeric_mask] = numeric_values.loc[numeric_mask].map(
        lambda x: str(int(x)) if float(x).is_integer() else str(x)
    )
    return out


def make_month_date(year: pd.Series, month: pd.Series) -> pd.Series:
    y = numeric(year)
    m = numeric(month)
    valid = y.between(1900, 2100) & m.between(1, 12)
    result = pd.Series(pd.NaT, index=year.index, dtype="datetime64[ns]")
    result.loc[valid] = pd.to_datetime(
        pd.DataFrame({"year": y.loc[valid], "month": m.loc[valid], "day": 1}),
        errors="coerce",
    )
    return result


def make_day_date(year: pd.Series, month: pd.Series, day: pd.Series) -> pd.Series:
    y, m, d = numeric(year), numeric(month), numeric(day)
    valid = y.between(1900, 2100) & m.between(1, 12) & d.between(1, 31)
    result = pd.Series(pd.NaT, index=year.index, dtype="datetime64[ns]")
    result.loc[valid] = pd.to_datetime(
        pd.DataFrame({"year": y.loc[valid], "month": m.loc[valid], "day": d.loc[valid]}),
        errors="coerce",
    )
    return result


def audit_klosa() -> tuple[pd.DataFrame, dict]:
    base_path = RAW_ROOT / "KLOSA" / "KLoSA 1-9th wave (STATA)" / "w04_e.dta"
    base = read_dta(
        base_path,
        ["pid", "w04A002_age", "w04mniw_y", "w04mniw_m", "w04mniw_d"],
    )
    base = base.rename(
        columns={
            "pid": "person_id_raw",
            "w04A002_age": "baseline_age",
            "w04mniw_y": "baseline_year",
            "w04mniw_m": "baseline_month",
            "w04mniw_d": "baseline_day",
        }
    )
    base["person_id"] = normalized_id(base["person_id_raw"])
    base["baseline_age"] = numeric(base["baseline_age"])
    base["baseline_date"] = make_day_date(
        base["baseline_year"], base["baseline_month"], base["baseline_day"]
    )
    base_60 = base[base["baseline_age"] >= 60].copy()

    exit_specs = [
        ("w04", RAW_ROOT / "KLOSA" / "w04_exit_e.dta", "w04Xa010y", "w04Xa010m", "w04Xa010d"),
        ("w05", RAW_ROOT / "KLOSA" / "w05_exit_e.dta", "w05xA010Y", "w05xA010M", "w05xA010D"),
        ("w06", RAW_ROOT / "KLOSA" / "w06_Exit_e.dta", "w06x_A010Y", "w06x_A010M", "w06x_A010D"),
        ("w07", RAW_ROOT / "KLOSA" / "w07_exit_e.dta", "w07x_a010y", "w07x_a010m", "w07x_a010d"),
        ("w08", RAW_ROOT / "KLOSA" / "KLoSA 8th wave_EXIT" / "w08_exit_e.dta", "w08x_a010Y", "w08x_a010M", "w08x_a010D"),
        ("w09", RAW_ROOT / "KLOSA" / "KLoSA 9 wave Exit" / "Exit09_e.dta", "w09X_A010Y", "w09X_A010M", "w09X_A010D"),
    ]
    exit_rows: list[pd.DataFrame] = []
    for wave, path, y_col, m_col, d_col in exit_specs:
        d = read_dta(path, ["pid", y_col, m_col, d_col]).rename(
            columns={"pid": "person_id_raw", y_col: "death_year", m_col: "death_month", d_col: "death_day"}
        )
        d["person_id"] = normalized_id(d["person_id_raw"])
        d["death_date"] = make_day_date(d["death_year"], d["death_month"], d["death_day"])
        d["exit_wave"] = wave
        exit_rows.append(d[["person_id", "death_year", "death_month", "death_day", "death_date", "exit_wave"]])
    exits = pd.concat(exit_rows, ignore_index=True)
    exits = exits.dropna(subset=["person_id"])
    exits = exits.sort_values(["person_id", "death_date", "exit_wave"], na_position="last")
    duplicate_id_rows = int(exits.duplicated("person_id", keep=False).sum())
    exits = exits.drop_duplicates("person_id", keep="first")

    audit = base_60.merge(exits, on="person_id", how="left", validate="one_to_one")
    audit["death_date_year"] = numeric(audit["death_year"])
    audit["event_primary"] = audit["death_date_year"].between(2012, 2016, inclusive="both")
    audit["event_exact_4y"] = (
        audit["death_date"].notna()
        & audit["baseline_date"].notna()
        & (audit["death_date"] >= audit["baseline_date"])
        & (audit["death_date"] <= audit["baseline_date"] + pd.Timedelta(days=1461))
    )
    
    audit["event_exact_4y"] = audit["event_exact_4y"].fillna(False)
    audit["death_before_baseline"] = audit["death_date"].notna() & audit["baseline_date"].notna() & (audit["death_date"] < audit["baseline_date"])
    summary = {
        "cohort": "KLoSA",
        "raw_baseline_n": int(len(base)),
        "age60_n": int(len(base_60)),
        "exit_source_rows": int(sum(len(x) for x in exit_rows)),
        "exit_duplicate_id_rows_before_dedup": duplicate_id_rows,
        "matched_age60_death_dates": int(audit["death_date"].notna().sum()),
        "prebaseline_deaths_age60": int(audit["death_before_baseline"].sum()),
        "event_primary_n": int(audit["event_primary"].sum()),
        "event_exact_4y_n": int(audit["event_exact_4y"].sum()),
        "window": "death year 2012-2016; exact-date sensitivity <=1461 days",
        "source": "KLoSA w04-w09 EXIT death-date fields",
    }
    return audit, summary


def audit_share() -> tuple[pd.DataFrame, dict]:
    base_path = RAW_ROOT / "share harmonised" / "GH_SHARE_g.dta"
    base = read_dta(base_path, ["mergeid", "r4iwy", "r4iwm", "r4agey"])
    base = base.rename(columns={"mergeid": "person_id_raw", "r4iwy": "baseline_year", "r4iwm": "baseline_month", "r4agey": "baseline_age"})
    base["person_id"] = normalized_id(base["person_id_raw"])
    base["baseline_year"] = numeric(base["baseline_year"])
    base["baseline_age"] = numeric(base["baseline_age"])
    base["baseline_date"] = make_month_date(base["baseline_year"], base["baseline_month"])
    base = base[(base["baseline_year"] == 2011) & (base["baseline_age"] >= 60)].copy()
    eol_path = RAW_ROOT / "share harmonised" / "GH_SHARE_EOL_g.dta"
    eol = read_dta(eol_path, ["mergeid", "raxyear", "raxmonth"])
    eol = eol.rename(columns={"mergeid": "person_id_raw", "raxyear": "death_year", "raxmonth": "death_month"})
    eol["person_id"] = normalized_id(eol["person_id_raw"])
    eol["death_date"] = make_month_date(eol["death_year"], eol["death_month"])
    eol = eol.sort_values(["person_id", "death_date"], na_position="last")
    duplicate_id_rows = int(eol.duplicated("person_id", keep=False).sum())
    eol = eol.drop_duplicates("person_id", keep="first")
    audit = base.merge(eol[["person_id", "death_year", "death_month", "death_date"]], on="person_id", how="left", validate="one_to_one")
    audit["death_date_year"] = numeric(audit["death_year"])
    audit["event_primary"] = audit["death_date_year"].between(2011, 2015, inclusive="both")
    audit["event_exact_4y"] = (
        audit["death_date"].notna() & audit["baseline_date"].notna()
        & (audit["death_date"] >= audit["baseline_date"])
        & (audit["death_date"] <= audit["baseline_date"] + pd.Timedelta(days=1461))
    )
    audit["death_before_baseline"] = audit["death_date"].notna() & (audit["death_date"] < audit["baseline_date"])
    summary = {
        "cohort": "SHARE",
        "raw_baseline_n": int(len(base)),
        "age60_n": int(len(base)),
        "eol_source_rows": int(len(eol)),
        "eol_duplicate_id_rows_before_dedup": duplicate_id_rows,
        "matched_age60_death_dates": int(audit["death_date"].notna().sum()),
        "prebaseline_deaths_age60": int(audit["death_before_baseline"].sum()),
        "event_primary_n": int(audit["event_primary"].sum()),
        "event_exact_4y_n": int(audit["event_exact_4y"].sum()),
        "window": "death year 2011-2015; exact-date sensitivity <=1461 days",
        "source": "GH_SHARE_EOL_g raxyear/raxmonth",
    }
    return audit, summary


def audit_mhas() -> tuple[pd.DataFrame, dict]:
    base_path = RAW_ROOT / "MHAS" / "H_MHAS_c2.dta"
    base = read_dta(base_path, ["rahhidnp", "r3agey", "rabyear", "r3iwy"])
    base = base.rename(columns={"rahhidnp": "person_id_raw", "r3agey": "age_direct", "rabyear": "birth_year", "r3iwy": "baseline_year"})
    base["person_id"] = normalized_id(base["person_id_raw"])
    base["age_direct"] = numeric(base["age_direct"])
    base["birth_year"] = numeric(base["birth_year"])
    base["baseline_year"] = numeric(base["baseline_year"])
    base["baseline_date"] = pd.to_datetime(base["baseline_year"].where(base["baseline_year"].between(1900, 2100)).astype("Int64").astype("string") + "-07-01", errors="coerce")
    valid_direct = base["age_direct"].between(20, 110)
    derived_age = base["baseline_year"] - base["birth_year"]
    valid_derived = derived_age.between(20, 110)
    base["age_mhas"] = base["age_direct"].where(valid_direct, derived_age.where(valid_derived))
    base_60 = base[base["age_mhas"] >= 60].copy()
    eol_path = RAW_ROOT / "MHAS" / "H_MHAS_EOL_b.dta"
    eol = read_dta(eol_path, ["rahhidnp", "raxyear", "raxmonth"])
    eol = eol.rename(columns={"rahhidnp": "person_id_raw", "raxyear": "death_year", "raxmonth": "death_month"})
    eol["person_id"] = normalized_id(eol["person_id_raw"])
    eol["death_date"] = make_month_date(eol["death_year"], eol["death_month"])
    eol = eol.sort_values(["person_id", "death_date"], na_position="last")
    duplicate_id_rows = int(eol.duplicated("person_id", keep=False).sum())
    eol = eol.drop_duplicates("person_id", keep="first")
    audit = base_60.merge(eol[["person_id", "death_year", "death_month", "death_date"]], on="person_id", how="left", validate="one_to_one")
    audit["death_date_year"] = numeric(audit["death_year"])
    audit["event_primary"] = audit["death_date_year"].between(2012, 2016, inclusive="both")
    audit["event_exact_4y"] = (
        audit["death_date"].notna() & audit["baseline_date"].notna()
        & (audit["death_date"] >= audit["baseline_date"])
        & (audit["death_date"] <= audit["baseline_date"] + pd.Timedelta(days=1461))
    )
    audit["death_before_baseline"] = audit["death_date"].notna() & (audit["death_date"] < audit["baseline_date"])
    summary = {
        "cohort": "MHAS",
        "raw_baseline_n": int(len(base)),
        "age_valid_n": int(base["age_mhas"].notna().sum()),
        "age60_n": int(len(base_60)),
        "eol_source_rows": int(len(eol)),
        "eol_duplicate_id_rows_before_dedup": duplicate_id_rows,
        "matched_age60_death_dates": int(audit["death_date"].notna().sum()),
        "prebaseline_deaths_age60": int(audit["death_before_baseline"].sum()),
        "event_primary_n": int(audit["event_primary"].sum()),
        "event_exact_4y_n": int(audit["event_exact_4y"].sum()),
        "window": "death year 2012-2016; exact-date sensitivity <=1461 days",
        "source": "H_MHAS_EOL_b raxyear/raxmonth",
    }
    return audit, summary


def write_outputs(audits: dict[str, pd.DataFrame], summaries: list[dict], log_path: Path) -> None:
    summary_df = pd.DataFrame(summaries)
    summary_path = RESULT_DIR / f"current_four_year_event_summary_{RUN_DATE}.csv"
    summary_df.to_csv(summary_path, index=False)
    for cohort, audit in audits.items():
        audit = audit.copy()
        for col in audit.columns:
            if pd.api.types.is_datetime64_any_dtype(audit[col]):
                audit[col] = audit[col].dt.strftime("%Y-%m-%d")
        audit_path = RESULT_DIR / f"{cohort.lower()}_four_year_event_audit_{RUN_DATE}.csv"
        audit.to_csv(audit_path, index=False)
        logging.info("Wrote %s", audit_path)
    metadata = {
        "run_date": RUN_DATE,
        "project_root": str(PROJECT_ROOT),
        "raw_root": str(RAW_ROOT),
        "python": sys.version,
        "platform": platform.platform(),
        "pandas": pd.__version__,
        "pyreadstat": getattr(pyreadstat, "__version__", "unknown"),
        "raw_data_modified": False,
        "primary_rule": "death year inclusive from baseline year through baseline year + 4",
        "exact_sensitivity_rule": "death date from baseline date through baseline date + 1461 days",
    }
    metadata_path = RESULT_DIR / f"current_four_year_event_metadata_{RUN_DATE}.json"
    metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    report_lines = [
        "# Current four-year mortality event recomputation",
        "",
        "## Material Passport",
        "- Type: source-level mortality event audit for KLoSA, SHARE, and MHAS",
        "- Status: VERIFIED after raw-source rerun; primary event count uses the project year-window rule",
        f"- Script: {Path(__file__).resolve()}",
        f"- Log: {log_path}",
        "- Raw data modified: no",
        "",
        "## Primary results",
        "",
        "| Cohort | Age-60+ denominator | Matched death dates | Pre-baseline deaths | Primary events | Exact-date sensitivity |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for s in summaries:
        denom = s.get("age60_n", "")
        report_lines.append(
            f"| {s['cohort']} | {denom:,} | {s['matched_age60_death_dates']:,} | {s['prebaseline_deaths_age60']:,} | {s['event_primary_n']:,} | {s['event_exact_4y_n']:,} |"
        )
    report_lines += [
        "",
        "Primary windows: KLoSA 2012-2016, SHARE 2011-2015, MHAS 2012-2016. Valid death year is sufficient for the primary event; exact-date sensitivity uses available month/day precision and a 1,461-day upper bound.",
        "The event audit is restricted to the current age-60+ baseline denominators: KLoSA w04 age, SHARE wave-4 visits in 2011 with r4agey >= 60, and MHAS D-022 direct-or-derived age >= 60.",
        "",
        "## Outputs",
        f"- Summary: `{summary_path}`",
        *[f"- {c} audit: `{RESULT_DIR / (c.lower() + '_four_year_event_audit_' + RUN_DATE + '.csv')}`" for c in audits],
        f"- Metadata: `{metadata_path}`",
    ]
    report_path = RESULT_DIR / f"current_four_year_event_recompute_report_{RUN_DATE}.md"
    report_path.write_text("\n".join(report_lines) + "\n", encoding="utf-8")
    logging.info("Wrote %s", summary_path)
    logging.info("Wrote %s", report_path)


def main() -> None:
    log_path = configure_logging()
    logging.info("START current four-year mortality event recomputation")
    audits = {}
    summaries = []
    for name, fn in (("KLoSA", audit_klosa), ("SHARE", audit_share), ("MHAS", audit_mhas)):
        logging.info("Auditing %s", name)
        audit, summary = fn()
        audits[name] = audit
        summaries.append(summary)
        logging.info("%s summary: %s", name, summary)
    write_outputs(audits, summaries, log_path)
    logging.info("DONE")


if __name__ == "__main__":
    main()
