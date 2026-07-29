# Six-Cohort Readiness Registry

## Material Passport
- Type: cross-cohort denominator and four-year event-readiness registry
- Status: VERIFIED_CURRENT for all six cohorts; three current event counts were recomputed from raw mortality sources
- Script: D:/AI_project/project3/code/03_describe/build_cohort_readiness_registry.R
- Output: D:/AI_project/project3/results/cohort_readiness/six_cohort_readiness_registry_2026-07-28.csv
- Raw data modified: no.

## Current Denominators
The registry applies D-021 to SHARE (wave-4 visits in 2011 only) and D-022 to MHAS (direct or derived age). These supersede the earlier denominator-audit values for those cohorts.

| Cohort | Baseline | Raw N | Current age 60+ N | Four-year window | Verified current events | Prior reported events | Status |
|---|---:|---:|---:|---|---:|---:|---|
| CHARLS | 2011 | 17,705 | 7,669 | 2011-2015 | 785 | 785 | VERIFIED |
| CLHLS | 2011/12 | 9,765 | 9,749 | <=1461 days | 3,502 | 3,502 | VERIFIED |
| KLoSA | 2012 | 7,486 | 5,289 | 2012-2016 | 585 | 918 | VERIFIED |
| SHARE | 2011 only | 54,550 | 36,604 | 2011-2015 | 3,689 | 6,287 | VERIFIED |
| MHAS | 2012 | 15,716 age-valid | 10,174 | 2012-2016 | 1,404 | 1,735 | VERIFIED |
| HRS | 2012 | 20,554 | 13,867 | 2012-2016 | 2,352 | 2,352 | VERIFIED |

## Interpretation
All six cohorts now have current verified event counts. The KLoSA historical 918 was not a valid current denominator-restricted count: it summed EXIT records without restricting to wave-4 baseline IDs and age 60+.
SHARE and MHAS use D-021 and D-022 respectively. Valid death year is sufficient for the frozen primary event count when month is missing; exact-date counts are reported separately in the audit artifact.
The CLHLS D-019 correction is now recorded separately: 45 pre-baseline deaths are marked `prebaseline_death=TRUE` and excluded from the time axis; no outcome definition was changed by this registry.

## Remaining Gate
The event-count gate is complete. Preserve the exact-date sensitivity columns and the 44 KLoSA year-only records as documented when selecting the final modeling time scale.
