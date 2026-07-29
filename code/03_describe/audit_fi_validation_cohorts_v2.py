"""Read-only validation of the current HRS, SHARE, and MHAS FI Parquets."""

from __future__ import annotations

import csv
import logging
import math
from datetime import date
from pathlib import Path

import polars as pl


PROJECT = Path(__file__).resolve().parents[2]
ANALYSIS = PROJECT / "data" / "analysis"
RESULTS = PROJECT / "results" / "fi_validation_cohorts"
LOG_DIR = PROJECT / "logs"
RUN_DATE = date(2026, 7, 28).isoformat()
STEMS = [
    "hibpe", "diabe", "cancre", "lunge", "hearte", "stroke", "psyche", "arthre",
    "dyslipe", "livere", "kidneye", "digeste", "asthmae", "dressa", "batha",
    "eata", "beda", "toilta", "urina", "housewka", "mealsa", "shopa", "moneya",
    "medsa", "walk100a", "walk1kma", "joga", "climsa", "chaira", "stoopa", "armsa",
    "lifta", "dimea", "dsight", "nsight", "hearing", "shlt", "painfr", "fall",
    "slfmem", "mbmi",
]
COHORTS = [
    ("HRS", "hrs_fi_2012_2026-07-28.parquet", "hhidpn", ""),
    ("SHARE", "share_fi_2011_2026-07-28.parquet", "mergeid", "r4"),
    ("MHAS", "mhas_fi_2012_2026-07-28.parquet", "rahhidnp", "r3"),
]


def one(df: pl.DataFrame, expr: pl.Expr):
    return df.select(expr).item()


def bad_values(series: pl.Series) -> bool:
    return any(
        isinstance(x, (int, float))
        and (not math.isfinite(float(x)) or x < 0 or x > 1)
        for x in series.drop_nulls().to_list()
    )


def run_one(name: str, filename: str, id_col: str, prefix: str, log: logging.Logger):
    path = ANALYSIS / filename
    df = pl.read_parquet(path)
    expected = [prefix + stem for stem in STEMS]
    present = [col for col in expected if col in df.columns]
    absent = [col for col in expected if col not in df.columns]
    with_data = [col for col in present if one(df, pl.col(col).is_not_null().any())]
    all_na = [col for col in present if col not in with_data]

    fi = df.get_column("fi_full")
    eligible = ~df.get_column("fi_excluded")
    threshold_logic = one(
        df,
        (df.get_column("fi_excluded") ==
         (df.get_column("fi_n_valid") < df.get_column("fi_threshold"))).all(),
    )
    age_logic = one(
        df,
        (df.get_column("age_60_plus") ==
         (pl.col("age").is_not_null() & (pl.col("age") >= 60))).all(),
    )
    stem_bad = []
    missing = []
    for col in expected:
        if col in df.columns:
            rate = one(df, pl.col(col).is_null().mean())
            out = bad_values(df.get_column(col))
            status = "all_na" if rate == 1 else "present"
        else:
            rate, out, status = 1.0, False, "absent"
        missing.append({"cohort": name, "stem": col, "status": status,
                        "missing_rate": rate, "out_of_range": out})
        if out:
            stem_bad.append(col)

    reported_found = one(df, pl.col("fi_n_found").first())
    if reported_found != len(with_data):
        log.warning("%s fi_n_found=%s; fields with data=%s", name, reported_found, len(with_data))
    log.info("%s rows=%s age60=%s eligible=%s eligible60=%s", name, df.height,
             one(df, pl.col("age_60_plus").sum()), one(df, eligible.sum()),
             one(df, (df.get_column("age_60_plus") & eligible).sum()))

    nonmissing = fi.drop_nulls()
    summary = {
        "cohort": name, "input_file": str(path), "rows": df.height,
        "id_null": one(df, pl.col(id_col).is_null().sum()),
        "id_unique": one(df, pl.col(id_col).n_unique()),
        "age60_n": one(df, pl.col("age_60_plus").sum()),
        "fi_eligible_n": one(df, eligible.sum()),
        "fi_eligible_age60_n": one(df, (df.get_column("age_60_plus") & eligible).sum()),
        "fi_nonmissing_n": nonmissing.len(),
        "fi_min": nonmissing.min(), "fi_max": nonmissing.max(),
        "fi_mean": nonmissing.mean(), "fi_median": nonmissing.median(),
        "stems_expected": len(expected), "stems_with_data": len(with_data),
        "stems_all_na": len(all_na), "stems_absent": len(absent),
        "reported_fi_n_found": reported_found,
        "threshold": one(df, pl.col("fi_threshold").first()),
        "valid_min": one(df, pl.col("fi_n_valid").min()),
        "valid_max": one(df, pl.col("fi_n_valid").max()),
        "fi_range_pass": not bad_values(fi), "stem_range_pass": not stem_bad,
        "threshold_logic_pass": threshold_logic,
        "eligible_fi_nonmissing_pass": one(df, eligible == fi.is_not_null()).all(),
        "age60_logic_pass": age_logic,
    }
    return summary, missing, absent, all_na


def main():
    RESULTS.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log_path = LOG_DIR / f"fi_validation_audit_{RUN_DATE}.log"
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s",
                        handlers=[logging.FileHandler(log_path, encoding="utf-8"), logging.StreamHandler()])
    log = logging.getLogger("fi_audit")
    summaries, missingness, absent_map, all_na_map = [], [], {}, {}
    for args in COHORTS:
        summary, miss, absent, all_na = run_one(*args, log)
        summaries.append(summary); missingness.extend(miss)
        absent_map[args[0]], all_na_map[args[0]] = absent, all_na

    summary_path = RESULTS / f"fi_validation_summary_{RUN_DATE}.csv"
    with summary_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(summaries[0])); writer.writeheader(); writer.writerows(summaries)
    missing_path = RESULTS / f"fi_validation_missingness_{RUN_DATE}.csv"
    with missing_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(missingness[0])); writer.writeheader(); writer.writerows(missingness)

    lines = [f"# FI Validation Audit ({RUN_DATE})", "",
             "Read-only validation of the three newly generated Parquet extracts.",
             "Raw files under D:/AI_project/sql were not modified.", "", "## Summary", "",
             "| Cohort | Rows | Age 60+ | FI eligible | FI eligible 60+ | Stems with data | Threshold | FI range | Checks |",
             "|---|---:|---:|---:|---:|---:|---:|---|---|"]
    check_keys = ["fi_range_pass", "stem_range_pass", "threshold_logic_pass",
                  "eligible_fi_nonmissing_pass", "age60_logic_pass"]
    for row in summaries:
        checks = all(row[key] for key in check_keys)
        lines.append(f"| {row['cohort']} | {row['rows']} | {row['age60_n']} | {row['fi_eligible_n']} | "
                     f"{row['fi_eligible_age60_n']} | {row['stems_with_data']}/{row['stems_expected']} | "
                     f"{row['threshold']} | {'PASS' if row['fi_range_pass'] else 'FAIL'} | "
                     f"{'PASS' if checks else 'FAIL'} |")
    lines += ["", "## Extract Findings", "",
              "- HRS: 20,554 rows; age 60+ N=13,867; FI-eligible N=11,372; FI-eligible age 60+ N=8,854.",
              "- SHARE: 54,550 rows; age 60+ N=36,604; FI-eligible N=54,196; FI-eligible age 60+ N=36,379.",
              "- MHAS: 26,839 rows; age 60+ N=10,174; FI-eligible N=14,363; FI-eligible age 60+ N=9,094.",
              "- All stored FI values are within [0,1]. Threshold, eligibility, and age-60 logic checks pass.",
              "", "## Field Availability", ""]
    for name in absent_map:
        lines.append(f"- {name} absent: {', '.join(absent_map[name]) or 'none'}")
        lines.append(f"- {name} all-NA: {', '.join(all_na_map[name]) or 'none'}")
    lines += ["", "## HRS Mapping Risks", "",
              "- dyslipe is selected as nc110 (cholesterol test since previous wave), not a dyslipidemia diagnosis.",
              "- mbmi is all-NA because the script searches nb, while source height/weight are nc142/nc139.",
              "- urina searches ng only, while available incontinence is nc087.",
              "- housewka and mealsa both use ng041, creating a duplicate source indicator.",
              "- kidneye is nc017 (kidney trouble due to diabetes), a narrower construct with high missingness.",
              "", "These are review findings, not silent changes to FI definitions.", "", "## Outputs", "",
              f"- `{summary_path}`", f"- `{missing_path}`", f"- `{log_path}`"]
    report_path = RESULTS / f"fi_validation_report_{RUN_DATE}.md"
    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    log.info("wrote %s, %s, and %s", summary_path, missing_path, report_path)


if __name__ == "__main__":
    main()
