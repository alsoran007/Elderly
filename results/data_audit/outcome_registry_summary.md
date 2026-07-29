# Project3 Outcome Registry

This registry is a Phase 1 data-layer artifact. The candidate records are exit/EOL/longitudinal mortality candidates only and are not the final analysis cohort or final 5-year outcome.

- Candidate records exported: 36630
- Cohorts represented in candidate records: CHARLS, CLHLS, ELSA, KLoSA, MHAS, SHARE
- Candidate records with day-level dates: 7412
- Candidate records with month-level dates: 26611
- Candidate records with year-level dates: 1474
- Candidate records with missing/invalid dates: 1133

## Required next linkage gate

1. Link each candidate record to the appropriate baseline person-level file using the confirmed person ID.
2. Obtain last-known-alive/interview dates and administrative censoring dates for non-events.
3. Resolve CHARLS 2015/2018 mortality status, confirm CLHLS interval/status coding against the codebook, resolve KLoSA w01/w02 mortality coverage, and confirm HRS mortality fields.
4. Pre-specify handling of month/year-only death dates; do not silently impute a day in the primary outcome.
5. Only after this gate construct the analysis-ready 5-year outcome and calculate event counts.

## Output files

- `cohort_registry.csv`: planned role, baseline, identifier status, and current data gate.
- `outcome_crosswalk.csv`: source-specific ID and death-date fields.
- `outcome_candidate_records.csv`: derived exit/EOL mortality candidates with date precision.
- `outcome_candidate_summary.csv`: source-level counts and date completeness.
