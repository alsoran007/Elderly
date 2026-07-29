# KLoSA Wave-4 FI Mapping Audit (2026-07-28)

Raw KLoSA data were read only. No FI, outcome, or raw data file was modified.

- Input: `D:/AI_project/sql/KLOSA/KLoSA 1-9th wave (STATA)/w04_e.dta`
- Rows: 7486
- Age 60+ (w04A002_age): 5289
- Candidate/derived stems: 25
- Not found: 14
- Semantic review required: 2

## Blocking Findings

- Nine mobility stems have no direct population-level performance item in the wave-4 labels; job-demand variables must not be substituted.
- `dyslipe`, `digeste`, `asthmae`, and `slfmem` have no direct wave-4 label match.
- `kidneye` is not assigned to `w04C004m06` because that field is kidney dysfunction disability, not a general kidney disease diagnosis.
- `stroke` code 3 means suspected stroke or transient ischemic attack and requires an explicit inclusion decision.
- `painfr` is activity difficulty from body pain, not a direct chronic-pain frequency measure.

## Output

- Mapping table: `D:/AI_project/project3/results/fi_klosa/klosa_w04_fi_mapping_2026-07-28.csv`
- Log: `D:/AI_project/project3/logs/audit_klosa_fi_wave4_2026-07-28.log`
