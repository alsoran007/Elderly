# CHARLS Bootstrap Optimism Correction Report (2026-07-30)

## Method
Harrell's internal-bootstrap optimism correction (B = 200 replications).
Resampling at the **person** level (all person-periods for a sampled person are
included) to preserve within-person correlation across risk periods.
Each replication: fit Model B on bootstrap sample → C_boot_in;
apply to original data → C_boot_orig; optimism = C_boot_in − C_boot_orig.
Corrected C = Apparent C − mean(optimism).

## Results
- Development set: 7546 persons, 14551 person-periods, 771 events (5.3%)
- Valid replications: 200 / 200
- **Apparent C-index:   0.7705**
- Mean optimism:        0.0004  (SD 0.0085, 95% interval -0.0154–0.0185)
- **Corrected C-index:  0.7701**

## Interpretation
Optimism = 0.0004 (0.04% of apparent C). The correction is minimal, indicating low overfitting
in this sample. The corrected C-index should replace the apparent value in
Methods §8.1 and Results §3.3 for the final manuscript.

## Files
- Summary: `results/aim1/aim1_bootstrap_optimism_2026-07-30.csv`
- Distribution: `results/aim1/aim1_bootstrap_optimism_distribution_2026-07-30.csv`

## Reproducibility
`Rscript --vanilla code/04_model/run_bootstrap_optimism_charls_2026-07-30.R`
