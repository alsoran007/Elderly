# Aim 2 LOCO Report (2026-07-29)

## Cohort summary
| Cohort | N | Events | Event rate |
|---|---:|---:|---:|
| CHARLS | 7551 | 771 | 10.2% |
| CLHLS  | 7095 | 3282 | 46.3% |
| KLoSA  | 5288 | 510 | 9.6% |

## Model specification
Binary logistic regression: `event ~ fi_full + age` (no female — KLoSA parquet lacks sex variable)

## LOCO performance

| Round | Train | Test | C-index | O:E | Cal slope | Brier | IPA |
|---|---|---|---:|---:|---:|---:|---:|
| A raw    | CLHLS+KLoSA | CHARLS | 0.7588 | 0.669 | 0.851 | 0.0862 | 0.0597 |
| A L1     | CLHLS+KLoSA | CHARLS | 0.7588 | 1.000 | 0.851 | 0.0813 | 0.1136 |
| B raw    | CHARLS+KLoSA | CLHLS | 0.8346 | 1.266 | 0.935 | 0.1775 | 0.2859 |
| B L1     | CHARLS+KLoSA | CLHLS | 0.8346 | 1.000 | 0.935 | 0.1649 | 0.3368 |
| C raw    | CHARLS+CLHLS | KLoSA | 0.8011 | 0.758 | 1.075 | 0.0742 | 0.1482 |
| C L1     | CHARLS+CLHLS | KLoSA | 0.8011 | 1.000 | 1.075 | 0.0731 | 0.1608 |

## CHARLS-only baselines

| Model | Test | C-index | O:E | Cal slope |
|---|---|---:|---:|---:|
| CHARLS-only raw | CLHLS | 0.8334 | 1.276 | 0.990 |
| CHARLS-only L1  | CLHLS | 0.8334 | 1.000 | 0.990 |
| CHARLS-only raw | KLoSA | 0.8023 | 0.971 | 1.179 |
| CHARLS-only L1  | KLoSA | 0.8023 | 1.000 | 1.179 |

## H3 verdict (downsampling control)

- **Round B** (adding KLoSA to CHARLS, test=CLHLS): ΔC full=0.0012, downsampled=0.0013 → **SUPPORTED (downsampled ΔC > 0)**
- **Round C** (adding CLHLS to CHARLS, test=KLoSA): ΔC full=-0.0012, downsampled=-0.0013 → **NOT SUPPORTED**

## Education note
Female was excluded from all LOCO models for cross-cohort consistency (KLoSA FI parquet lacks sex variable).
This differs from Aim 1 (which used fi_full + age + female on CHARLS person-period).

