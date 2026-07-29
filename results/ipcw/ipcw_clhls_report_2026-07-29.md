# CLHLS IPCW Sensitivity Report (2026-07-29)

## Background
SAP §12.3 requires sensitivity analysis when missing outcomes > 20%.
CLHLS FI-eligible 60+ (excl prebaseline deaths): **9207 persons**
Complete outcomes (event_4y known): **7095 (77.1%)**
Censored (event_4y=NA): **2112 (22.9%)**

## Censoring Model
Predictors of being observed: fi_full (p=0.000), age (p=0.000), female (p=0.130)
Interpretation: Censoring is NOT completely random — IPCW is necessary.

## Performance Comparison

| Metric | Unweighted (Aim1) | IPCW-weighted | Δ |
|---|---|---|---|
| C-index | 0.8389 | 0.8397 | **+0.0008** |
| O:E | 1.2473 | 1.2547 | +0.0075 |
| Cal slope | 0.9393 | 0.9458 | +0.0065 |
| Brier | 0.17509 | 0.17399 | -0.00110 |
| IPA | 0.2957 | 0.2967 | +0.0010 |

## Conclusion
IPCW-weighted C-index = 0.8397 vs unweighted = 0.8389 (ΔC = +0.0008).
The difference is negligible (ΔC < 0.005). The complete-case Aim1 analysis is robust to informative censoring.

