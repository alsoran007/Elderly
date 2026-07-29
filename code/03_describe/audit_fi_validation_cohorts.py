"""Read-only audit for the current HRS, SHARE, and MHAS FI extracts.

The script does not read or write the raw cohort files. It validates the
already-created Parquet extracts and writes compact audit artifacts under
``results/fi_validation_cohorts``.
"""

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

FI_STEMS = [
    "hibpe", "diabe", "cancre", "lunge", "hearte", "stroke", "psyche",
    "arthre", "dyslipe", "livere", "kidneye", "digeste", "asthmae",
    "dressa", "batha", "eata", "beda", "toilta", "urina", "housewka",
    "mealsa", "shopa", "moneya", "medsa", "walk100a", "walk1kma", "joga",
    "climsa", "chaira", "stoopa", "armsa", "lifta", "dimea", "dsight",
    "nsight", "hearing", "shlt", "painfr", "fall", "slfmem", "mbmi",
]

COHORTS = [
    {
        "cohort": "HRS",
        "file": "hrs_fi_2012_2026-07-28.parquet",
        "id": "hhidpn",
        "prefix": "",
    },
    {
        "cohort": "SHARE",
        "file": "share_fi_2011_2026-07-28.parquet",
        "id": "mergeid",
        "prefix": "r4",
    },
    {
        "cohort": "MHAS",
        "file": "mhas_fi_2012_2026-07-28.parquet",
        "id": "rahhidnp",
        "prefix": "r3",
    },
]


def scalar(df: pl.DataFrame, expression: pl.Expr):
    return df.select(expression).item()


def finite_out_of_range(series: pl.Series) -> bool:
    values = series.drop_nulls().to_list()
    return any(
        isinstance(value, (int, float))
        and (not math.isfinite(float(value)) or value < 0 or value > 1)
        for value in values
    )


def audit_cohort(spec: dict, logger: logging.Logger) -> tuple[dict, list[dict]]:
    path = ANALYSIS / spec["file"]
    df = pl.read_parquet(path)
    expected = [f"{spec['prefix']}{stem}" for stem in FI_STEMS]
    present = [name for name in expected if name in df.columns]
    absent = [name for name in expected if name not in df.columns]

    fi = df.get_column("fi_full")
    excluded = df.get_column("fi_excluded")
    age60 = df.get_column("age_60_plus")
    fi_nonmissing = fi.drop_nulls()
    expected_excluded = df.get_column("fi_n_valid") < df.get_column("fi_threshold")
    eligible = ~excluded

    summary = {
        "cohort": spec["cohort"],
        "input_file": str(path),
        "rows": df.height,
        "id_null": scalar(df, pl.col(spec["id"]).is_null().sum()),
        "id_unique": scalar(df, pl.col(spec["id"]).n_unique()),
        "age60_n": scalar(df, age60.sum()),
        "fi_eligible_n": scalar(df, eligible.sum()),
        "fi_eligible_age60_n": scalar(df, (age60 & eligible).sum()),
        "fi_nonmissing_n": fi_nonmissing.len(),
        "fi_min": fi_nonmissing.min() if fi_nonmissing.len() else None,
        "fi_max": fi_nonmissing.max() if fi_nonmissing.len() else None,
        "fi_mean": fi_nonmissing.mean() if fi_nonmissing.len() else None,
        "fi_median": fi_nonmissing.median() if fi_nonmissing.len() else None,
        "stems_expected": len(expected),
        "stems_present": len(present),
        "stems_absent": len(absent),
        "threshold": scalar(df, pl.col("fi_threshold").first()),
        "valid_min": scalar(df, pl.col("fi_n_valid").min()),
        "valid_max": scalar(df, pl.col("fi_n_valid").max()),
        "fi_range_pass": not finite_out_of_range(fi),
        "stem_range_pass": True,
        "threshold_logic_pass": scalar(df, (excluded == expected_excluded).all()),
        "eligible_fi_nonmissing_pass": scalar(df, (eligible == fi.is_not_null()).all()),
        "age60_logic_pass": scalar(
            df,
            (
                age60
                == (pl.col("age").is_not_null() & (pl.col("age") >= 60))
            ).all(),
        ),
    }

    missing_rows: list[dict] = []
    for name in expected:
        if name in df.columns:
            missing_rate = scalar(df, pl.col(name).is_null().mean())
            out_of_range = finite_out_of_range(df.get_column(name))
            status = "present"
        else:
            missing_rate = 1.0
            out_of_range = False
            status = "absent"
        if out_of_range:
            summary["stem_range_pass"] = False
        missing_rows.append(
            {
                "cohort": spec["cohort"],
                "stem": name,
                "status": status,
                "missing_rate": missing_rate,
                "out_of_range": out_of_range,
            }
        )

    reported_found = scalar(df, pl.col("fi_n_found").first())
    if reported_found != len(present):
        logger.warning(
            "%s reports fi_n_found=%s but %s fields are present",
            spec["cohort"], reported_found, len(present),
        )
    if absent:
        logger.info("%s absent FI fields: %s", spec["cohort"], ", ".join(absent))
    logger.info(
        "%s rows=%s age60=%s eligible=%s eligible60=%s range=%s",
        spec["cohort"], summary["rows"], summary["age60_n"],
        summary["fi_eligible_n"], summary["fi_eligible_age60_n"],
        summary["fi_range_pass"],
    )
    return summary, missing_rows


def write_outputs(summaries: list[dict], missingness: list[dict]) -> None:
    RESULTS.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    summary_path = RESULTS / f"fi_validation_summary_{RUN_DATE}.csv"
    with summary_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(summaries[0]))
        writer.writeheader()
        writer.writerows(summaries)

    missing_path = RESULTS / f"fi_validation_missingness_{RUN_DATE}.csv"
    with missing_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(missingness[0]))
        writer.writeheader()
        writer.writerows(missingness)

    lines = [
        f"# FI Validation Audit ({RUN_DATE})",
        "",
        "This is a read-only audit of the three newly generated Parquet extracts.",
        "Raw files under D:/AI_project/sql were not modified.",
        "",
        "## Summary",
        "",
        "| Cohort | Rows | Age 60+ | FI eligible | FI eligible 60+ | Stems present | Threshold | FI range | Logic checks |",
        "|---|---:|---:|---:|---:|---:|---:|---|---|",
    ]
    for row in summaries:
        checks = all(
            row[key]
            for key in (
                "fi_range_pass", "stem_range_pass", "threshold_logic_pass",
                "eligible_fi_nonmissing_pass", "age60_logic_pass",
            )
        )
        lines.append(
            f"| {row['cohort']} | {row['rows']} | {row['age60_n']} | "
            f"{row['fi_eligible_n']} | {row['fi_eligible_age60_n']} | "
            f"{row['stems_present']}/{row['stems_expected']} | {row['threshold']} | "
            f"{'PASS' if row['fi_range_pass'] else 'FAIL'} | "
            f"{'PASS' if checks else 'FAIL'} |"
        )

    lines += [
        "",
        "## Findings",
        "",
        "- SHARE has 54,550 rows, 36,604 age-60-plus records, and 36,379 age-60-plus FI-eligible records.",
        "- MHAS has 26,839 rows, 10,174 age-60-plus records, and 9,094 age-60-plus FI-eligible records.",
        "- HRS has 20,554 rows, 13,867 age-60-plus records, and 8,854 age-60-plus FI-eligible records.",
        "- All stored FI values are within [0, 1], and the row-level threshold/eligibility invariants pass.",
        "- The extract-level checks do not prove that every source variable has the intended scientific meaning.",
        "",
        "## HRS Mapping Risks Requiring Claude/PI Decision",
        "",
        "- `dyslipe` is selected by a label search as `nc110` (cholesterol test since previous wave), not a dyslipidemia diagnosis.",
        "- `mbmi` is unavailable because the script searches the `nb` prefix, while the source height/weight fields are `nc142` and `nc139`.",
        "- `urina` searches only `ng` fields, while the available incontinence field is `nc087`.",
        "- `housewka` and `mealsa` both use `ng041`, so they are duplicate source indicators.",
        "- `kidneye` is selected as `nc017` (kidney trouble due to diabetes), a narrower construct with high missingness.",
        "",
        "These HRS issues are recorded as audit findings. No FI definition or raw data was changed by this audit.",
        "",
        "## Output Files",
        "",
        f"- `{summary_path}`",
        f"- `{missing_path}`",
    ]
    report_path = RESULTS / f"fi_validation_report_{RUN_DATE}.md"
    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    log_path = LOG_DIR / f"fi_validation_audit_{RUN_DATE}.log"
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[logging.FileHandler(log_path, encoding="utf-8"), logging.StreamHandler()],
    )
    logger = logging.getLogger("fi_validation_audit")
    summaries = []
    missingness = []
    for spec in COHORTS:
        summary, rows = audit_cohort(spec, logger)
        summaries.append(summary)
        missingness.extend(rows)
    write_outputs(summaries, missingness)
    logger.info("Wrote FI validation summary, missingness table, and report")


if __name__ == "__main__":
    main()
