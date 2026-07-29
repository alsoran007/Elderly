# CHARLS Person-Period Construction Report (2026-07-27)

## Construction boundary
This is a new discrete-time wave framework. It does not modify or rerun `charls_outcome.py`, and it does not use exact death dates. Baseline covariates are repeated across intervals.

## Assertions
- baseline_N_17705: PASS
- age_60_N_7669: PASS
- ID_overlaps_15139_14395_13734: PASS
- exit_2013_overlap_408: PASS
- period_events_all_408_563_829_640: PASS
- period_events_60plus_342_443_651_502: PASS
- person_period_rows_64792: PASS
- person_period_events_2440: PASS
- no_rows_after_death_or_final_loss: PASS

## Sample and events
Baseline N=17705; age 60+ N=7669; person-period rows=64792; person-period events=2440; 60+ events=1938.
Period events (all/60+): 1=408/342; 2=563/443; 3=829/651; 4=640/502

## Risk-set decay (60+)
| period | interval | risk set start | deaths | intermittent missing | final lost | alive at end |
|---:|---|---:|---:|---:|---:|---:|
| 1 | 2011-2013 | 7669 | 342 | 528 | 218 | 6581 |
| 2 | 2013-2015 | 7109 | 443 | 423 | 129 | 6114 |
| 3 | 2015-2018 | 6537 | 651 | 356 | 167 | 5363 |
| 4 | 2018-2020 | 5719 | 502 | 0 | 299 | 4918 |

## Intermittent follow-up
Intermittent-missing persons=2893 (60+=1013). Among the 2015-missing baseline persons, 1226 reappeared in 2018/2020 and 1340 never reappeared. Reappearing persons retain the missing interval row and continue into later observed intervals.

## Unmatched 2013 Exit records
Unmatched records=23; using the official 10-character household key (2011 householdID + `0`), 15 belong to an existing baseline household and 8 are from households absent at baseline; duplicated existing-household groups=0. Unmatched records are not assigned baseline mortality events.

## Outputs
- `D:\AI_project\project3\data\analysis\charls_person_period_2026-07-27.parquet`
- `D:\AI_project\project3\data\analysis\charls_baseline_cohort_2026-07-27.parquet`
- `D:\AI_project\project3\results\outcome_charls\person_period\risk_set_decay_60plus_2026-07-27.csv`
- `D:\AI_project\project3\results\outcome_charls\person_period\person_period_status_summary_2026-07-27.csv`
- `D:\AI_project\project3\results\outcome_charls\person_period\person_period_report_2026-07-27.md`
- `D:\AI_project\project3\logs\build_charls_outcome_2026-07-27.log`
