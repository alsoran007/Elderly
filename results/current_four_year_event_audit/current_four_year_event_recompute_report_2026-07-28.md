# Current four-year mortality event recomputation

## Material Passport
- Type: source-level mortality event audit for KLoSA, SHARE, and MHAS
- Status: VERIFIED after raw-source rerun; primary event count uses the project year-window rule
- Script: D:\AI_project\project3\code\03_outcome\recompute_current_four_year_events.py
- Log: D:\AI_project\project3\logs\current_four_year_event_recompute_2026-07-28.log
- Raw data modified: no

## Primary results

| Cohort | Age-60+ denominator | Matched death dates | Pre-baseline deaths | Primary events | Exact-date sensitivity |
|---|---:|---:|---:|---:|---:|
| KLoSA | 5,289 | 1,447 | 1 | 585 | 510 |
| SHARE | 36,604 | 8,272 | 9 | 3,689 | 3,204 |
| MHAS | 10,174 | 1,942 | 21 | 1,404 | 1,246 |

Primary windows: KLoSA 2012-2016, SHARE 2011-2015, MHAS 2012-2016. Valid death year is sufficient for the primary event; exact-date sensitivity uses available month/day precision and a 1,461-day upper bound.
The event audit is restricted to the current age-60+ baseline denominators: KLoSA w04 age, SHARE wave-4 visits in 2011 with r4agey >= 60, and MHAS D-022 direct-or-derived age >= 60.

## Outputs
- Summary: `D:\AI_project\project3\results\current_four_year_event_audit\current_four_year_event_summary_2026-07-28.csv`
- KLoSA audit: `D:\AI_project\project3\results\current_four_year_event_audit\klosa_four_year_event_audit_2026-07-28.csv`
- SHARE audit: `D:\AI_project\project3\results\current_four_year_event_audit\share_four_year_event_audit_2026-07-28.csv`
- MHAS audit: `D:\AI_project\project3\results\current_four_year_event_audit\mhas_four_year_event_audit_2026-07-28.csv`
- Metadata: `D:\AI_project\project3\results\current_four_year_event_audit\current_four_year_event_metadata_2026-07-28.json`
