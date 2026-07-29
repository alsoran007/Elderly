# HRS Fixed 41-item FI (2026-07-29)

Exactly 41 unique deficit columns; at least 33 valid items are required.

- Input: D:/AI_project/sql/HRS Products/RAND HRS Products(原始)/2012 RAND HRS Fat File/h12f3a.dta
- Output: D:/AI_project/project3/data/analysis/hrs_fi_2012_2026-07-29.parquet
- Rows: 20554
- Age 60+: 13867
- FI eligible all: 14007
- FI eligible age 60+: 10707
- Threshold: 33/41
- Substitutes: nc017, nc145, nc148, nc150, nc271
- Corrected sources: ng002 jogging, ng009 arms, nc087 incontinence, nc096/nc097 vision, nd101 memory, nc139+nc141+nc142 BMI.

## Validation

- FI checked within [0,1].
- Source-derived item columns are unique and exactly 41.
- High-correlation pairs: 0
- Mapping: D:/AI_project/project3/results/fi_hrs_v2/tables/hrs_fi_v2_mapping_2026-07-29.csv
- Log: D:/AI_project/project3/logs/build_fi_hrs_v2_2026-07-29.log
