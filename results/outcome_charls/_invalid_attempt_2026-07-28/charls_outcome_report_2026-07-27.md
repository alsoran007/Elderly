# CHARLS Outcome Construction Report (2026-07-27)

## Baseline date decision
The date scan found personal interview year/month in `2011/weight.dta`; the baseline date uses that observed month with day 15 because no interview day is available. Unmatched records, if any, use the task-specified 2011-07-01 fallback. Sensitivity checks shift each baseline month by +/-3 months.
Date-field scan hits: 1; baseline date sources: {'weight_iyear_imonth': 17705}; baseline date range: 2011-06-15 to 2012-03-15; birth calendar codes: {2: 13681, 1: 3921, nan: 103}; lunar birth-date conversions: 13294.

## ID and sample flow
Baseline N=17705; 2015 overlap=15139; 2018 overlap=14395; 2020 overlap=13734; 2013 Exit overlap=408 / 431.
The 23 unmatched 2013 Exit records are retained in the audit count and excluded only from the baseline-linked outcome because their reconstructed 12-character IDs are absent from the 2011 baseline.

## Follow-up status and events
Status counts: {'lost_to_followup': 17705}.
Death-date sources: {<NA>: 17705}.
5-year events=0; 8-year events=0; 5-year analysis N=0; 8-year analysis N=0.
5-year/8-year death dates are based on 1826/2922 days. Exact exit dates take precedence; deaths known only from Sample_Infor use the corresponding wave interview midpoint and are marked wave_midpoint.

## Calendar handling
2013 Exit calendar counts: {2.0: 241, 1.0: 185, nan: 5}; 2020 Exit calendar counts: {1.0: 588, 2.0: 181, nan: 1}.
Lunar death records converted=0; day-imputed=0; converted records crossing year=0, crossing month=0. The questionnaire has no leap-month flag, so lunar dates were treated as non-leap months.

## Stratified event table
- female=0, age_group=<60: n=4638, deaths_5y=0
- female=0, age_group=60-69: n=2275, deaths_5y=0
- female=0, age_group=70-79: n=1060, deaths_5y=0
- female=0, age_group=80+: n=244, deaths_5y=0
- female=0, age_group=nan: n=254, deaths_5y=0
- female=1, age_group=<60: n=5388, deaths_5y=0
- female=1, age_group=60-69: n=2216, deaths_5y=0
- female=1, age_group=70-79: n=991, deaths_5y=0
- female=1, age_group=80+: n=318, deaths_5y=0
- female=1, age_group=nan: n=308, deaths_5y=0
- female=<NA>, age_group=<60: n=10, deaths_5y=0
- female=<NA>, age_group=60-69: n=2, deaths_5y=0
- female=<NA>, age_group=70-79: n=1, deaths_5y=0

## Follow-up plots
- `followup_time_distribution.png` shows observed death/censoring time.
- `kaplan_meier_5y.png` shows the 5-year KM curve among non-lost records.
- `lunar_conversion_before_after.png` compares raw lunar year-month counts with converted solar year-month counts.

## Literature comparison gate
STATUS: UNVERIFIED/BLOCKED. The local literature corpus did not provide a directly comparable published all-cause 5-year CHARLS population mortality estimate. The nearest local numeric result (183 deaths) is from a disease-specific asthma cohort and is not a valid benchmark. The 2-percentage-point comparison gate therefore cannot be passed without an authoritative comparable source.
The local literature matrix contains a CHARLS mortality-model study with 183 deaths in a disease-specific asthma cohort, but that is not a valid all-cause population benchmark and is not used as one.

## Preconditions and checks
- baseline_N_17705: PASS
- ID_reconstruction_and_uniqueness: PASS
- expected_ID_overlaps_15139_14395_13734_and_exit_408: PASS
- died_wave_intersections_all_zero: PASS
- baseline_date_scan_and_fallback_recorded: PASS
- no_negative_followup_time: PASS
- status_partition_sums_to_17705: PASS

## Limitations
2011 baseline months are observed in weight.dta but interview days are unavailable, so day 15 is used. 2013 lunar dates are converted with a non-leap-month approximation; 2015/2018/2020 deaths generally have wave-level timing only. Lost-to-follow-up persons retain missing analysis time rather than being silently assigned an artificial censoring date.

## Output
- `D:\AI_project\project3\data\analysis\charls_outcome_2026-07-27.parquet`
- `D:\AI_project\project3\results\outcome_charls\charls_outcome_report_2026-07-27.md`
- `D:\AI_project\project3\logs\charls_outcome_2026-07-27.log`
