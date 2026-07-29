# CLHLS Negative Follow-up Days Audit

## Material Passport
- Type: independent raw-field audit of follow-up-day sign
- Status: VERIFIED after raw SAV reread and hard assertions
- Script: D:/AI_project/project3/code/03_outcome/audit_clhls_negative_followup_verified.R
- Raw input: D:/AI_project/sql/CLHLS/CLHLS_dataset_2008-2018_SPSS/clhls_2011_2018_longitudinal_dataset_released_version1.sav
- Detail output: D:/AI_project/project3/results/outcome_clhls/clhls_negative_followup_audit_2026-07-28.csv
- Log: D:/AI_project/project3/logs/clhls_negative_followup_audit_2026-07-28.log
- Raw SAV modified: no.

## Definition Audited
`days = validated_death_date - individual_baseline_date`; negative means `days < 0`.
Death dates use d14 validated fields for `dth11_14 == 1` and d18 validated fields for `dth11_14 == 0 & dth14_18 == 1`.
The v2 convention imputes missing day as 15 and constrains supplied day values to 1-28; both operations are recorded in the CSV.

## Findings
- Raw records: 9765.
- Death-status records: 4716.
- Constructed validated death dates: 4650.
- Direct negative follow-up records: **45**.
- Negative-day range: -306 to -1 days.
- Negative-day quartiles (P25 / median / P75): -184 / -92 / -27.
- Death source: d14=45; d18=0.
- Negative records with imputed baseline day: 0.
- Negative records with imputed death day: 7.
- Negative records with adjusted death day (v2 1-28 constraint): 3.

## Cross-check
- Prior v2 detail CSV matches independent audit: TRUE.

## Decision Gate
The raw-field audit supports 45 direct negative follow-up records under the stated definition.
D-019's 0-record statement is inconsistent with this raw reread and the v2 detail CSV; keep it unresolved pending Claude/PI review.
This audit does not choose whether to exclude, recode, or reinterpret the records, and it does not edit D-019 or the v2 outcome plan.
