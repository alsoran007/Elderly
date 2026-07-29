# KLoSA w08/w09 death-date variable audit

Run date: 2026-07-28. Raw KLoSA files were read only; no outcome variables were constructed.

## Conclusion

The irregular field names are confirmed as the correct wave-specific death-date variables. w08 uses `w08x_a010Y`, `w08x_a010M`, `w08x_a010D`; w09 uses `w09X_A010Y`, `w09X_A010M`, `w09X_A010D`. All six fields have the expected death-date labels.

## Source audit

| Wave | Main rows | EXIT rows | Date-valid | Date-valid % | Year 2012-2016 | Complete dates in window | Same-wave PID link | Prior-wave union link |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| w08 | 6488 | 512 | 438 | 85.55% | 9 | 2 | 0 | 510/512 (99.61%) |
| w09 | 6057 | 535 | 487 | 91.03% | 7 | 6 | 0 | 534/535 (99.81%) |

## Missing-date components

- w08: year `-9`=11; month `-9`=27; day `-9`=73; any missing component=73; all three `-9`=11; valid full dates=438/512.
- w09: year `-9`=13; month `-9`=23; day `-9`=48; any missing component=48; all three `-9`=12; valid full dates=487/535.

## Interpretation and boundary

- The zero same-wave PID overlap is expected for EXIT records representing respondents who are no longer present in that wave's main interview file; it is not treated as a date-variable failure.
- Historical main-file linkage is 510/512 for w08 against w01-w07 and 534/535 for w09 against w01-w08. The three unmatched PIDs are retained in the separate audit CSV for review.
- The previously noted w08 2012-2016 year-window count is 9, but only 2 have complete calendar dates. w09 has 7 year-window records, 6 with complete calendar dates. These are raw source diagnostics, not final event counts.
- The harmonization program's `-9` handling is consistent with this audit: unknown date components remain unresolved rather than being imputed.

## Outputs

- Summary: `D:/AI_project/project3/results/klosa_w08_w09_date_audit/klosa_w08_w09_date_summary_2026-07-28.csv`
- Field definitions: `D:/AI_project/project3/results/klosa_w08_w09_date_audit/klosa_w08_w09_date_field_definitions_2026-07-28.csv`
- Row-level audit: `D:/AI_project/project3/results/klosa_w08_w09_date_audit/klosa_w08_w09_date_records_2026-07-28.csv`
- Unmatched historical PIDs: `D:/AI_project/project3/results/klosa_w08_w09_date_audit/klosa_w08_w09_unmatched_prior_pid_2026-07-28.csv`
- Log: `D:/AI_project/project3/logs/klosa_w08_w09_date_audit_2026-07-28.log`
