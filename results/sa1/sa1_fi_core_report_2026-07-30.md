# SA-1: FI_core (19-item) Sensitivity Analysis Report (2026-07-30)

## Purpose
Assess robustness of discrimination and calibration results when FI is restricted
to the 19 items available in ALL SIX cohorts under strict column-name matching
(FI_core, D-028). Computability threshold = ceiling(0.8 × 19) = 16 items.
Pre-specified in SAP §12.3 SA-1.

## FI_core: 19 items
arthre, batha, beda, cancre, diabe, dressa, eata, fall, hearing, hibpe, mbmi, mealsa, medsa, moneya, painfr, shlt, shopa, stroke, toilta

**Warning items** (D-028): `hibpe` KLoSA=0.067 vs HRS=0.682; `arthre` KLoSA=0.025 vs HRS=0.672. These likely reflect differential diagnosis ascertainment, not true prevalence differences.

## Results

### SA-1a: Aim 1 equivalent (CHARLS FI_core -> CLHLS)
CHARLS development: 7496 persons | 14454 pp rows | 766 events
CLHLS validation: 7035 persons | 3233 events
fi_core coefficient: 2.7882 (p=0.0000)
CHARLS internal C: 0.7668  (FI_full main: 0.7705)
CLHLS external C:  0.8346 [0.8260-0.8430]
vs FI_full (main): 0.8389 | delta: -0.0044

### SA-1b: Aim 3 equivalent (Asian pool FI_core -> HRS/SHARE/MHAS)
Asian pool: N=19705 | events=4487 | rate=22.8%

| Cohort | Level | C-index | O:E | IPA | vs FI_full delta C |
|---|---|---|---|---|---|
| HRS | L0 | 0.7777 | 0.979 | 0.2040 | -0.0124 |
| HRS | L1 | 0.7777 | 1.000 | 0.2044 | — |
| SHARE | L0 | 0.7725 | 0.633 | 0.0555 | -0.0055 |
| SHARE | L1 | 0.7725 | 1.000 | 0.1149 | — |
| MHAS | L0 | 0.7243 | 0.819 | 0.0584 | -0.0000 |
| MHAS | L1 | 0.7243 | 1.000 | 0.0753 | — |

## Robustness Assessment
SA-1a CLHLS delta C vs main (FI_full): -0.0044
FI_core produces substantially similar discrimination to FI_full across all cohorts,
supporting the robustness of conclusions to item availability constraints.

*Generated: 2026-07-31 15:17:39*
