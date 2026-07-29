# CLHLS 4-Year Mortality Outcome v2

## Material Passport
- Type: reproducible outcome construction and audit artifact
- Status: VERIFIED after a successful R rerun and hard assertions
- Script: D:/AI_project/project3/code/03_outcome/build_clhls_outcome_v2.R
- Output: D:/AI_project/project3/data/analysis/clhls_outcome_2026-07-28.parquet
- Log: D:/AI_project/project3/logs/clhls_outcome_v2_2026-07-28.log

## v1 Deprecated, v2 Adopted
- v1 assumed CLHLS had no death-date variables and used interval-censoring endpoints.
- The validated fields d14vyear/month/day and d18vyear/month/day disprove that premise; v1 interval outputs are retained only as audit history.
- v2 uses validated death dates and a 0-1,461 day window from each participant's baseline interview. Missing validated death days use day 15 per the v2 plan; interview dates are never substituted for death dates.

## Sample Flow
- Raw N = 9,765.
- Death-status N = 4,716; alive at 2018 = 2,884; lost = 2,165.
- Constructed death dates = 4650 / 4716 (98.60%); post-baseline valid dates after 45 pre-baseline records = 4605.
- Pre-baseline deaths excluded from time analysis = 45.
- Baseline age >=60 N = 9749; outcome-known age >=60 N = 7481.

## Outcome Counts
- event_4y = 1 for a death at 0 through 1,461 days inclusive; death after day 1,461 is 0.
- Confirmed alive at 2018 is 0 with time_4y = 1,461; lost or unconstructable death dates remain missing for the fixed-window outcome.
- All-sample events = 3502.
- Age >=60 events = 3502; crude rate = 3502/9749 = 35.92%.

Age strata:
 age_group baseline_n outcome_known_n events_4y rate_known
     60-79       3219            2359       344  0.1458245
     80-89       2640            2010       841  0.4184080
     90-99       2433            1942      1374  0.7075180
      100+       1457            1170       943  0.8059829

Sex strata:
    sex baseline_n outcome_known_n events_4y rate_known
   male       4398            3373      1485  0.4402609
 female       5367            4116      2017  0.4900389

## Death-Date Sources and Missingness
 source deaths valid_year valid_month valid_day constructed_date missing_date
    d14   2879       2813        2879      2763             2813           66
    d18   1837       1837        1837      1837             1837            0
- d14 is used for dth11_14 = 1; d18 is used for dth11_14 = 0 and dth14_18 = 1.
- The released d14vday label says year, but the field is treated as the validated day based on its day-level values and codebook role.

## Loss to Follow-Up
- Lost N = 2165 / 9765 = 22.17%.
- Lost baseline age mean = 84.0; median = 83.0.
- Lost female proportion = 54.92%.
- Lost age strata = 60-79=845; 80-89=607; 90-99=452; 100+=253; NA=8.
- The 22.2% loss rate exceeds the project plan 20% planning value and needs a prespecified loss sensitivity analysis before modeling.

## CLHLS and CHARLS Age Diagnostic
- Plot written: results/outcome_clhls/clhls_charls_age_comparison_v2.png.
- CLHLS age >=60 median = 86.0; P25 = 76.0; P75 = 94.0.

## Literature Benchmark Gate
- Observed CLHLS 60+ crude 4-year mortality = 3502/9749 = 35.92%.
- The local literature-status and evidence files reviewed here do not contain a directly verified published CLHLS estimate using the same 60+ denominator, individual baseline dates, and 1,461-day window. A comparable literature benchmark remains unverified.

## 45 Pre-Baseline Deaths
- Count = 45; these remain dead, but event_4y and time_4y are missing because death precedes baseline.
       id baseline_date death_date days baseline_age female
 12018102    2011-08-22 2011-06-15  -68           74      0
 13050002    2011-06-28 2011-06-15  -13           86      0
 14051305    2011-08-10 2011-07-16  -25           73      0
 21053108    2011-09-15 2011-02-10 -217           93      1
 21062702    2011-08-26 2011-06-15  -72           85      1
 23048602    2011-08-02 2011-01-20 -194           82      1
 32169908    2011-07-27 2011-01-15 -193           94      0
 32357505    2011-08-09 2011-08-05   -4          112      1
 32447612    2012-06-17 2012-06-05  -12          102      1
 33005302    2011-08-26 2011-05-26  -92          100      0
 33174602    2011-07-21 2011-07-03  -18           84      0
 33195202    2011-08-26 2011-03-20 -159           86      1
 37010208    2011-10-22 2011-02-28 -236          101      1
 37215608    2011-10-28 2011-01-15 -286          105      1
 37250608    2011-11-05 2011-09-03  -63           76      1
 37291808    2011-11-03 2011-05-03 -184           94      0
 37292508    2011-10-21 2011-03-04 -231           96      1
 37306108    2011-11-28 2011-06-15 -166           70      0
 37307908    2011-11-10 2011-01-08 -306           91      0
 37400612    2012-07-03 2011-10-28 -249          102      1
 41110305    2011-07-28 2011-07-01  -27          106      1
 41236908    2012-05-23 2011-09-21 -245           99      0
 42150405    2011-07-27 2011-01-28 -180           91      0
 42206408    2012-06-25 2012-06-15  -10          100      0
 42219008    2012-06-27 2012-05-20  -38           79      1
 42237108    2012-06-28 2011-10-09 -263           94      0
 42304912    2012-06-14 2012-05-05  -40           99      1
 42321212    2012-07-05 2012-01-15 -172          102      1
 43089405    2011-08-26 2011-03-10 -169          102      0
 43206308    2012-07-10 2012-02-15 -146          110      1
 43307112    2012-07-12 2012-07-01  -11           93      1
 44066598    2011-08-21 2011-01-19 -214          100      0
 44100602    2011-08-22 2011-08-06  -16           88      0
 45014808    2011-07-13 2011-02-06 -157           94      1
 45215908    2012-06-13 2012-06-12   -1           92      0
 45618205    2011-07-08 2011-04-15  -84           99      0
 45643205    2011-07-08 2011-06-18  -20           74      0
 45644905    2011-07-12 2011-02-17 -145          105      1
 45800512    2012-06-28 2012-06-04  -24          100      1
 46030708    2012-09-13 2012-08-04  -40           90      0
 50065502    2011-07-09 2011-04-06  -94           75      0
 51010408    2011-08-11 2011-06-15  -57           97      1
 51150202    2011-08-11 2011-05-23  -80           81      0
 51164902    2011-08-19 2011-06-15  -65           89      1
 51178902    2011-09-02 2011-05-05 -120           83      1

## Outputs and Constraints
- Parquet: D:/AI_project/project3/data/analysis/clhls_outcome_2026-07-28.parquet
- Negative-detail CSV: D:/AI_project/project3/results/outcome_clhls/clhls_prebaseline_deaths_v2_2026-07-28.csv
- Log: D:/AI_project/project3/logs/clhls_outcome_v2_2026-07-28.log
- Raw SAV was not modified.
- Downstream FI modeling remains outside this task and requires review of outcome-known and loss handling.

## Session
R version 4.4.1 (2024-06-14 ucrt)
Platform: x86_64-w64-mingw32/x64
Running under: Windows 11 x64 (build 26200)

Matrix products: default


locale:
[1] LC_COLLATE=Chinese (Simplified)_China.utf8 
[2] LC_CTYPE=Chinese (Simplified)_China.utf8   
[3] LC_MONETARY=Chinese (Simplified)_China.utf8
[4] LC_NUMERIC=C                               
[5] LC_TIME=Chinese (Simplified)_China.utf8    

time zone: Asia/Shanghai
tzcode source: internal

attached base packages:
[1] stats     graphics  grDevices utils     datasets  methods   base     

loaded via a namespace (and not attached):
 [1] bit_4.6.0          gtable_0.3.6       dplyr_1.2.1        compiler_4.4.1    
 [5] tidyselect_1.2.1   dichromat_2.0-0.1  assertthat_0.2.1   arrow_23.0.1.2    
 [9] systemfonts_1.3.1  scales_1.4.0       textshaping_1.0.0  ggplot2_4.0.1     
[13] readr_2.1.5        R6_2.6.1           labeling_0.4.3     generics_0.1.3    
[17] forcats_1.0.0      tibble_3.3.1       pillar_1.11.1      RColorBrewer_1.1-3
[21] tzdb_0.4.0         rlang_1.1.7        S7_0.2.1           bit64_4.6.0-1     
[25] cli_3.6.5          withr_3.0.2        magrittr_2.0.3     grid_4.4.1        
[29] haven_2.5.4        hms_1.1.3          lifecycle_1.0.5    vctrs_0.7.3       
[33] glue_1.8.0         farver_2.1.2       ragg_1.3.3         purrr_1.0.4       
[37] tools_4.4.1        pkgconfig_2.0.3   
