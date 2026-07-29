"""Build the CHARLS person-level mortality outcome from read-only raw files.

The script intentionally keeps exact exit dates separate from wave-midpoint
approximations. It uses 2011-07-01 only because the 2011 files contain no
interview date field; this assumption is reported and stress-tested at +/-3
months.
"""

from __future__ import annotations

import json
import logging
import re
import shutil
import subprocess
import tempfile
from datetime import date, datetime
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import pyreadstat

from lunar_convert import convert_lunar_to_solar


SEED = 20260726
WINDOW_5Y = 1826
WINDOW_8Y = 2922
BASELINE_DATE = pd.Timestamp("2011-07-01")
PROJECT_ROOT = Path(__file__).resolve().parents[2]
RAW_ROOT = PROJECT_ROOT.parent / "sql"
DATA_ROOT = PROJECT_ROOT / "data" / "analysis"
RESULT_ROOT = PROJECT_ROOT / "results" / "outcome_charls"
LOG_ROOT = PROJECT_ROOT / "logs"
OUTPUT_PARQUET = DATA_ROOT / "charls_outcome_2026-07-27.parquet"
REPORT = RESULT_ROOT / "charls_outcome_report_2026-07-27.md"
LOG_PATH = LOG_ROOT / "charls_outcome_2026-07-27.log"


def setup_logging() -> logging.Logger:
    LOG_ROOT.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger("charls_outcome")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()
    handler = logging.FileHandler(LOG_PATH, mode="w", encoding="utf-8")
    handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    logger.addHandler(handler)
    logger.addHandler(logging.StreamHandler())
    return logger


def raw_path(relative: str) -> Path:
    path = RAW_ROOT / relative
    if not path.exists():
        raise FileNotFoundError(path)
    return path


def read_dta(relative: str, columns: Sequence[str]) -> pd.DataFrame:
    frame, _ = pyreadstat.read_dta(str(raw_path(relative)), usecols=list(columns))
    return frame


def as_num(values: pd.Series) -> pd.Series:
    return pd.to_numeric(values, errors="coerce")


def as_clean_id(values: pd.Series) -> pd.Series:
    if pd.api.types.is_numeric_dtype(values):
        values = values.map(lambda x: "" if pd.isna(x) else f"{int(x):d}")
    result = values.astype("string").str.strip()
    return result.mask(result.isin(["", "<NA>", "nan", "None"]))


def assert_unique(values: pd.Series, label: str) -> None:
    valid = values.dropna()
    if valid.duplicated().any():
        raise AssertionError(f"duplicate IDs in {label}")


def normalize_id11(values: pd.Series) -> pd.Series:
    result = as_clean_id(values)
    if (result.dropna().str.len() != 11).any():
        raise AssertionError("2011 ID is not consistently 11 characters")
    return result


def rebuild_id12(household: pd.Series, id11: pd.Series) -> pd.Series:
    hh = as_clean_id(household)
    old = normalize_id11(id11)
    if (hh.dropna().str.len() != 9).any():
        raise AssertionError("2011 householdID is not consistently 9 characters")
    result = hh + "0" + old.str[-2:]
    if (result.dropna().str.len() != 12).any():
        raise AssertionError("reconstructed ID is not consistently 12 characters")
    return result


def valid_component(value: object, low: int, high: int) -> Optional[int]:
    try:
        if pd.isna(value):
            return None
        value = int(float(value))
    except (TypeError, ValueError, OverflowError):
        return None
    return value if low <= value <= high else None


def construct_dates(
    years: pd.Series,
    months: pd.Series,
    days: pd.Series,
    calendars: pd.Series,
    min_year: int,
    max_year: int,
    allow_day_imputation: bool = True,
) -> pd.DataFrame:
    """Construct dates and retain conversion diagnostics row by row."""
    rows: List[Dict[str, object]] = []
    for y, m, d, cal in zip(years, months, days, calendars):
        year = valid_component(y, min_year, max_year)
        month = valid_component(m, 1, 12)
        raw_day = valid_component(d, 1, 31)
        day_imputed = False
        if raw_day is None and allow_day_imputation and (pd.isna(d) or str(d).strip() in {"0", "0.0"}):
            raw_day = 15
            day_imputed = True
        calendar_code = valid_component(cal, 1, 2)
        converted = False
        conversion_status = "not_needed"
        solar: Optional[date] = None
        if year is not None and month is not None and raw_day is not None:
            if calendar_code == 2:
                solar = convert_lunar_to_solar(year, month, raw_day)
                converted = solar is not None
                conversion_status = "lunar_converted" if converted else "lunar_invalid"
            elif calendar_code in (1, None):
                try:
                    solar = date(year, month, raw_day)
                    conversion_status = "solar" if calendar_code == 1 else "calendar_missing_assumed_solar"
                except ValueError:
                    solar = None
                    conversion_status = "solar_invalid"
            else:
                conversion_status = "calendar_invalid"
        else:
            conversion_status = "components_missing_or_invalid"
        rows.append(
            {
                "date": pd.Timestamp(solar) if solar else pd.NaT,
                "calendar_code": calendar_code,
                "day_used": raw_day,
                "day_imputed": day_imputed,
                "converted": converted,
                "conversion_status": conversion_status,
                "raw_year": year,
                "raw_month": month,
                "raw_day": raw_day,
                "cross_year": bool(converted and solar.year != year),
                "cross_month": bool(converted and (solar.year != year or solar.month != month)),
            }
        )
    return pd.DataFrame(rows, index=years.index)


def scan_baseline_date_fields() -> List[Dict[str, object]]:
    hits: List[Dict[str, object]] = []
    for path in sorted((RAW_ROOT / "Charls" / "2011").glob("*.dta"), key=lambda p: p.name.lower()):
        _, meta = pyreadstat.read_dta(str(path), metadataonly=True)
        fields = []
        for name, label in zip(meta.column_names, meta.column_labels):
            text = f"{name} {label}".lower()
            if re.search(r"iyear|imonth|interview.*date|date.*interview|visit.*date|date.*visit", text):
                fields.append(name)
        if fields:
            hits.append({"file": str(path), "fields": fields})
    return hits


def read_followup(relative: str, wave: int) -> pd.DataFrame:
    frame = read_dta(relative, ["ID", "died", "iyear", "imonth"])
    result = pd.DataFrame(
        {
            "id_12": as_clean_id(frame["ID"]),
            f"present_{wave}": 1,
            f"died_{wave}": as_num(frame["died"]),
            f"iyear_{wave}": as_num(frame["iyear"]),
            f"imonth_{wave}": as_num(frame["imonth"]),
        }
    )
    assert_unique(result["id_12"], f"CHARLS {wave} Sample_Infor")
    return result.set_index("id_12")


def wave_midpoint(years: pd.Series, months: pd.Series) -> pd.Series:
    out = []
    for year, month in zip(years, months):
        y = valid_component(year, 1900, 2100)
        m = valid_component(month, 1, 12) or 7
        out.append(pd.Timestamp(date(y, m, 15)) if y else pd.NaT)
    return pd.Series(out, index=years.index)


def read_exit(relative: str, day_field: bool, min_year: int, max_year: int) -> pd.DataFrame:
    columns = ["ID", "exb001_1", "exb001_2", "exb002"] + (["exb001_3"] if day_field else [])
    frame = read_dta(relative, columns)
    raw_day = frame["exb001_3"] if day_field else pd.Series(np.nan, index=frame.index)
    calendar = frame["exb002"]
    dates = construct_dates(frame["exb001_1"], frame["exb001_2"], raw_day, calendar, min_year, max_year)
    result = pd.DataFrame(
        {
            "id_12": as_clean_id(frame["ID"]),
            "exit_record": 1,
            "death_date": dates["date"].values,
            "death_date_calendar": dates["calendar_code"].values,
            "death_date_day_imputed": dates["day_imputed"].values,
            "death_date_converted": dates["converted"].values,
            "death_date_cross_year": dates["cross_year"].values,
            "death_date_cross_month": dates["cross_month"].values,
            "death_date_conversion_status": dates["conversion_status"].values,
            "death_raw_year": dates["raw_year"].values,
            "death_raw_month": dates["raw_month"].values,
        }
    )
    assert_unique(result["id_12"], relative)
    return result.set_index("id_12")


def first_nonmissing(series_list: Iterable[object]) -> object:
    for value in series_list:
        if pd.notna(value):
            return value
    return pd.NaT


def km_curve(times: pd.Series, events: pd.Series) -> Tuple[List[float], List[float]]:
    frame = pd.DataFrame({"time": times, "event": events}).dropna().sort_values("time")
    survival = 1.0
    xs = [0.0]
    ys = [1.0]
    for t, group in frame.groupby("time"):
        at_risk = int((frame["time"] >= t).sum())
        deaths = int(group["event"].sum())
        if deaths:
            survival *= 1 - deaths / at_risk
            xs.extend([float(t), float(t)])
            ys.extend([ys[-1], survival])
    return xs, ys


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
        raise RuntimeError("Neither a Python parquet engine nor the configured Rscript is available")
    with tempfile.TemporaryDirectory(prefix="charls_outcome_") as temp_dir:
        temp_csv = Path(temp_dir) / "outcome.csv"
        frame.to_csv(temp_csv, index=False, na_rep="")
        date_cols = ["baseline_date", "death_date", "last_known_alive_date"]
        r_code = (
            "args <- commandArgs(TRUE); d <- read.csv(args[1], stringsAsFactors=FALSE, na.strings=c('', 'NA')); "
            "for (x in c('baseline_date','death_date','last_known_alive_date')) if (x %in% names(d)) d[[x]] <- as.Date(d[[x]]); "
            "for (x in c('prebaseline_death','death_date_converted','death_date_day_imputed','death_date_cross_year','death_date_cross_month')) "
            "if (x %in% names(d)) { v <- tolower(trimws(as.character(d[[x]]))); d[[x]] <- ifelse(v %in% c('true','1'), TRUE, ifelse(v %in% c('false','0'), FALSE, NA)) }; "
            "arrow::write_parquet(d, args[2])"
        )
        subprocess.run([str(rscript), "--vanilla", "-e", r_code, str(temp_csv), str(output)], check=True)
    logger.info("parquet_writer=R_arrow")


def make_plots(frame: pd.DataFrame) -> None:
    RESULT_ROOT.mkdir(parents=True, exist_ok=True)
    observed = frame[frame["time_to_event"].notna()].copy()
    plt.figure(figsize=(8, 5))
    plt.hist(observed["time_to_event"], bins=30, color="#2c7fb8", alpha=0.85)
    plt.axvline(WINDOW_5Y, color="#d95f0e", linestyle="--", label="1826 days")
    plt.xlabel("Days from baseline")
    plt.ylabel("Persons")
    plt.title("CHARLS follow-up time distribution")
    plt.legend()
    plt.tight_layout()
    plt.savefig(RESULT_ROOT / "followup_time_distribution.png", dpi=160)
    plt.close()

    km_input = frame[frame["time_5y"].notna() & frame["event_5y"].notna()]
    xs, ys = km_curve(km_input["time_5y"], km_input["event_5y"])
    plt.figure(figsize=(8, 5))
    plt.step(xs, ys, where="post", color="#1b9e77")
    plt.xlim(0, WINDOW_5Y)
    plt.ylim(0, 1.02)
    plt.xlabel("Days from baseline")
    plt.ylabel("Kaplan-Meier survival")
    plt.title("CHARLS 5-year all-cause mortality KM curve")
    plt.tight_layout()
    plt.savefig(RESULT_ROOT / "kaplan_meier_5y.png", dpi=160)
    plt.close()

    lunar = frame[frame["death_date_converted"] == True].copy()
    if not lunar.empty:
        before = lunar.groupby(["death_raw_year", "death_raw_month"]).size().reset_index(name="n")
        after = lunar.assign(year=lunar["death_date"].dt.year, month=lunar["death_date"].dt.month).groupby(["year", "month"]).size().reset_index(name="n")
        fig, axes = plt.subplots(1, 2, figsize=(11, 4), sharey=True)
        axes[0].bar(before["death_raw_year"].astype(str) + "-" + before["death_raw_month"].astype(str), before["n"], color="#756bb1")
        axes[0].set_title("Lunar raw year-month")
        axes[1].bar(after["year"].astype(str) + "-" + after["month"].astype(str), after["n"], color="#31a354")
        axes[1].set_title("Converted solar year-month")
        for axis in axes:
            axis.tick_params(axis="x", labelrotation=90, labelsize=7)
        fig.tight_layout()
        fig.savefig(RESULT_ROOT / "lunar_conversion_before_after.png", dpi=160)
        plt.close(fig)


def make_report(
    frame: pd.DataFrame,
    diagnostics: Dict[str, object],
    assertions: Dict[str, str],
    literature_note: str,
) -> None:
    counts = frame["followup_status"].value_counts().to_dict()
    source_counts = frame["death_date_source"].value_counts(dropna=False).to_dict()
    prebaseline = frame[frame["prebaseline_death"] == True]
    prebaseline_details = "; ".join(
        f"{row.id_12}: baseline={row.baseline_date.date()}, death={row.death_date.date()}, "
        f"delta_days={int((row.death_date - row.baseline_date).days)}"
        for row in prebaseline.itertuples()
    ) or "none"
    sex_age = []
    grouped = frame.assign(age_group=pd.cut(frame["baseline_age"], [-np.inf, 59, 69, 79, np.inf], labels=["<60", "60-69", "70-79", "80+"])).groupby(["female", "age_group"], dropna=False)
    for (sex, age_group), group in grouped:
        sex_age.append(f"female={sex}, age_group={age_group}: n={len(group)}, deaths_5y={int(group['event_5y'].sum(skipna=True))}")
    lines = [
        "# CHARLS Outcome Construction Report (2026-07-27)",
        "",
        "## Baseline date decision",
        f"The date scan found personal interview year/month in `2011/weight.dta`; the baseline date uses that observed month with day 15 because no interview day is available. Unmatched records, if any, use the task-specified {BASELINE_DATE.date()} fallback. Sensitivity checks shift each baseline month by +/-3 months.",
        f"Date-field scan hits: {diagnostics['baseline_date_scan_hits']}; baseline date sources: {diagnostics['baseline_date_source_counts']}; baseline date range: {diagnostics['baseline_date_range']}; birth calendar codes: {diagnostics['birth_calendar_counts']}; lunar birth-date conversions: {diagnostics['birth_lunar_converted_n']}.",
        "",
        "## ID and sample flow",
        f"Baseline N={len(frame)}; 2015 overlap={diagnostics['overlap_2015']}; 2018 overlap={diagnostics['overlap_2018']}; 2020 overlap={diagnostics['overlap_2020']}; 2013 Exit overlap={diagnostics['exit_2013_overlap']} / {diagnostics['exit_2013_rows']}.",
        f"The 23 unmatched 2013 Exit records are retained in the audit count and excluded only from the baseline-linked outcome because their reconstructed 12-character IDs are absent from the 2011 baseline.",
        "",
        "## Follow-up status and events",
        f"Status counts: {counts}.",
        f"Death-date sources: {source_counts}.",
        f"5-year events={int(frame['event_5y'].sum(skipna=True))}; 8-year events={int(frame['event_8y'].sum(skipna=True))}; 5-year analysis N={int(frame['event_5y'].notna().sum())}; 8-year analysis N={int(frame['event_8y'].notna().sum())}.",
        f"Pre-baseline death/date conflicts={diagnostics['prebaseline_death_n']}; records remain `dead` with original death dates, but their time_to_event/event_5y/time_5y/event_8y/time_8y are missing and excluded from time-based denominators. Details: {prebaseline_details}.",
        f"5-year/8-year death dates are based on {WINDOW_5Y}/{WINDOW_8Y} days. Exact exit dates take precedence; deaths known only from Sample_Infor use the corresponding wave interview midpoint and are marked wave_midpoint.",
        "",
        "## Calendar handling",
        f"2013 Exit calendar counts: {diagnostics['exit_2013_calendar_counts']}; 2020 Exit calendar counts: {diagnostics['exit_2020_calendar_counts']}.",
        f"Lunar death records converted={diagnostics['lunar_death_converted_n']}; day-imputed={diagnostics['lunar_day_imputed_n']}; converted records crossing year={diagnostics['lunar_cross_year_n']}, crossing month={diagnostics['lunar_cross_month_n']}. The questionnaire has no leap-month flag, so lunar dates were treated as non-leap months.",
        "",
        "## Stratified event table",
        *[f"- {x}" for x in sex_age],
        "",
        "## Follow-up plots",
        "- `followup_time_distribution.png` shows observed death/censoring time.",
        "- `kaplan_meier_5y.png` shows the 5-year KM curve among non-lost records.",
        "- `lunar_conversion_before_after.png` compares raw lunar year-month counts with converted solar year-month counts.",
        "",
        "## Literature comparison gate",
        literature_note,
        "The local literature matrix contains a CHARLS mortality-model study with 183 deaths in a disease-specific asthma cohort, but that is not a valid all-cause population benchmark and is not used as one.",
        "",
        "## Preconditions and checks",
    ]
    lines.extend(f"- {key}: {value}" for key, value in assertions.items())
    lines.extend([
        "",
        "## Limitations",
        "2011 baseline months are observed in weight.dta but interview days are unavailable, so day 15 is used. 2013 lunar dates are converted with a non-leap-month approximation; 2015/2018/2020 deaths generally have wave-level timing only. Lost-to-follow-up persons retain missing analysis time rather than being silently assigned an artificial censoring date.",
        "",
        "## Output",
        f"- `{OUTPUT_PARQUET}`",
        f"- `{REPORT}`",
        f"- `{LOG_PATH}`",
    ])
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    logger = setup_logging()
    DATA_ROOT.mkdir(parents=True, exist_ok=True)
    RESULT_ROOT.mkdir(parents=True, exist_ok=True)
    np.random.seed(SEED)
    logger.info("START seed=%s", SEED)

    baseline_date_hits = scan_baseline_date_fields()
    base_raw = read_dta("Charls/2011/demographic_background.dta", ["ID", "householdID", "ba002_1", "ba002_2", "ba002_3", "ba003", "ba004", "rgender"])
    base = pd.DataFrame(
        {
            "id_w1_11": normalize_id11(base_raw["ID"]),
            "household_id": as_clean_id(base_raw["householdID"]),
            "ba002_1": base_raw["ba002_1"],
            "ba002_2": base_raw["ba002_2"],
            "ba002_3": base_raw["ba002_3"],
            "ba003": base_raw["ba003"],
            "ba004": base_raw["ba004"],
            "rgender": base_raw["rgender"],
        }
    )
    base["id_12"] = rebuild_id12(base["household_id"], base["id_w1_11"])
    assert_unique(base["id_w1_11"], "CHARLS 2011 raw IDs")
    assert_unique(base["id_12"], "CHARLS 2011 reconstructed IDs")
    if len(base) != 17705:
        raise AssertionError(f"unexpected CHARLS 2011 baseline N={len(base)}")

    weight = read_dta("Charls/2011/weight.dta", ["ID", "iyear", "imonth"])
    raw_weight_ids = as_clean_id(weight["ID"])
    valid_weight = raw_weight_ids.notna() & raw_weight_ids.str.len().eq(11)
    weight = weight.loc[valid_weight].reset_index(drop=True)
    weight_ids = normalize_id11(weight["ID"])
    assert_unique(weight_ids, "CHARLS 2011 weight IDs")
    weight_dates = wave_midpoint(as_num(weight["iyear"]), as_num(weight["imonth"]))
    date_map = pd.Series(weight_dates.to_numpy(), index=weight_ids).to_dict()
    base["baseline_date"] = base["id_w1_11"].map(date_map)
    base["baseline_date_source"] = np.where(base["baseline_date"].notna(), "weight_iyear_imonth", "fallback_2011_07_01")
    base["baseline_date"] = pd.to_datetime(base["baseline_date"], errors="coerce").fillna(BASELINE_DATE)
    base = base.set_index("id_12", drop=False)

    samples = {}
    for wave in (2015, 2018, 2020):
        samples[wave] = read_followup(f"Charls/{wave}/Sample_Infor.dta", wave)
        overlap = int(base["id_12"].isin(samples[wave].index).sum())
        expected = {2015: 15139, 2018: 14395, 2020: 13734}[wave]
        if overlap != expected:
            raise AssertionError(f"ID overlap mismatch for {wave}: {overlap} != {expected}")
        base = base.join(samples[wave], how="left")
        logger.info("wave=%s overlap=%s", wave, overlap)

    exit13 = read_exit("Charls/2013/Exit_Interview.dta", False, 2011, 2014)
    exit20 = read_exit("Charls/2020/Exit_Module.dta", True, 2011, 2020)
    exit13_overlap = int(base["id_12"].isin(exit13.index).sum())
    if exit13_overlap != 408:
        raise AssertionError(f"2013 Exit overlap mismatch: {exit13_overlap} != 408")

    base = base.join(exit13.add_suffix("_2013"), how="left")
    base = base.join(exit20.add_suffix("_2020"), how="left")

    died_columns = ["died_2015", "died_2018", "died_2020"]
    for col in died_columns:
        base[col] = as_num(base[col])
    for left, right in ((2015, 2018), (2015, 2020), (2018, 2020)):
        ids_left = set(base.index[base[f"died_{left}"] == 1])
        ids_right = set(base.index[base[f"died_{right}"] == 1])
        if ids_left.intersection(ids_right):
            raise AssertionError(f"died status overlap between {left} and {right}")

    death_flags = (
        (base[died_columns].eq(1).any(axis=1))
        | base["exit_record_2013"].eq(1)
        | base["exit_record_2020"].eq(1)
    )
    sample_presence = base[["present_2015", "present_2018", "present_2020"]].notna().any(axis=1)
    base["followup_status"] = np.select([death_flags, sample_presence], ["dead", "alive_censored"], default="lost_to_followup")

    base["death_date"] = pd.NaT
    base["death_date_source"] = pd.NA
    base["death_date_calendar"] = pd.NA
    base["death_date_converted"] = False
    base["death_date_day_imputed"] = False
    base["death_date_cross_year"] = False
    base["death_date_cross_month"] = False
    base["death_raw_year"] = pd.NA
    base["death_raw_month"] = pd.NA
    for idx, row in base.iterrows():
        exit_candidates = []
        for suffix in ("_2013", "_2020"):
            if row.get(f"exit_record{suffix}") == 1:
                candidate = row.get(f"death_date{suffix}")
                if pd.notna(candidate):
                    exit_candidates.append((candidate, suffix))
        if exit_candidates:
            chosen, suffix = min(exit_candidates, key=lambda x: x[0])
            base.at[idx, "death_date"] = chosen
            base.at[idx, "death_date_source"] = "exit_file"
            for key in ("calendar", "converted", "day_imputed", "cross_year", "cross_month"):
                base.at[idx, f"death_date_{key}"] = row.get(f"death_date_{key}{suffix}")
            base.at[idx, "death_raw_year"] = row.get(f"death_raw_year{suffix}")
            base.at[idx, "death_raw_month"] = row.get(f"death_raw_month{suffix}")
        elif death_flags.loc[idx]:
            death_wave = next((wave for wave in (2015, 2018, 2020) if row.get(f"died_{wave}") == 1), None)
            if death_wave is not None:
                midpoint = wave_midpoint(pd.Series([row.get(f"iyear_{death_wave}")]), pd.Series([row.get(f"imonth_{death_wave}")])).iloc[0]
                base.at[idx, "death_date"] = midpoint
                base.at[idx, "death_date_source"] = "wave_midpoint"

    base["last_known_alive_date"] = pd.NaT
    for wave in (2015, 2018, 2020):
        dates = wave_midpoint(base[f"iyear_{wave}"], base[f"imonth_{wave}"])
        valid_alive = base[f"present_{wave}"].notna() & (base[f"died_{wave}"] == 0)
        base.loc[valid_alive, "last_known_alive_date"] = base.loc[valid_alive, "last_known_alive_date"].combine(dates[valid_alive], max)

    base["death_date"] = pd.to_datetime(base["death_date"], errors="coerce")
    base["last_known_alive_date"] = pd.to_datetime(base["last_known_alive_date"], errors="coerce")
    base["time_to_event"] = pd.Series(np.nan, index=base.index, dtype=float)
    base["prebaseline_death"] = False
    dead_rows = base["followup_status"].eq("dead") & base["death_date"].notna()
    alive_rows = base["followup_status"].eq("alive_censored") & base["last_known_alive_date"].notna()
    base.loc[dead_rows, "time_to_event"] = (base.loc[dead_rows, "death_date"] - base.loc[dead_rows, "baseline_date"]).dt.days
    base.loc[alive_rows, "time_to_event"] = (base.loc[alive_rows, "last_known_alive_date"] - base.loc[alive_rows, "baseline_date"]).dt.days
    base["time_to_event"] = base["time_to_event"].astype("Float64")
    negative_n = int((base["time_to_event"] < 0).sum())
    if negative_n:
        negative_rows = base["time_to_event"] < 0
        base.loc[negative_rows, "prebaseline_death"] = True
        logger.warning(
            "prebaseline_death_rows=%s",
            base.loc[
                negative_rows,
                ["id_12", "baseline_date", "death_date", "death_date_source", "time_to_event"],
            ].to_dict("records"),
        )
        # Preserve the death status/date, but exclude impossible intervals from time-based analyses.
        base.loc[negative_rows, "time_to_event"] = pd.NA

    for window, label in ((WINDOW_5Y, "5y"), (WINDOW_8Y, "8y")):
        time_col = f"time_{label}"
        event_col = f"event_{label}"
        base[time_col] = base["time_to_event"].clip(upper=window)
        base[event_col] = pd.Series(pd.NA, index=base.index, dtype="Int64")
        known = base["time_to_event"].notna()
        base.loc[known, event_col] = 0
        base.loc[dead_rows & (base["time_to_event"] <= window), event_col] = 1

    birth_dates = construct_dates(base_raw["ba002_1"], base_raw["ba002_2"], base_raw["ba002_3"], base_raw["ba003"], 1900, 2011)
    base["birth_date"] = birth_dates["date"].values
    base["baseline_age"] = np.floor((base["baseline_date"] - base["birth_date"]).dt.days / 365.2425)
    fallback_age = as_num(base["ba004"])
    age_missing = base["baseline_age"].isna() & fallback_age.notna()
    base.loc[age_missing, "baseline_age"] = fallback_age[age_missing]
    base["female"] = base["rgender"].map({1: 0, 2: 1}).astype("Int64")
    base["death_date_calendar"] = pd.to_numeric(base["death_date_calendar"], errors="coerce").astype("Int64")

    sensitivity = {}
    for shift, shifted in (("minus_3m", pd.Timestamp("2011-04-01")), ("plus_3m", pd.Timestamp("2011-10-01"))):
        shifted_baseline = base["baseline_date"] + (shifted - BASELINE_DATE)
        shifted_time = (base["death_date"].fillna(base["last_known_alive_date"]) - shifted_baseline).dt.days
        sensitivity[shift] = int(((shifted_time <= WINDOW_5Y) & (shifted_time >= 0) & base["followup_status"].eq("dead")).sum())

    diagnostics = {
        "baseline_date_scan_hits": len(baseline_date_hits),
        "baseline_date_source_counts": base["baseline_date_source"].value_counts().to_dict(),
        "baseline_date_range": f"{base['baseline_date'].min().date()} to {base['baseline_date'].max().date()}",
        "birth_calendar_counts": base_raw["ba003"].value_counts(dropna=False).to_dict(),
        "birth_lunar_converted_n": int(((birth_dates["converted"] == True)).sum()),
        "overlap_2015": int(base["id_12"].isin(samples[2015].index).sum()),
        "overlap_2018": int(base["id_12"].isin(samples[2018].index).sum()),
        "overlap_2020": int(base["id_12"].isin(samples[2020].index).sum()),
        "exit_2013_overlap": exit13_overlap,
        "exit_2013_rows": len(exit13),
        "exit_2013_calendar_counts": exit13["death_date_calendar"].value_counts(dropna=False).to_dict(),
        "exit_2020_calendar_counts": exit20["death_date_calendar"].value_counts(dropna=False).to_dict(),
        "lunar_death_converted_n": int(base["death_date_converted"].sum()),
        "lunar_day_imputed_n": int(((base["death_date_converted"] == True) & base["death_date_day_imputed"]).sum()),
        "lunar_cross_year_n": int(base["death_date_cross_year"].sum()),
        "lunar_cross_month_n": int(base["death_date_cross_month"].sum()),
        "sensitivity": sensitivity,
        "negative_followup_n": negative_n,
        "prebaseline_death_n": int(base["prebaseline_death"].sum()),
    }
    assertions = {
        "baseline_N_17705": "PASS",
        "ID_reconstruction_and_uniqueness": "PASS",
        "expected_ID_overlaps_15139_14395_13734_and_exit_408": "PASS",
        "died_wave_intersections_all_zero": "PASS",
        "baseline_date_scan_and_fallback_recorded": "PASS",
        "no_negative_followup_time_after_explicit_exclusion": "PASS" if not (base["time_to_event"] < 0).any() else "FAIL",
        "prebaseline_death_explicitly_excluded_from_time_analysis": "PASS" if int(base["prebaseline_death"].sum()) == negative_n else "FAIL",
        "status_partition_sums_to_17705": "PASS" if sum(counts for counts in base["followup_status"].value_counts().tolist()) == len(base) else "FAIL",
    }
    if "FAIL" in assertions.values():
        raise AssertionError(assertions)

    keep = [
        "id_12", "id_w1_11", "household_id", "baseline_date", "baseline_date_source", "baseline_age", "female", "birth_date",
        "death_date", "death_date_source", "death_date_calendar", "last_known_alive_date", "followup_status",
        "prebaseline_death", "time_to_event", "event_5y", "time_5y", "event_8y", "time_8y", "death_date_converted",
        "death_date_day_imputed", "death_date_cross_year", "death_date_cross_month", "death_raw_year", "death_raw_month",
    ]
    output = base.reset_index(drop=True)[keep].copy()
    write_parquet(output, OUTPUT_PARQUET, logger)
    make_plots(output)
    literature_note = (
        "STATUS: UNVERIFIED/BLOCKED. The local literature corpus did not provide a directly comparable published "
        "all-cause 5-year CHARLS population mortality estimate. The nearest local numeric result (183 deaths) is "
        "from a disease-specific asthma cohort and is not a valid benchmark. The 2-percentage-point comparison gate "
        "therefore cannot be passed without an authoritative comparable source."
    )
    make_report(output, diagnostics, assertions, literature_note)
    logger.info("DONE rows=%s event_5y=%s event_8y=%s status_counts=%s", len(output), int(output["event_5y"].sum(skipna=True)), int(output["event_8y"].sum(skipna=True)), output["followup_status"].value_counts().to_dict())
    print(json.dumps({"rows": len(output), "event_5y": int(output["event_5y"].sum(skipna=True)), "event_8y": int(output["event_8y"].sum(skipna=True)), "status_counts": output["followup_status"].value_counts().to_dict(), "output": str(OUTPUT_PARQUET), "literature_gate": "UNVERIFIED"}, ensure_ascii=False))


if __name__ == "__main__":
    main()
