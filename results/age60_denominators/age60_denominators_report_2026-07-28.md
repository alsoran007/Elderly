# Baseline age-60+ denominator audit

Run date: 2026-07-28. Raw source files were read only; no raw file was modified.

## Primary counts

The primary denominator is the number of records in the frozen baseline source with a valid age field and age >=60. No mortality, FI, model, or outcome construction was performed.

| Cohort | Baseline age field | Raw rows | Age-valid rows | Age missing | Age 60+ | 60+ / age-valid | Check |
|---|---:|---:|---:|---:|---:|---:|---|
| CHARLS | `2011 - ba002_1` | 17705 | 17651 | 54 (0.30%) | **7669** | 43.45% | PASS |
| CLHLS | `trueage` | 9765 | 9765 | 0 (0.00%) | **9749** | 99.84% | PASS |
| KLoSA | `w04A002_age` | 7486 | 7486 | 0 (0.00%) | **5289** | 70.65% | PASS |
| HRS | `na019` | 20554 | 20554 | 0 (0.00%) | **13867** | 67.47% | PASS |
| SHARE | `age2011` | 17356 | 16485 | 871 (5.02%) | **12722** | 77.17% | PASS |
| MHAS | `r3agey` | 26839 | 15716 | 11123 (41.44%) | **10176** | 64.75% | PASS |

## SHARE response sensitivity

SHARE `cv_r` contains pooled release rows; wave 4 is selected with `waveid==42`. The primary count is all wave-4 rows with valid `age2011` (12722). Among completed interviews (`interview==1`), the corresponding 60+ count is 11778. This sensitivity is reported without changing the primary denominator.

## Source and scope notes

- CHARLS age follows the project-approved convention `2011 - ba002_1`.
- CLHLS uses `trueage` from the 2011-2018 longitudinal baseline file.
- KLoSA uses direct `w04A002_age` from 2012 wave w04.
- HRS uses `na019` from the 2012 RAND Fat File; the previously validated 60+ count is 13,867.
- MHAS uses `r3agey`, where r3 is the 2012 wave in H_MHAS_c2.
- These are denominator checks only. Existing mortality event counts were not recomputed.
