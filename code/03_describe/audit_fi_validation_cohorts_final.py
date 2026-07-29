"""Corrected runner for the read-only FI validation audit."""

from pathlib import Path
import sys

import polars as pl

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audit_fi_validation_cohorts_v2 as base


def run_one(name, filename, id_col, prefix, log):
    path = base.ANALYSIS / filename
    df = pl.read_parquet(path)
    expected = [prefix + stem for stem in base.STEMS]
    present = [col for col in expected if col in df.columns]
    absent = [col for col in expected if col not in df.columns]
    with_data = [col for col in present if base.one(df, pl.col(col).is_not_null().any())]
    all_na = [col for col in present if col not in with_data]
    fi = df.get_column("fi_full")
    age60 = df.get_column("age_60_plus")
    eligible = ~df.get_column("fi_excluded")
    threshold_logic = base.one(
        df, (df.get_column("fi_excluded") ==
             (df.get_column("fi_n_valid") < df.get_column("fi_threshold"))).all())
    age_logic = base.one(
        df, (age60 == (pl.col("age").is_not_null() & (pl.col("age") >= 60))).all())
    missing = []
    stem_bad = []
    for col in expected:
        if col in df.columns:
            rate = base.one(df, pl.col(col).is_null().mean())
            out = base.bad_values(df.get_column(col))
            status = "all_na" if rate == 1 else "present"
        else:
            rate, out, status = 1.0, False, "absent"
        if out:
            stem_bad.append(col)
        missing.append({"cohort": name, "stem": col, "status": status,
                        "missing_rate": rate, "out_of_range": out})
    found = base.one(df, pl.col("fi_n_found").first())
    if found != len(with_data):
        log.warning("%s fi_n_found=%s; fields with data=%s", name, found, len(with_data))
    nonmissing = fi.drop_nulls()
    summary = {
        "cohort": name, "input_file": str(path), "rows": df.height,
        "id_null": base.one(df, pl.col(id_col).is_null().sum()),
        "id_unique": base.one(df, pl.col(id_col).n_unique()),
        "age60_n": base.one(df, age60.sum()),
        "fi_eligible_n": base.one(df, eligible.sum()),
        "fi_eligible_age60_n": base.one(df, (age60 & eligible).sum()),
        "fi_nonmissing_n": nonmissing.len(), "fi_min": nonmissing.min(),
        "fi_max": nonmissing.max(), "fi_mean": nonmissing.mean(),
        "fi_median": nonmissing.median(), "stems_expected": len(expected),
        "stems_with_data": len(with_data), "stems_all_na": len(all_na),
        "stems_absent": len(absent), "reported_fi_n_found": found,
        "threshold": base.one(df, pl.col("fi_threshold").first()),
        "valid_min": base.one(df, pl.col("fi_n_valid").min()),
        "valid_max": base.one(df, pl.col("fi_n_valid").max()),
        "fi_range_pass": not base.bad_values(fi), "stem_range_pass": not stem_bad,
        "threshold_logic_pass": threshold_logic,
        "eligible_fi_nonmissing_pass": base.one(df, (eligible == fi.is_not_null()).all()),
        "age60_logic_pass": age_logic,
    }
    log.info("%s rows=%s age60=%s eligible=%s eligible60=%s", name, df.height,
             summary["age60_n"], summary["fi_eligible_n"], summary["fi_eligible_age60_n"])
    return summary, missing, absent, all_na


base.run_one = run_one


if __name__ == "__main__":
    base.main()
