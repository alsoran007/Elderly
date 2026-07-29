# FI Validation Audit (2026-07-28)

Read-only validation of the three newly generated Parquet extracts.
Raw files under D:/AI_project/sql were not modified.

## Summary

| Cohort | Rows | Age 60+ | FI eligible | FI eligible 60+ | Stems with data | Threshold | FI range | Checks |
|---|---:|---:|---:|---:|---:|---:|---|---|
| HRS | 20554 | 13867 | 11372 | 8854 | 33/41 | 27.0 | PASS | PASS |
| SHARE | 54550 | 36604 | 54196 | 36379 | 31/41 | 25.0 | PASS | PASS |
| MHAS | 26839 | 10174 | 14363 | 9094 | 27/41 | 22.0 | PASS | PASS |

## Extract Findings

- HRS: 20,554 rows; age 60+ N=13,867; FI-eligible N=11,372; FI-eligible age 60+ N=8,854.
- SHARE: 54,550 rows; age 60+ N=36,604; FI-eligible N=54,196; FI-eligible age 60+ N=36,379.
- MHAS: 26,839 rows; age 60+ N=10,174; FI-eligible N=14,363; FI-eligible age 60+ N=9,094.
- All stored FI values are within [0,1]. Threshold, eligibility, and age-60 logic checks pass.

## Field Availability

- HRS absent: none
- HRS all-NA: livere, digeste, asthmae, urina, joga, armsa, slfmem, mbmi
- SHARE absent: r4dyslipe, r4livere, r4kidneye, r4digeste, r4urina, r4walk1kma, r4joga, r4painfr, r4fall, r4mbmi
- SHARE all-NA: none
- MHAS absent: r3lunge, r3hearte, r3psyche, r3dyslipe, r3livere, r3kidneye, r3digeste, r3asthmae, r3urina, r3housewka, r3walk100a, r3walk1kma, r3dsight, r3nsight
- MHAS all-NA: none

## HRS Mapping Risks

- dyslipe is selected as nc110 (cholesterol test since previous wave), not a dyslipidemia diagnosis.
- mbmi is all-NA because the script searches nb, while source height/weight are nc142/nc139.
- urina searches ng only, while available incontinence is nc087.
- housewka and mealsa both use ng041, creating a duplicate source indicator.
- kidneye is nc017 (kidney trouble due to diabetes), a narrower construct with high missingness.

These are review findings, not silent changes to FI definitions.

## Outputs

- `D:\AI_project\project3\results\fi_validation_cohorts\fi_validation_summary_2026-07-28.csv`
- `D:\AI_project\project3\results\fi_validation_cohorts\fi_validation_missingness_2026-07-28.csv`
- `D:\AI_project\project3\logs\fi_validation_audit_2026-07-28.log`
