# HRS Exit Event Count Report (2026-07-27)

## Assertions
- five_wave_rows_1187_1242_1310_980_1266: PASS
- 2012_XA123_nonmissing_1180: PASS
- special_codes_recorded: PASS
- five_wave_hhidpn_unique: PASS
- baseline_N_20554: PASS
- baseline_age60_N_13867: PASS
- four_year_window_matched_events_2550: PASS
- four_year_window_age60_events_2352: PASS
- harmonized_HRS_match_5985_of_5985: PASS

## Five-wave parsing
Rows by wave: 2012=1187; 2014=1242; 2016=1310; 2018=980; 2020=1266.
Combined rows=5985; unique hhidpn=5985; harmonized HRS match=5985/5985.
2012 death-year non-missing=1180/1187; month non-missing=1180/1187.
Special codes treated as missing: year 9998/9999; month 98/99. Raw distributions are retained in the log and output columns.

## Baseline and four-year window
2012 Fat File baseline N=20554; age 60+ N=13867.
Death-year window [2012, 2016]: all Exit records=3115; matched baseline records=2550; unique earliest matched events=2550; age 60+ events=2352; 60+ cumulative mortality=16.96%.
Events among age 60+ by death year: {'2012': 200, '2013': 575, '2014': 543, '2015': 494, '2016': 540}.
Baseline-interview-month sensitivity (exclude 2012 deaths reported before baseline interview month): 60+ events=2339, difference=13.

## Scope and limitations
This is an event-count feasibility output for HRS external validation. It does not construct person-period data, FI/IC variables, or mortality models. The 2012-2016 window is defined by cleaned death year; death month is retained for quality checks and sensitivity only.

## Outputs
- `D:\AI_project\project3\data\interim\hrs_exit_deaths_2026-07-27.parquet`
- `D:\AI_project\project3\results\outcome_hrs\hrs_event_count_report_2026-07-27.md`
- `D:\AI_project\project3\logs\hrs_exit_parse_2026-07-27.log`
