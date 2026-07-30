# SA-3 Education-Adjusted Sensitivity Analysis Report (2026-07-30)

## Status
**POST HOC sensitivity analysis** (SAP amendment A-001, 2026-07-30).
Conducted after outcome unblinding (2026-07-29). Does NOT change H1–H6 verdicts.

## Models
- **Main model (B)**: `event ~ fi_full + age + female + factor(period)` (SAP-registered)
- **SA-3 model**: `event ~ fi_full + age + female + factor(period) + edu_isced`

## Education encoding (frozen in A-001)
ISCED 3-level covariate; complete-case only.
- CHARLS `bd001`: 1–5 → 1; 6–7 → 2; 8–11 → 3
- CLHLS `f1` (years): 0–9 → 1; 10–12 → 2; ≥13 → 3; 88/99 = NA

## Sample sizes
- CHARLS main model pp rows: 14551 (7546 persons, 771 events)
- CHARLS SA-3 pp rows: 14529 (7534 persons, 770 events) — 12 persons excluded (missing edu)
- CLHLS main validation: 7095 persons, 3282 events (46.3%)
- CLHLS SA-3 validation: 7069 persons, 3268 events — 26 persons excluded (missing edu)

## Internal discrimination (CHARLS)
- Main model C-index (edu-complete sample): 0.7706
- SA-3  model C-index (edu-complete sample): 0.7725
- ΔC (SA-3 − main): +0.0020
- edu_isced coefficient: -0.4475 (p=0.0031)

## CLHLS external validation

| Model | N | Events | C-index [95% CI] | O:E | Cal slope | IPA |
|---|---:|---:|---|---:|---:|---:|
| Main (full CC, Aim 1) | 7095 | 3282 | 0.8389 [0.8302–0.8472] | 1.2457 | 0.9382 | 0.2962 |
| Main (edu-complete)    | 7069 | 3268 | 0.8389 [0.8289–0.8477] | 1.2469 | 0.9379 | 0.2958 |
| SA-3 (+edu_isced)     | 7069 | 3268 | 0.8380 [0.8281–0.8467] | 1.2402 | 0.9315 | 0.2958 |

## SA-3 vs Main model delta (on edu-complete sample)
- ΔC-index : -0.0009
- Δ O:E    : -0.0067
- Δ slope  : -0.0064
- Δ IPA    : +0.0001

## Robustness verdict
**Pre-specified criterion** (A-001): |ΔC| < 0.02 AND |ΔO:E| < 0.05 AND |Δslope| < 0.05
**Observed**: |ΔC| = 0.0009 | |ΔO:E| = 0.0067 | |Δslope| = 0.0064
**Verdict: ROBUST — main model conclusions hold without education adjustment**

## Files
- Performance CSV: `results/sa3/sa3_education_performance_2026-07-30.csv`
- Calibration plot: `results/sa3/figures/sa3_calibration_clhls_2026-07-30.{tiff,pdf}`

## For manuscript
Report SA-3 in Methods §8.5 (sensitivity analyses) and cite the verdict in
Results (one paragraph) and Limitations (replace the refuted 'education unavailable' claim).

*Generated: 2026-07-31 01:35:09*
