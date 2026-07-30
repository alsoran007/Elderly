# Supplementary Table S1. Final 41-item frailty index specification

All deficit definitions were extracted programmatically from the Gateway to Global Aging harmonised CHARLS Version D.2 Stata script (`bbxleyec.do`, 2025-09 release) using `code/02_harmonize/extract_gateway_fi_defs.py`. The `Gateway .do line` column gives the line number of the defining statement, enabling item-by-item audit.

**Item count**: 44 candidates screened; **41** retained in the final locked specification (decision D-020, 2026-07-28); 3 excluded (see Note column).

**Domain distribution of the final 41 items**

| Domain | Items |
| --- | ---: |
| ADL | 6 |
| Chronic conditions | 13 |
| Cognitive proxy | 1 |
| General health | 4 |
| IADL | 5 |
| Mobility | 9 |
| Sensory | 3 |

**Full item specification**

| Stem | Domain | Concept | Gateway .do line | Raw variable(s) | In final 41-item FI | Note |
| --- | --- | --- | --- | --- | --- | --- |
| arthre | Chronic conditions | arthritis | 7517 | da007_13_ | Yes |  |
| asthmae | Chronic conditions | asthma | 7597 | da007_14_ | Yes |  |
| cancre | Chronic conditions | cancer | 7437 | da007_4_ | Yes |  |
| diabe | Chronic conditions | diabetes | 7421 | da007_3_ | Yes |  |
| digeste | Chronic conditions | digestive disease | 7581 | da007_10_ | Yes |  |
| dyslipe | Chronic conditions | dyslipidemia | 7533 | da007_2_ | Yes |  |
| hearte | Chronic conditions | heart disease | 7469 | da007_7_ | Yes |  |
| hibpe | Chronic conditions | hypertension | 7405 | da007_1_ | Yes |  |
| kidneye | Chronic conditions | kidney disease | 7565 | da007_9_ | Yes |  |
| livere | Chronic conditions | liver disease | 7549 | da007_6_ | Yes |  |
| lunge | Chronic conditions | chronic lung disease | 7453 | da007_5_ | Yes |  |
| psyche | Chronic conditions | psychiatric problem | 7501 | da007_11_ | Yes |  |
| stroke | Chronic conditions | stroke | 7485 | da007_8_ | Yes |  |
| batha | ADL | bathing | 6496 | db001;db004;db005;db006;db007;db008;db009;db011 | Yes |  |
| beda | ADL | bed transfer | 6530 | db001;db004;db005;db006;db007;db008;db009;db013 | Yes |  |
| dressa | ADL | dressing | 6479 | db001;db004;db005;db006;db007;db008;db009;db010 | Yes |  |
| eata | ADL | eating | 6513 | db001;db004;db005;db006;db007;db008;db009;db012 | Yes |  |
| toilta | ADL | toileting | 6547 | db001;db004;db005;db006;db007;db008;db009;db014 | Yes |  |
| urina | ADL | continence | 6564 | db001;db004;db005;db006;db007;db008;db009;db015 | Yes |  |
| housewka | IADL | housework | 6753 | db016 | Yes |  |
| mealsa | IADL | preparing meals | 6737 | db017 | Yes |  |
| medsa | IADL | taking medication | 6705 | db020 | Yes |  |
| moneya | IADL | managing money | 6689 | db019 | Yes |  |
| shopa | IADL | shopping | 6721 | db018 | Yes |  |
| armsa | Mobility | raise arms | 6459 | db007 | Yes |  |
| chaira | Mobility | chair rise | 6373 | db004 | Yes |  |
| climsa | Mobility | climb flights of stairs | 6390 | db005 | Yes |  |
| dimea | Mobility | pick up coin | 6442 | db009 | Yes |  |
| joga | Mobility | jog 1km | 6322 | db001 | Yes |  |
| lifta | Mobility | lift 5kg | 6425 | db008 | Yes |  |
| stoopa | Mobility | stoop/kneel/crouch | 6408 | db006 | Yes |  |
| walk100a | Mobility | walk 100m | 6356 | db001;db002;db003 | Yes |  |
| walk1kma | Mobility | walk 1km | 6339 | db001;db002 | Yes |  |
| dsight | Sensory | distance vision | 8719 | da032;da033 | Yes |  |
| hearing | Sensory | hearing | 8764 | da039 | Yes |  |
| nsight | Sensory | near vision | 8733 | da032;da034 | Yes |  |
| fall | General health | fall history | 8794 | da023 | Yes |  |
| hearaid | General health | wears hearing aid | 8777 | da038 | No | Excluded: positive rate 0.56% (< 1% Searle criterion); cross-cohort non-comparability |
| hlthlm_c | General health | health limits activity | 8960 | fa001;fa002;fa003;fa005;fc013;fd030;fh004 | No | Excluded: missing rate 35.1% (> 30% threshold) |
| mbmi | General health | measured BMI | 50485 |  | Yes |  |
| mbmicata | General health | BMI category | 50503 |  | No | Excluded: construct redundant with continuous mbmi |
| painfr | General health | frequent pain | 8924 | da041 | Yes |  |
| shlt | General health | self-rated health | 6244 | da001;da002;da079;da080 | Yes |  |
| slfmem | Cognitive proxy | self-rated memory | 20727 | db032;dc004 | Yes |  |

Abbreviations: ADL, activities of daily living; IADL, instrumental activities of daily living; FI, frailty index; BMI, body mass index.

---

# Supplementary Table S2. Cross-cohort FI item coverage and positive rates

Cell values give the **positive rate** (proportion coded as a deficit) among participants aged >= 60 years in each cohort. Blank cells indicate the item was unavailable, or present as an all-missing column, in that cohort's harmonised file.

**FI_core** (19 items) = stems available with a valid positive rate in all six cohorts under strict column-name matching; used in sensitivity analysis SA-1 and in the H6 feature-importance analysis. **FI_core_5of6** (32 items) = stems available in at least five cohorts.

Coverage is constrained mainly by MHAS (27 of 41 canonical stems) and by KLoSA, whose mobility items use non-canonical column names. Two items are present but all-missing by design and were verified as intentional (decision D-028 addendum): `joga` in SHARE (no `r4joga` field in the Gateway wave-4 file) and `dimea` in CLHLS (no coin-pickup measurement at the 2011/12 baseline).

| Stem | CHARLS | CLHLS | KLoSA | HRS | SHARE | MHAS | Cohorts with data | FI_core (6/6) | FI_core_5of6 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| arthre | 0.367 | 0.144 | 0.025 | 0.672 | 0.323 | 0.311 | 6 | Yes | Yes |
| batha | 0.111 | 0.240 | 0.041 | 0.186 | 0.080 | 0.067 | 6 | Yes | Yes |
| beda | 0.091 | 0.114 | 0.030 | 0.150 | 0.051 | 0.102 | 6 | Yes | Yes |
| cancre | 0.010 | 0.009 | 0.014 | 0.186 | 0.089 | 0.036 | 6 | Yes | Yes |
| diabe | 0.071 | 0.043 | 0.025 | 0.267 | 0.158 | 0.264 | 6 | Yes | Yes |
| dressa | 0.083 | 0.131 | 0.028 | 0.183 | 0.102 | 0.120 | 6 | Yes | Yes |
| eata | 0.053 | 0.086 | 0.026 | 0.096 | 0.025 | 0.044 | 6 | Yes | Yes |
| fall | 0.190 | 0.380 | 0.025 | 0.368 | 0.062 | 0.432 | 6 | Yes | Yes |
| hearing | 0.682 | 0.475 | 0.390 | 0.450 | 0.455 | 0.640 | 6 | Yes | Yes |
| hibpe | 0.321 | 0.295 | 0.067 | 0.682 | 0.490 | 0.595 | 6 | Yes | Yes |
| mbmi | 0.146 | 0.298 | 0.065 | 0.334 | 0.229 | 0.341 | 6 | Yes | Yes |
| mealsa | 0.150 | 0.371 | 0.082 | 0.081 | 0.056 | 0.064 | 6 | Yes | Yes |
| medsa | 0.103 | 0.351 | 0.031 | 0.055 | 0.028 | 0.032 | 6 | Yes | Yes |
| moneya | 0.185 | 0.239 | 0.058 | 0.072 | 0.061 | 0.033 | 6 | Yes | Yes |
| painfr | 0.346 | 0.621 | 0.444 | 0.360 | 0.591 | 0.395 | 6 | Yes | Yes |
| shlt | 0.750 | 0.408 | 0.735 | 0.487 | 0.587 | 0.686 | 6 | Yes | Yes |
| shopa | 0.149 | 0.370 | 0.056 | 0.099 | 0.090 | 0.123 | 6 | Yes | Yes |
| stroke | 0.037 | 0.086 | 0.012 | 0.095 | 0.069 | 0.044 | 6 | Yes | Yes |
| toilta | 0.180 | 0.133 | 0.026 | 0.148 | 0.034 | 0.079 | 6 | Yes | Yes |
| armsa | 0.144 | 0.061 | — | 0.196 | 0.118 | 0.159 | 5 |  | Yes |
| chaira | 0.347 | 0.310 | — | 0.427 | 0.233 | 0.340 | 5 |  | Yes |
| climsa | 0.515 | 0.520 | — | 0.434 | 0.348 | 0.499 | 5 |  | Yes |
| dsight | 0.723 | 0.244 | 0.512 | 0.415 | 0.416 | — | 5 |  | Yes |
| hearte | 0.160 | 0.127 | 0.017 | 0.301 | 0.201 | — | 5 |  | Yes |
| housewka | 0.155 | 0.562 | 0.060 | 0.271 | 0.153 | — | 5 |  | Yes |
| lifta | 0.195 | 0.453 | — | 0.303 | 0.266 | 0.294 | 5 |  | Yes |
| lunge | 0.141 | 0.122 | 0.007 | 0.118 | 0.090 | — | 5 |  | Yes |
| nsight | 0.719 | 0.125 | 0.508 | 0.456 | 0.483 | — | 5 |  | Yes |
| psyche | 0.016 | 0.150 | 0.009 | 0.185 | 0.100 | — | 5 |  | Yes |
| slfmem | 0.794 | 0.034 | — | 0.519 | 0.528 | 0.654 | 5 |  | Yes |
| stoopa | 0.384 | 0.128 | — | 0.515 | 0.367 | 0.473 | 5 |  | Yes |
| urina | 0.070 | 0.066 | 0.021 | 0.283 | 0.079 | — | 5 |  | Yes |
| dimea | 0.067 | — | — | 0.095 | 0.055 | 0.093 | 4 |  |  |
| joga | 0.659 | 0.531 | — | 0.683 | — | 0.644 | 4 |  |  |
| livere | 0.040 | 0.006 | 0.003 | — | 0.080 | — | 4 |  |  |
| walk100a | 0.028 | 0.257 | — | 0.535 | 0.152 | — | 4 |  |  |
| walk1kma | 0.244 | 0.477 | — | 0.371 | 0.032 | — | 4 |  |  |
| asthmae | 0.055 | 0.011 | — | — | 0.387 | — | 3 |  |  |
| dyslipe | 0.105 | 0.044 | — | — | 0.303 | — | 3 |  |  |
| kidneye | 0.066 | 0.009 | — | 0.121 | — | — | 3 |  |  |
| digeste | 0.220 | 0.055 | — | — | — | — | 2 |  |  |
| activity_health | — | — | 0.488 | — | — | — | 1 |  |  |
| concentration | — | — | 0.193 | — | — | — | 1 |  |  |
| depressed_yr | — | — | — | 0.133 | — | — | 1 |  |  |
| dizzy | — | — | — | 0.143 | — | — | 1 |  |  |
| ever_depression | — | — | — | 0.211 | — | — | 1 |  |  |
| fatigue | — | — | — | 0.205 | — | — | 1 |  |  |
| gloom_2wk | — | — | 0.069 | — | — | — | 1 |  |  |
| grooming | — | — | 0.031 | — | — | — | 1 |  |  |
| hearing_activity | — | — | 0.055 | — | — | — | 1 |  |  |
| laundry | — | — | 0.086 | — | — | — | 1 |  |  |
| near_out | — | — | 0.066 | — | — | — | 1 |  |  |
| other_disease | — | — | 0.079 | — | — | — | 1 |  |  |
| phone | — | — | 0.039 | — | — | — | 1 |  |  |
| restless_sleep | — | — | 0.208 | — | — | — | 1 |  |  |
| transport_out | — | — | 0.074 | — | — | — | 1 |  |  |
| vision_activity | — | — | 0.053 | — | — | — | 1 |  |  |
| wash_groom | — | — | 0.029 | — | — | — | 1 |  |  |
| weight_change | — | — | 0.194 | — | — | — | 1 |  |  |

**Measurement-equivalence caution.** Two chronic-condition items show outlying cross-cohort rates that likely reflect differential diagnosis or ascertainment rather than true prevalence: `hibpe` (KLoSA 0.067 vs HRS 0.682) and `arthre` (KLoSA 0.025 vs HRS 0.672). Both are retained in FI_full but interpreted with caution; this heterogeneity is one mechanism underlying the H3 null result.

---

# Supplementary Table S3. Cross-cohort concordance of FI item importance (H6)

Pairwise Spearman rank correlations between cohort-specific orderings of feature importance. Importance was quantified as |beta_standardised| from a logistic model fitted separately in each cohort on FI_core (19 items) plus age; for a main-effects generalised linear model this is the exact linear-SHAP importance.

**Summary statistics**

| Statistic | Value |
| --- | --- |
| Number of cohort pairs | 15 |
| Median rho | 0.4105 |
| Minimum rho | 0.0962 (KLoSA-HRS) |
| Maximum rho | 0.6677 (CHARLS-SHARE) |
| Interquartile range | 0.3270-0.4835 |
| Pre-registered H6 threshold | median rho >= 0.70 |
| H6 concordance criterion | Not met |

**Full 6 x 6 matrix** (lower triangle; diagonal = 1 by construction)

| Cohort | CHARLS | CLHLS | KLoSA | HRS | SHARE | MHAS |
| --- | --- | --- | --- | --- | --- | --- |
| CHARLS | 1.0000 |  |  |  |  |  |
| CLHLS | 0.4571 | 1.0000 |  |  |  |  |
| KLoSA | 0.0992 | 0.3549 | 1.0000 |  |  |  |
| HRS | 0.5098 | 0.4391 | 0.0962 | 1.0000 |  |  |
| SHARE | 0.6677 | 0.4406 | 0.3338 | 0.6662 | 1.0000 |  |
| MHAS | 0.2887 | 0.4105 | 0.3203 | 0.4105 | 0.6617 | 1.0000 |

H6 specified two criteria: (i) age ranks in the top three in every cohort, and (ii) median pairwise Spearman rho >= 0.70. Criterion (i) was met — age ranked **first** in all six cohorts. Criterion (ii) was not met (observed median 0.41), so **H6 is partially supported**.

KLoSA showed the weakest concordance with other cohorts (rho = 0.10 with HRS; 0.10 with CHARLS), attributable to floor effects in its ADL items (positive rates 2-7%) among a relatively young, community-dwelling sample (median age ~71 years). The Western and Latin American cohorts were mutually more concordant (SHARE-HRS 0.67; SHARE-MHAS 0.66).

*Scope caveat*: |beta_standardised| captures main-effect contributions only and is insensitive to non-linearity and interactions. These results are exploratory; SHAP values from non-linear learners may reveal additional structure.

