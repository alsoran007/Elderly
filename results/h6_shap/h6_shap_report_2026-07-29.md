# H6 SHAP Report (2026-07-29)

## Method
Cohort-specific logistic regression on FI_core 19 items + age (20 features total).
Importance = |β_standardised| (linear SHAP for main-effects GLM, exact for this model class).

## FI_core 19 items
arthre, batha, beda, cancre, diabe, dressa, eata, fall, hearing, hibpe, mbmi, mealsa, medsa, moneya, painfr, shlt, shopa, stroke, toilta

## Cohort sizes

| Cohort | N | Events | Rate |
|---|---:|---:|---:|
| CHARLS | 7551 | 771 | 10.2% |
| CLHLS | 7095 | 3282 | 46.3% |
| KLoSA | 5288 | 510 | 9.6% |
| HRS | 10707 | 2138 | 20.0% |
| SHARE | 36352 | 3165 | 8.7% |
| MHAS | 9081 | 924 | 10.2% |

## Top-3 features per cohort

| Cohort | #1 | #2 | #3 | Age rank |
|---|---|---|---|---:|
| CHARLS | age | shlt | arthre | 1 |
| CLHLS | age | mealsa | mbmi | 1 |
| KLoSA | age | mealsa | cancre | 1 |
| HRS | age | shlt | batha | 1 |
| SHARE | age | shlt | cancre | 1 |
| MHAS | age | diabe | shlt | 1 |

## Cross-cohort Spearman rank correlations

| Pair | Spearman |
|---|---:|
| CHARLS<->CLHLS | 0.4571 |
| CHARLS<->KLoSA | 0.0992 |
| CHARLS<->HRS | 0.5098 |
| CHARLS<->SHARE | 0.6677 |
| CHARLS<->MHAS | 0.2887 |
| CLHLS<->KLoSA | 0.3549 |
| CLHLS<->HRS | 0.4391 |
| CLHLS<->SHARE | 0.4406 |
| CLHLS<->MHAS | 0.4105 |
| KLoSA<->HRS | 0.0962 |
| KLoSA<->SHARE | 0.3338 |
| KLoSA<->MHAS | 0.3203 |
| HRS<->SHARE | 0.6662 |
| HRS<->MHAS | 0.4105 |
| SHARE<->MHAS | 0.6617 |

**Median Spearman: 0.4105** | Min: 0.0962 | Max: 0.6677

## H6 Verdict

**PARTIAL**

- Median Spearman = 0.4105 (< threshold 0.7)
- Age in top 3: 6 / 6 cohorts

