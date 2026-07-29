# CLHLS Step 1-4 Outcome Probe (2011-2018)

## Scope
This report covers extraction, assertion, visit-date measurement, baseline construction, and interval construction only. Step 5 event_5y/event_8y construction, FI/IC construction, and final analysis outputs were not run.

## Step 1 Assertions
- Input: clhls_2011_2018_longitudinal_dataset_released_version1.sav
- N = 9,765; selected fields = 14; raw source was read with haven::read_sav().
- dth11_14 expected counts: -9 lost = 820; 0 surviving = 6,066; 1 died = 2,879; missing = 0.
- dth14_18 expected counts: -9 lost = 1,345; 0 surviving = 2,884; 1 died = 1,837; missing = 3,699.
- Baseline yearin expected counts: 2011 = 7,328; 2012 = 2,437.
- Cross-check: 2,884 + 1,837 + 1,345 = 6,066: PASS.

## Step 2 Visit-Date Measurements
- Baseline: 2011-01-11 to 2012-09-26 (n=9,765); median = 2011-08-20.
- 2014 visit: 2014-01-23 to 2014-11-30 (n=6,066); median = 2014-05-27; span = 311 days.
- 2018 visit: 2017-10-08 to 2019-07-31 (n=2,903); median = 2018-07-24; span = 661 days.
- The 2018 visit dates empirically span more than the calendar year 2018; the observed dates, not the wave label, were used.
- Monthly counts are exported in visit_monthly_counts.png.

## Step 3 Baseline
- baseline_date = make_date(yearin, monthin, dayin); missing dates = 0.
- trueage: min 47; P25 76; median 86; P75 94; max 114; mean 85.8; SD 11.4.
- Age groups: <60=16; 60-69=722; 70-79=2497; 80-89=2640; 90-99=2433; 100+=1457.
- Age >=80: 6530 (66.87%); >=90: 3890 (39.84%); >=100: 1457 (14.92%).
- Sex a1: male = 4398; female = 5367; missing/unexpected = 0.
- Baseline age plot is exported in baseline_age_by_sex.png.
- CHARLS comparison plot was not produced because data/analysis/charls_outcome_2026-07-27.parquet is unavailable.

## Step 4 Death Intervals
- Interval 1 deaths: 2879; [baseline_date, observed 2014 visit-period maximum = 2014-11-30].
- Interval 2 deaths: 1837; [individual 2014 visit date, observed 2018 visit-period maximum = 2019-07-31]; fallback to 2014 minimum date when individual date missing = 0.
- Death intervals total: 4716.
- Intervals crossing 1,826 days: 1837 / 4716 (38.95%); interval 1 = 0; interval 2 = 1837.
- Among crossers, interval width days: min 1707; median 1893; max 2015; distance from interval L to day 1,826: min 606; median 819; max 1182.
- Interval width plot is exported in interval_width_days.png.

## Status Counts
- dth11_14 surviving = 6066; dead = 2879; lost = 820.
- dth14_18 among dth11_14 survivors: surviving = 2884; dead = 1837; lost = 1345.

## Constraints and Next Gate
- No 5-year or 8-year event variables were created in this Step 1-4 run.
- The observed 2018 date range and the interval-crossing count must be reviewed before selecting the subsequent outcome strategy.
- The raw SAV file remains unmodified.
