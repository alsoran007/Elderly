"""Parse HRS Exit files and validate the 2012-2016 mortality window.

The 2012/2014/2016 files are fixed-width .da files with .dct dictionaries;
2018/2020 are read from the available Stata files.  No raw HRS file is
modified, and no person-period or model is constructed here.
"""

from __future__ import annotations

import json
import logging
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Dict, Iterable, List, Tuple

import numpy as np
import pandas as pd
import pyreadstat


SEED = 20260726
PROJECT_ROOT = Path(__file__).resolve().parents[2]
HRS_ROOT = PROJECT_ROOT.parent / "sql" / "HRS Products"
EXIT_ROOT = HRS_ROOT / "HRS Exit"
DATA_ROOT = PROJECT_ROOT / "data" / "interim"
RESULT_ROOT = PROJECT_ROOT / "results" / "outcome_hrs"
LOG_ROOT = PROJECT_ROOT / "logs"
OUTPUT_PATH = DATA_ROOT / "hrs_exit_deaths_2026-07-27.parquet"
REPORT_PATH = RESULT_ROOT / "hrs_event_count_report_2026-07-27.md"
LOG_PATH = LOG_ROOT / "hrs_exit_parse_2026-07-27.log"

WAVE_CONFIG = {
    2012: {"data": "2012/x12da/X12A_R.da", "dct": "2012/x12sta/X12A_R.dct"},
    2014: {"data": "2014/x14da/X14A_R.da", "dct": "2014/x14sta/X14A_R.dct"},
    2016: {"data": "2016/x16da/X16A_R.da", "dct": "2016/x16sta/X16A_R.dct"},
    2018: {"data": "2018/x18sta/X18A_R.dta", "dct": "2018/x18sta/X18A_R.dct"},
    2020: {"data": "2020/x20sta/X20A_R.dta", "dct": "2020/x20sta/X20A_R.dct"},
}

SPECIAL_YEAR_CODES = {9998, 9999}
SPECIAL_MONTH_CODES = {98, 99}


def setup_logging() -> logging.Logger:
    LOG_ROOT.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger("hrs_exit_parse")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()
    handler = logging.FileHandler(LOG_PATH, mode="w", encoding="utf-8")
    handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    logger.addHandler(handler)
    logger.addHandler(logging.StreamHandler())
    return logger


def normalize_id(values: pd.Series) -> pd.Series:
    if pd.api.types.is_numeric_dtype(values):
        values = values.map(lambda value: "" if pd.isna(value) else str(int(value)))
    result = values.astype("string").str.strip()
    return result.mask(result.isin(["", "<NA>", "nan", "None"]))


def normalize_hhidpn(values: pd.Series) -> pd.Series:
    result = normalize_id(values)
    numeric_values = pd.to_numeric(result, errors="coerce")
    result = result.where(numeric_values.isna(), numeric_values.map(lambda value: f"{int(value):09d}" if pd.notna(value) else pd.NA))
    return result.str.zfill(9)


def parse_dct(dct_path: Path) -> List[Tuple[int, str, str]]:
    fields = []
    pattern = re.compile(r'_column\((\d+)\)\s+\S+\s+(\S+)\s+%[^\s]+\s+"([^"]*)"')
    for line in dct_path.read_text(encoding="latin-1").splitlines():
        match = pattern.search(line)
        if match:
            fields.append((int(match.group(1)), match.group(2), match.group(3)))
    if not fields:
        raise ValueError(f"No Stata dictionary fields parsed from {dct_path}")
    return sorted(fields)


def target_variables(fields: List[Tuple[int, str, str]]) -> Dict[str, str]:
    month_candidates = [name for _, name, label in fields if "DATE OF DEATH- MONTH" in label.upper()]
    year_candidates = [name for _, name, label in fields if "DATE OF DEATH- YEAR" in label.upper()]
    if len(month_candidates) != 1 or len(year_candidates) != 1:
        raise ValueError(f"Could not uniquely locate death date variables: {month_candidates}, {year_candidates}")
    names = {name for _, name, _ in fields}
    if not {"HHID", "PN"}.issubset(names):
        raise ValueError("DCT is missing HHID or PN")
    return {"hhid": "HHID", "pn": "PN", "month": month_candidates[0], "year": year_candidates[0]}


def read_fixed_width(data_path: Path, fields: List[Tuple[int, str, str]], variables: Dict[str, str]) -> pd.DataFrame:
    ordered = fields
    specs: List[Tuple[str, int, int]] = []
    wanted = set(variables.values())
    for index, (start, name, _) in enumerate(ordered):
        if name not in wanted:
            continue
        end = ordered[index + 1][0] if index + 1 < len(ordered) else start + 10
        specs.append((name, start - 1, end - 1))
    # Direct slicing avoids pandas read_fwf inferring a wider field when a
    # preceding field is blank.  Positions are still derived from the DCT.
    rows = []
    for line in data_path.read_text(encoding="latin-1", errors="replace").splitlines():
        rows.append({name: line[start:end] for name, start, end in specs})
    return pd.DataFrame(rows, columns=[name for name, _, _ in specs])


def read_exit_wave(wave: int) -> Tuple[pd.DataFrame, Dict[str, object]]:
    config = WAVE_CONFIG[wave]
    data_path = EXIT_ROOT / config["data"]
    dct_path = EXIT_ROOT / config["dct"]
    fields = parse_dct(dct_path)
    variables = target_variables(fields)
    if data_path.suffix.lower() == ".da":
        frame = read_fixed_width(data_path, fields, variables)
    else:
        frame, _ = pyreadstat.read_dta(str(data_path), usecols=list(variables.values()))
    frame = frame.rename(columns={value: key for key, value in variables.items()})
    frame["hhid"] = normalize_id(frame["hhid"])
    frame["pn"] = normalize_id(frame["pn"])
    frame["hhidpn"] = frame["hhid"] + frame["pn"]
    frame["death_year_raw"] = pd.to_numeric(frame["year"], errors="coerce").astype("Int64")
    frame["death_month_raw"] = pd.to_numeric(frame["month"], errors="coerce").astype("Int64")
    frame["death_year"] = frame["death_year_raw"].mask(frame["death_year_raw"].isin(SPECIAL_YEAR_CODES)).astype("Int64")
    frame["death_month"] = frame["death_month_raw"].mask(frame["death_month_raw"].isin(SPECIAL_MONTH_CODES)).astype("Int64")
    frame["date_valid"] = frame["death_year"].between(1900, 2100) & frame["death_month"].between(1, 12)
    frame["exit_wave"] = wave
    frame = frame[["hhid", "pn", "hhidpn", "exit_wave", "death_year_raw", "death_month_raw", "death_year", "death_month", "date_valid"]]
    if frame["hhidpn"].duplicated().any():
        raise AssertionError(f"duplicate hhidpn within HRS Exit {wave}")
    diagnostics = {
        "rows": len(frame),
        "year_nonmissing": int(frame["death_year_raw"].notna().sum()),
        "month_nonmissing": int(frame["death_month_raw"].notna().sum()),
        "year_raw_distribution": {str(key): int(value) for key, value in frame["death_year_raw"].value_counts(dropna=False).items()},
        "month_raw_distribution": {str(key): int(value) for key, value in frame["death_month_raw"].value_counts(dropna=False).items()},
        "variables": variables,
    }
    return frame, diagnostics


def read_baseline() -> pd.DataFrame:
    fat_files = list(HRS_ROOT.rglob("h12f3a.dta"))
    if len(fat_files) != 1:
        raise AssertionError(f"Expected one h12f3a.dta, found {len(fat_files)}")
    frame, _ = pyreadstat.read_dta(str(fat_files[0]), usecols=["hhid", "pn", "na019", "na500", "na501"])
    frame["hhid"] = normalize_id(frame["hhid"])
    frame["pn"] = normalize_id(frame["pn"])
    frame["hhidpn"] = normalize_hhidpn(frame["hhid"] + frame["pn"])
    frame["age_2012"] = pd.to_numeric(frame["na019"], errors="coerce")
    frame["interview_month_2012"] = pd.to_numeric(frame["na500"], errors="coerce").astype("Int64")
    frame["interview_year_2012"] = pd.to_numeric(frame["na501"], errors="coerce").astype("Int64")
    frame["age_60_plus"] = frame["age_2012"] >= 60
    frame = frame[["hhid", "pn", "hhidpn", "age_2012", "age_60_plus", "interview_year_2012", "interview_month_2012"]]
    if frame["hhidpn"].duplicated().any():
        raise AssertionError("duplicate hhidpn in 2012 baseline Fat File")
    return frame


def write_parquet(frame: pd.DataFrame, output: Path, logger: logging.Logger) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    try:
        frame.to_parquet(output, index=False)
        logger.info("parquet_writer=pandas")
        return
    except (ImportError, ValueError, OSError) as exc:
        logger.info("pandas_parquet_unavailable=%s", exc)
    rscript = Path(r"D:\LeStoreDownload\R\R-4.4.1\bin\x64\Rscript.exe")
    if not rscript.exists():
        raise RuntimeError("No Parquet writer available")
    with tempfile.TemporaryDirectory(prefix="hrs_exit_") as temp_dir:
        csv_path = Path(temp_dir) / "hrs_exit.csv"
        frame.to_csv(csv_path, index=False, na_rep="")
        r_code = (
            "args <- commandArgs(TRUE); d <- read.csv(args[1], stringsAsFactors=FALSE, "
            "na.strings=c('', 'NA'), colClasses='character', check.names=FALSE); "
            "for (x in c('exit_wave','death_year_raw','death_month_raw','death_year','death_month','age_2012','interview_year_2012','interview_month_2012')) "
            "if (x %in% names(d)) d[[x]] <- as.numeric(d[[x]]); "
            "for (x in c('date_valid','in_4y_window','baseline_match','age_60_plus','selected_earliest_4y','hrs_harmonized_match')) "
            "if (x %in% names(d)) { v <- tolower(trimws(as.character(d[[x]]))); d[[x]] <- ifelse(v %in% c('true','1'), TRUE, ifelse(v %in% c('false','0'), FALSE, NA)) }; "
            "arrow::write_parquet(d, args[2])"
        )
        subprocess.run([str(rscript), "--vanilla", "-e", r_code, str(csv_path), str(output)], check=True)
    logger.info("parquet_writer=R_arrow")


def main() -> None:
    logger = setup_logging()
    np.random.seed(SEED)
    DATA_ROOT.mkdir(parents=True, exist_ok=True)
    RESULT_ROOT.mkdir(parents=True, exist_ok=True)
    logger.info("START seed=%s", SEED)

    exit_frames = []
    wave_diagnostics = {}
    for wave in WAVE_CONFIG:
        frame, diagnostics = read_exit_wave(wave)
        exit_frames.append(frame)
        wave_diagnostics[str(wave)] = diagnostics
        logger.info("wave=%s rows=%s year_nonmissing=%s month_nonmissing=%s", wave, diagnostics["rows"], diagnostics["year_nonmissing"], diagnostics["month_nonmissing"])
    exits = pd.concat(exit_frames, ignore_index=True)
    total_rows = len(exits)
    unique_ids = exits["hhidpn"].nunique()
    if total_rows != 5985 or unique_ids != 5985:
        raise AssertionError(f"five-wave rows/unique IDs={total_rows}/{unique_ids}, expected 5985/5985")
    exits["in_4y_window"] = exits["death_year"].between(2012, 2016)

    baseline = read_baseline()
    if len(baseline) != 20554 or int(baseline["age_60_plus"].sum()) != 13867:
        raise AssertionError(f"unexpected baseline N/60+: {len(baseline)}/{int(baseline['age_60_plus'].sum())}")
    baseline_ids = set(baseline["hhidpn"])
    exits["baseline_match"] = exits["hhidpn"].isin(baseline_ids)
    exits["age_2012"] = exits["hhidpn"].map(baseline.set_index("hhidpn")["age_2012"])
    exits["age_60_plus"] = exits["age_2012"] >= 60
    exits["selected_earliest_4y"] = False
    window = exits[exits["in_4y_window"] & exits["baseline_match"]].copy()
    window = window.sort_values(["hhidpn", "death_year", "death_month", "exit_wave"])
    earliest = window.drop_duplicates("hhidpn", keep="first")["hhidpn"]
    exits.loc[exits["hhidpn"].isin(set(earliest)), "selected_earliest_4y"] = True

    # Match against the harmonized HRS file by the same normalized 9-character key.
    harmonized_path = HRS_ROOT / "harmonised HRS" / "H_HRS_d.dta"
    _, harmonized_meta = pyreadstat.read_dta(str(harmonized_path), metadataonly=True)
    if "hhidpn" not in harmonized_meta.column_names:
        raise AssertionError("H_HRS_d.dta lacks hhidpn")
    harmonized, _ = pyreadstat.read_dta(str(harmonized_path), usecols=["hhidpn"])
    harmonized_ids = set(normalize_hhidpn(harmonized["hhidpn"]).dropna())
    exits["hrs_harmonized_match"] = exits["hhidpn"].isin(harmonized_ids)

    window_all = exits[exits["in_4y_window"]]
    selected = exits[exits["selected_earliest_4y"]]
    selected_60 = selected[selected["age_60_plus"]]
    event_year_counts = {str(int(key)): int(value) for key, value in selected_60["death_year"].value_counts().sort_index().items()}
    baseline_interview = baseline.set_index("hhidpn")[["interview_year_2012", "interview_month_2012"]]
    selected_60 = selected_60.join(baseline_interview, on="hhidpn")
    month_sensitivity = selected_60["death_year"].ne(2012) | (selected_60["death_month"] >= selected_60["interview_month_2012"])
    month_sensitivity_events_60 = int(month_sensitivity.sum())

    assertions = {
        "five_wave_rows_1187_1242_1310_980_1266": "PASS" if [wave_diagnostics[str(w)]["rows"] for w in WAVE_CONFIG] == [1187, 1242, 1310, 980, 1266] else "FAIL",
        "2012_XA123_nonmissing_1180": "PASS" if wave_diagnostics["2012"]["year_nonmissing"] == 1180 else "FAIL",
        "special_codes_recorded": "PASS" if 9998 in set(exits["death_year_raw"].dropna()) and 9999 in set(exits["death_year_raw"].dropna()) and 98 in set(exits["death_month_raw"].dropna()) and 99 in set(exits["death_month_raw"].dropna()) else "FAIL",
        "five_wave_hhidpn_unique": "PASS" if unique_ids == total_rows == 5985 else "FAIL",
        "baseline_N_20554": "PASS" if len(baseline) == 20554 else "FAIL",
        "baseline_age60_N_13867": "PASS" if int(baseline["age_60_plus"].sum()) == 13867 else "FAIL",
        "four_year_window_matched_events_2550": "PASS" if len(selected) == 2550 else "FAIL",
        "four_year_window_age60_events_2352": "PASS" if len(selected_60) == 2352 else "FAIL",
        "harmonized_HRS_match_5985_of_5985": "PASS" if int(exits["hrs_harmonized_match"].sum()) == 5985 else "FAIL",
    }
    if "FAIL" in assertions.values():
        raise AssertionError(assertions)

    output_columns = [
        "hhid", "pn", "hhidpn", "exit_wave", "death_year_raw", "death_month_raw", "death_year", "death_month",
        "date_valid", "in_4y_window", "baseline_match", "age_2012", "age_60_plus", "selected_earliest_4y", "hrs_harmonized_match",
    ]
    write_parquet(exits[output_columns], OUTPUT_PATH, logger)
    report_lines = [
        "# HRS Exit Event Count Report (2026-07-27)",
        "",
        "## Assertions",
        *[f"- {key}: {value}" for key, value in assertions.items()],
        "",
        "## Five-wave parsing",
        f"Rows by wave: " + "; ".join(f"{wave}={wave_diagnostics[str(wave)]['rows']}" for wave in WAVE_CONFIG) + ".",
        f"Combined rows={total_rows}; unique hhidpn={unique_ids}; harmonized HRS match={int(exits['hrs_harmonized_match'].sum())}/{total_rows}.",
        f"2012 death-year non-missing={wave_diagnostics['2012']['year_nonmissing']}/1187; month non-missing={wave_diagnostics['2012']['month_nonmissing']}/1187.",
        "Special codes treated as missing: year 9998/9999; month 98/99. Raw distributions are retained in the log and output columns.",
        "",
        "## Baseline and four-year window",
        f"2012 Fat File baseline N={len(baseline)}; age 60+ N={int(baseline['age_60_plus'].sum())}.",
        f"Death-year window [2012, 2016]: all Exit records={len(window_all)}; matched baseline records={len(window)}; unique earliest matched events={len(selected)}; age 60+ events={len(selected_60)}; 60+ cumulative mortality={len(selected_60)/int(baseline['age_60_plus'].sum()):.2%}.",
        f"Events among age 60+ by death year: {event_year_counts}.",
        f"Baseline-interview-month sensitivity (exclude 2012 deaths reported before baseline interview month): 60+ events={month_sensitivity_events_60}, difference={len(selected_60)-month_sensitivity_events_60}.",
        "",
        "## Scope and limitations",
        "This is an event-count feasibility output for HRS external validation. It does not construct person-period data, FI/IC variables, or mortality models. The 2012-2016 window is defined by cleaned death year; death month is retained for quality checks and sensitivity only.",
        "",
        "## Outputs",
        f"- `{OUTPUT_PATH}`",
        f"- `{REPORT_PATH}`",
        f"- `{LOG_PATH}`",
    ]
    REPORT_PATH.write_text("\n".join(report_lines) + "\n", encoding="utf-8")
    logger.info("DONE rows=%s unique=%s window_matched=%s events60=%s", total_rows, unique_ids, len(selected), len(selected_60))
    print(json.dumps({"rows": total_rows, "unique_hhidpn": unique_ids, "baseline_n": len(baseline), "baseline_age60": int(baseline["age_60_plus"].sum()), "window_events": len(selected), "window_events_age60": len(selected_60), "mortality_rate_age60": len(selected_60) / int(baseline["age_60_plus"].sum()), "output": str(OUTPUT_PATH)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
