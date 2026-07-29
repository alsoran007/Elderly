# KLoSA Fixed 41-item FI (2026-07-29)

KLoSA wave 4 uses exactly 41 unique deficit columns and requires at least 33 valid items for FI.
- Input: D:/AI_project/sql/KLOSA/KLoSA 1-9th wave (STATA)/w04_e.dta
- Output: D:/AI_project/project3/data/analysis/klosa_fi_2012_2026-07-29.parquet
- Rows: 7486
- Age 60+: 5289
- FI eligible all: 7486
- FI eligible age 60+: 5289
- Threshold: 33/41 valid items
- FI range: 0 to 0.8056

## Substitute-variable rules

- Four condition/general slots use w04C103, w04C106, w04C141, and w04C148.
- Nine function slots use w04C202, w04C208, w04C211, w04C212, w04C213, w04C216, w04C005, w04C081, and w04C084.
- Help-needed items map 1=no help, 3=some help, 5=full help to 0, 0.5, 1.
- Stroke code 3 (suspected stroke/TIA) is not counted in primary FI and needs sensitivity review.

## Validation

- FI values are checked to be within [0,1].
- Source-derived item columns are unique and exactly 41.
- High-correlation pairs (absolute r > 0.85): 24
- Mapping: D:/AI_project/project3/results/fi_klosa_v2/tables/klosa_fi_v2_mapping_2026-07-29.csv
- Log: D:/AI_project/project3/logs/build_fi_klosa_v2_2026-07-29.log
