"""Build the CHARLS discrete-time person-period mortality table.

This module is intentionally separate from charls_outcome.py.  It uses wave
status rather than exact death dates and preserves intermittent reappearance
as an observed risk interval.
"""

from __future__ import annotations

import json
import logging
import subprocess
import tempfile
from pathlib import Path
from typing import Dict, Iterable, List, Tuple

import numpy as np
import pandas as pd
import pyreadstat


SEED = 20260726
PROJECT_ROOT = Path(__file__).resolve().parents[2]
RAW_ROOT = PROJECT_ROOT.parent / "sql" / "Charls"
DATA_ROOT = PROJECT_ROOT / "data" / "analysis"
RESULT_ROOT = PROJECT_ROOT / "results" / "outcome_charls" / "person_period"
LOG_ROOT = PROJECT_ROOT / "logs"
LOG_PATH = LOG_ROOT / "build_charls_outcome_2026-07-27.log"
PERSON_PERIOD_PATH = DATA_ROOT / "charls_person_period_2026-07-27.parquet"
BASELINE_PATH = DATA_ROOT / "charls_baseline_cohort_2026-07-27.parquet"
RISK_TABLE_PATH = RESULT_ROOT / "risk_set_decay_60plus_2026-07-27.csv"
STATUS_TABLE_PATH = RESULT_ROOT / "person_period_status_summary_2026-07-27.csv"

WAVES = (2013, 2015, 2018, 2020)
EXPECTED_OVERLAPS = {2015: 15139, 2018: 14395, 2020: 13734}
EXPECTED_EVENTS = {1: 408, 2: 563, 3: 829, 4: 640}
EXPECTED_EVENTS_60 = {1: 342, 2: 443, 3: 651, 4: 502}


def setup_logging() -> logging.Logger:
    LOG_ROOT.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger("charls_person_period")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()
    handler = logging.FileHandler(LOG_PATH, mode="w", encoding="utf-8")
    handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    logger.addHandler(handler)
    logger.addHandler(logging.StreamHandler())
    return logger


def read_dta(relative: str, columns: Iterable[str]) -> pd.DataFrame:
    path = RAW_ROOT / relative
    if not path.exists():
        raise FileNotFoundError(path)
    frame, _ = pyreadstat.read_dta(str(path), usecols=list(columns))
    return frame


def clean_id(values: pd.Series) -> pd.Series:
    if pd.api.types.is_numeric_dtype(values):
        values = values.map(lambda value: "" if pd.isna(value) else str(int(value)))
    result = values.astype("string").str.strip()
    return result.mask(result.isin(["", "<NA>", "nan", "None"]))


def numeric(values: pd.Series) -> pd.Series:
    return pd.to_numeric(values, errors="coerce")


def assert_unique(values: pd.Series, label: str) -> None:
    valid = values.dropna()
    if valid.duplicated().any():
        raise AssertionError(f"duplicate IDs in {label}")


def write_parquet(frame: pd.DataFrame, output: Path, logger: logging.Logger) -> None:
    """Write Parquet with a deterministic R-arrow fallback when needed."""
    output.parent.mkdir(parents=True, exist_ok=True)
    try:
        frame.to_parquet(output, index=False)
        logger.info("parquet_writer=pandas")
        return
    except (ImportError, ValueError, OSError) as exc:
        logger.info("pandas_parquet_unavailable=%s", exc)

    rscript = Path(r"D:\LeStoreDownload\R\R-4.4.1\bin\x64\Rscript.exe")
    if not rscript.exists():
        raise RuntimeError("Neither a Python parquet engine nor configured Rscript is available")
    with tempfile.TemporaryDirectory(prefix="charls_person_period_") as temp_dir:
        csv_path = Path(temp_dir) / "table.csv"
        frame.to_csv(csv_path, index=False, na_rep="")
        r_code = (
            "args <- commandArgs(TRUE); "
            "d <- read.csv(args[1], stringsAsFactors=FALSE, na.strings=c('', 'NA'), "
            "colClasses='character', check.names=FALSE); "
            "for (x in c('period','period_start','period_end','event','age','sex','female')) "
            "if (x %in% names(d)) d[[x]] <- as.numeric(d[[x]]); "
            "for (x in c('age_60_plus','intermittent_missing','exit_2013_matched')) "
            "if (x %in% names(d)) { v <- tolower(trimws(as.character(d[[x]]))); "
            "d[[x]] <- ifelse(v %in% c('true','1'), TRUE, ifelse(v %in% c('false','0'), FALSE, NA)) }; "
            "arrow::write_parquet(d, args[2])"
        )
        subprocess.run(
            [str(rscript), "--vanilla", "-e", r_code, str(csv_path), str(output)],
            check=True,
        )
    logger.info("parquet_writer=R_arrow")


def later_presence(pid: str, period_index: int, presence: Dict[int, set]) -> bool:
    return any(pid in presence[wave] for wave in WAVES[period_index + 1 :])


def classify_interval(
    pid: str,
    period_index: int,
    exit13_ids: set,
    presence: Dict[int, set],
    died: Dict[int, pd.Series],
) -> Tuple[str, int]:
    """Return status and event for one interval endpoint."""
    endpoint = WAVES[period_index]
    if endpoint == 2013:
        event = int(pid in exit13_ids)
        if event:
            return "dead", 1
        present = pid in presence[2013]
    else:
        present = pid in presence[endpoint]
        event = int(present and died[endpoint].get(pid, np.nan) == 1)
        if event:
            return "dead", 1
    if present:
        return "alive", 0
    if later_presence(pid, period_index, presence):
        return "intermittent_missing", 0
    return "lost_to_followup", 0


def build_tables(logger: logging.Logger) -> Tuple[pd.DataFrame, pd.DataFrame, Dict[str, object]]:
    baseline_raw = read_dta(
        "2011/demographic_background.dta",
        ["ID", "householdID", "ba002_1", "rgender"],
    )
    baseline = pd.DataFrame(
        {
            "id_w1_11": clean_id(baseline_raw["ID"]),
            "household_id": clean_id(baseline_raw["householdID"]),
            "birth_year": numeric(baseline_raw["ba002_1"]),
            "sex": numeric(baseline_raw["rgender"]).astype("Int64"),
        }
    )
    baseline["pid"] = baseline["household_id"] + "0" + baseline["id_w1_11"].str[-2:]
    baseline["age"] = 2011 - baseline["birth_year"]
    baseline.loc[~baseline["birth_year"].between(1890, 2000), "age"] = np.nan
    baseline["age"] = baseline["age"].astype("Int64")
    baseline["female"] = baseline["sex"].map({1: 0, 2: 1}).astype("Int64")
    baseline["age_60_plus"] = baseline["age"].ge(60)
    assert_unique(baseline["id_w1_11"], "2011 raw IDs")
    assert_unique(baseline["pid"], "2011 reconstructed IDs")
    if len(baseline) != 17705:
        raise AssertionError(f"baseline N={len(baseline)} != 17705")

    exit13 = read_dta("2013/Exit_Interview.dta", ["ID"])
    exit13_ids = set(clean_id(exit13["ID"]).dropna())
    db13 = read_dta("2013/Demographic_Background.dta", ["ID"])
    presence: Dict[int, set] = {2013: set(clean_id(db13["ID"]).dropna())}
    died: Dict[int, pd.Series] = {}
    for wave in (2015, 2018, 2020):
        sample = read_dta(f"{wave}/Sample_Infor.dta", ["ID", "died"])
        sample_ids = clean_id(sample["ID"])
        assert_unique(sample_ids, f"{wave} Sample_Infor IDs")
        presence[wave] = set(sample_ids.dropna())
        died[wave] = pd.Series(numeric(sample["died"]).to_numpy(), index=sample_ids)
        overlap = int(baseline["pid"].isin(presence[wave]).sum())
        if overlap != EXPECTED_OVERLAPS[wave]:
            raise AssertionError(f"{wave} overlap={overlap} != {EXPECTED_OVERLAPS[wave]}")
        baseline[f"present_{wave}"] = baseline["pid"].isin(presence[wave])
        baseline[f"died_{wave}"] = baseline["pid"].map(died[wave]).astype("Float64")
        logger.info("wave=%s overlap=%s", wave, overlap)

    baseline["present_2013"] = baseline["pid"].isin(presence[2013])
    baseline["exit_2013_matched"] = baseline["pid"].isin(exit13_ids)

    rows: List[Dict[str, object]] = []
    for record in baseline.itertuples(index=False):
        pid = record.pid
        for period_index, endpoint in enumerate(WAVES):
            status, event = classify_interval(pid, period_index, exit13_ids, presence, died)
            row = {
                "pid": pid,
                "period": period_index + 1,
                "period_start": 2011 if period_index == 0 else WAVES[period_index - 1],
                "period_end": endpoint,
                "event": event,
                "age": record.age,
                "sex": record.sex,
                "female": record.female,
                "age_60_plus": bool(record.age_60_plus) if pd.notna(record.age_60_plus) else pd.NA,
                "status_at_end": status,
                "intermittent_missing": status == "intermittent_missing",
                "censor_reason": "death" if status == "dead" else (status if status != "alive" else "none"),
            }
            rows.append(row)
            if status in {"dead", "lost_to_followup"}:
                break

    person_period = pd.DataFrame(rows)
    person_period["period"] = person_period["period"].astype("Int64")
    person_period["event"] = person_period["event"].astype("Int64")
    person_period["age"] = person_period["age"].astype("Int64")
    person_period["sex"] = person_period["sex"].astype("Int64")
    person_period["female"] = person_period["female"].astype("Int64")
    person_period["age_60_plus"] = person_period["age_60_plus"].astype("boolean")
    person_period["intermittent_missing"] = person_period["intermittent_missing"].astype("boolean")

    first_event = (
        person_period.loc[person_period["event"] == 1]
        .groupby("pid", as_index=False)["period"]
        .min()
        .rename(columns={"period": "first_event_period"})
    )
    baseline = baseline.merge(first_event, on="pid", how="left")
    baseline["first_event_period"] = baseline["first_event_period"].astype("Int64")
    baseline["status_2013"] = [classify_interval(pid, 0, exit13_ids, presence, died)[0] for pid in baseline["pid"]]
    baseline["status_2015"] = [classify_interval(pid, 1, exit13_ids, presence, died)[0] for pid in baseline["pid"]]
    baseline["status_2018"] = [classify_interval(pid, 2, exit13_ids, presence, died)[0] for pid in baseline["pid"]]
    baseline["status_2020"] = [classify_interval(pid, 3, exit13_ids, presence, died)[0] for pid in baseline["pid"]]
    baseline["intermittent_followup"] = baseline[["status_2013", "status_2015", "status_2018", "status_2020"]].eq("intermittent_missing").any(axis=1)

    baseline_cols = [
        "pid", "id_w1_11", "household_id", "age", "sex", "female", "age_60_plus",
        "present_2013", "present_2015", "present_2018", "present_2020",
        "died_2015", "died_2018", "died_2020", "exit_2013_matched",
        "status_2013", "status_2015", "status_2018", "status_2020",
        "intermittent_followup", "first_event_period",
    ]
    baseline_out = baseline[baseline_cols].copy()
    for column in ["present_2013", "present_2015", "present_2018", "present_2020", "exit_2013_matched", "intermittent_followup"]:
        baseline_out[column] = baseline_out[column].astype("boolean")

    diagnostics: Dict[str, object] = {
        "baseline_n": len(baseline_out),
        "age_60_n": int(baseline_out["age_60_plus"].sum()),
        "exit_2013_rows": len(exit13_ids),
        "exit_2013_overlap": int(baseline_out["exit_2013_matched"].sum()),
        "overlaps": {str(wave): int(baseline_out[f"present_{wave}"].sum()) for wave in (2015, 2018, 2020)},
        "person_period_rows": len(person_period),
        "person_period_events": int(person_period["event"].sum()),
        "intermittent_persons": int(baseline_out["intermittent_followup"].sum()),
        "intermittent_persons_60_plus": int(baseline_out.loc[baseline_out["age_60_plus"], "intermittent_followup"].sum()),
    }
    return baseline_out, person_period, diagnostics


def unmatched_exit_summary(baseline: pd.DataFrame) -> Dict[str, object]:
    exit13 = read_dta("2013/Exit_Interview.dta", ["ID"])
    exit_ids = clean_id(exit13["ID"]).dropna()
    baseline_pids = set(baseline["pid"])
    unmatched = [pid for pid in exit_ids if pid not in baseline_pids]
    # The official bridge uses the 10-character household key: 2011 householdID + "0".
    baseline_households = set((baseline["household_id"].dropna() + "0").tolist())
    existing_household = [pid for pid in unmatched if pid[:10] in baseline_households]
    household_counts = pd.Series([pid[:10] for pid in existing_household]).value_counts()
    return {
        "unmatched_exit_records": len(unmatched),
        "unmatched_in_existing_baseline_household": len(existing_household),
        "unmatched_from_new_household": len(unmatched) - len(existing_household),
        "existing_household_duplicate_records": int((household_counts > 1).sum()),
    }


def make_summaries(baseline: pd.DataFrame, person_period: pd.DataFrame) -> Tuple[pd.DataFrame, pd.DataFrame]:
    all_rows = []
    risk_rows = []
    for period in range(1, 5):
        subset = person_period[person_period["period"] == period]
        all_rows.append(
            {
                "period": period,
                "period_start": int(subset["period_start"].iloc[0]),
                "period_end": int(subset["period_end"].iloc[0]),
                "rows": len(subset),
                "events": int(subset["event"].sum()),
                "intermittent_missing_rows": int((subset["status_at_end"] == "intermittent_missing").sum()),
                "final_lost_rows": int((subset["status_at_end"] == "lost_to_followup").sum()),
            }
        )
        old = subset[subset["age_60_plus"] == True]
        risk_rows.append(
            {
                "period": period,
                "period_start": int(subset["period_start"].iloc[0]),
                "period_end": int(subset["period_end"].iloc[0]),
                "risk_set_start": len(old),
                "deaths": int(old["event"].sum()),
                "intermittent_missing": int((old["status_at_end"] == "intermittent_missing").sum()),
                "final_lost": int((old["status_at_end"] == "lost_to_followup").sum()),
                "alive_at_end": int((old["status_at_end"] == "alive").sum()),
            }
        )
    return pd.DataFrame(all_rows), pd.DataFrame(risk_rows)


def write_report(
    baseline: pd.DataFrame,
    person_period: pd.DataFrame,
    diagnostics: Dict[str, object],
    all_summary: pd.DataFrame,
    risk_summary: pd.DataFrame,
    unmatched: Dict[str, object],
    assertions: Dict[str, str],
) -> Path:
    report = RESULT_ROOT / "person_period_report_2026-07-27.md"
    missing_2015 = ~baseline["present_2015"]
    later_appearance = baseline["present_2018"] | baseline["present_2020"]
    missing_2015_later = int((missing_2015 & later_appearance).sum())
    missing_2015_never = int((missing_2015 & ~later_appearance).sum())
    lines = [
        "# CHARLS Person-Period Construction Report (2026-07-27)",
        "",
        "## Construction boundary",
        "This is a new discrete-time wave framework. It does not modify or rerun `charls_outcome.py`, and it does not use exact death dates. Baseline covariates are repeated across intervals.",
        "",
        "## Assertions",
    ]
    lines.extend(f"- {key}: {value}" for key, value in assertions.items())
    lines.extend(
        [
            "",
            "## Sample and events",
            f"Baseline N={diagnostics['baseline_n']}; age 60+ N={diagnostics['age_60_n']}; person-period rows={diagnostics['person_period_rows']}; person-period events={diagnostics['person_period_events']}; 60+ events={int(person_period.loc[person_period['age_60_plus'] == True, 'event'].sum())}.",
            f"Period events (all/60+): " + "; ".join(
                f"{row.period}={int(row.events)}/{int(risk_summary.loc[risk_summary.period == row.period, 'deaths'].iloc[0])}"
                for row in all_summary.itertuples()
            ),
            "",
            "## Risk-set decay (60+)",
            "| period | interval | risk set start | deaths | intermittent missing | final lost | alive at end |",
            "|---:|---|---:|---:|---:|---:|---:|",
        ]
    )
    for row in risk_summary.itertuples():
        lines.append(f"| {row.period} | {row.period_start}-{row.period_end} | {row.risk_set_start} | {row.deaths} | {row.intermittent_missing} | {row.final_lost} | {row.alive_at_end} |")
    lines.extend(
        [
            "",
            "## Intermittent follow-up",
            f"Intermittent-missing persons={diagnostics['intermittent_persons']} (60+={diagnostics['intermittent_persons_60_plus']}). Among the 2015-missing baseline persons, {missing_2015_later} reappeared in 2018/2020 and {missing_2015_never} never reappeared. Reappearing persons retain the missing interval row and continue into later observed intervals.",
            "",
            "## Unmatched 2013 Exit records",
            f"Unmatched records={unmatched['unmatched_exit_records']}; using the official 10-character household key (2011 householdID + `0`), {unmatched['unmatched_in_existing_baseline_household']} belong to an existing baseline household and {unmatched['unmatched_from_new_household']} are from households absent at baseline; duplicated existing-household groups={unmatched['existing_household_duplicate_records']}. Unmatched records are not assigned baseline mortality events.",
            "",
            "## Outputs",
            f"- `{PERSON_PERIOD_PATH}`",
            f"- `{BASELINE_PATH}`",
            f"- `{RISK_TABLE_PATH}`",
            f"- `{STATUS_TABLE_PATH}`",
            f"- `{report}`",
            f"- `{LOG_PATH}`",
        ]
    )
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return report


def main() -> None:
    logger = setup_logging()
    np.random.seed(SEED)
    DATA_ROOT.mkdir(parents=True, exist_ok=True)
    RESULT_ROOT.mkdir(parents=True, exist_ok=True)
    logger.info("START seed=%s", SEED)

    baseline, person_period, diagnostics = build_tables(logger)
    all_summary, risk_summary = make_summaries(baseline, person_period)
    unmatched = unmatched_exit_summary(baseline)

    assertions = {
        "baseline_N_17705": "PASS" if diagnostics["baseline_n"] == 17705 else "FAIL",
        "age_60_N_7669": "PASS" if diagnostics["age_60_n"] == 7669 else "FAIL",
        "ID_overlaps_15139_14395_13734": "PASS" if diagnostics["overlaps"] == {"2015": 15139, "2018": 14395, "2020": 13734} else "FAIL",
        "exit_2013_overlap_408": "PASS" if diagnostics["exit_2013_overlap"] == 408 else "FAIL",
        "period_events_all_408_563_829_640": "PASS" if all_summary["events"].tolist() == [408, 563, 829, 640] else "FAIL",
        "period_events_60plus_342_443_651_502": "PASS" if risk_summary["deaths"].tolist() == [342, 443, 651, 502] else "FAIL",
        "person_period_rows_64792": "PASS" if diagnostics["person_period_rows"] == 64792 else "FAIL",
        "person_period_events_2440": "PASS" if diagnostics["person_period_events"] == 2440 else "FAIL",
        "no_rows_after_death_or_final_loss": "PASS" if not (((person_period.groupby("pid")["event"].cumsum() - person_period["event"]) > 0)).any() else "FAIL",
    }
    if "FAIL" in assertions.values():
        raise AssertionError(assertions)

    write_parquet(person_period, PERSON_PERIOD_PATH, logger)
    write_parquet(baseline, BASELINE_PATH, logger)
    all_summary.to_csv(STATUS_TABLE_PATH, index=False)
    risk_summary.to_csv(RISK_TABLE_PATH, index=False)
    report = write_report(baseline, person_period, diagnostics, all_summary, risk_summary, unmatched, assertions)
    logger.info("DONE rows=%s events=%s report=%s", len(person_period), int(person_period["event"].sum()), report)
    print(json.dumps({"rows": len(person_period), "events": int(person_period["event"].sum()), "outputs": [str(PERSON_PERIOD_PATH), str(BASELINE_PATH), str(report)]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
