# CHARLS 2011 FI diagnostic report

## Scope and construction

Gateway-aligned 43-item FI at CHARLS 2011 baseline. Raw files were read only. No mortality, outcome association, IC construction, or model fitting was performed. Age follows the project convention `2011 - ba002_1` (birth year), yielding baseline age 60+ N=7,669.

- Demographic rows: 17,705; FI eligible (>=35 valid items): 17404; excluded for >20% missing: 301
- FI-eligible age 60+ N: 7551; FI median/mean: 0.2 / 0.233
- ADL jump rescue: dressa=5884, batha=5885, eata=5885, beda=5885, toilta=5885, urina=5885

## Availability and Searle checks

- Missingness >30%: hlthlm_c (35.1%)
- Criterion 3 flags (<1% binary positive rate): hearaid
- Criterion 2 flags (non-monotonic age gradient): diabe, cancre, lunge, hearte, psyche, arthre, dyslipe, livere, kidneye, digeste, asthmae, painfr, hlthlm_c, slfmem

Item-level results: `tables/fi_item_availability_age_gradient.csv`.

## Redundancy and joga decision

- Pairs with |r| > 0.85: 0 (full list in `tables/fi_high_correlation_pairs_abs_gt_0.85.csv`).
- Focus correlations: walk100a/walk1kma=0.407; walk100a/joga=0.135; walk1kma/joga=0.417; dsight/nsight=0.455.
- Recommendation: retain `joga`; no tested pair exceeded |r|>0.85 and no redundancy criterion was triggered.

## FI distribution

- All eligible: N=17404, median=0.159, mean=0.192, max=0.846, >=0.7=29 (0.17%), skewness=1.354, age Spearman=0.342.
- Age 60+ eligible: N=7551, median=0.2, mean=0.233, max=0.808, >=0.7=23 (0.3%), skewness=1.065, age Spearman=0.225.
- Interpretation: both distributions are right-skewed and the central tendency is within the prespecified ranges. The strict <0.7 upper-limit expectation is exceeded by a small tail, not a large mass (23 age-60+ participants, 0.30%); this is reported rather than silently truncated. The age correlation is in the expected range for all eligible participants and lower in the restricted 60+ subset, so it should be retained as a diagnostic limitation.

## Unexpected data issues

- `ba004` is sparse/implausible in this release; age therefore uses the project-approved birth-year derivation, consistent with the existing CHARLS person-period code.
- `hlthlm_c` exceeds the 30% missingness threshold because its Gateway inputs span the work/retirement module; it is flagged for review and not silently imputed.
- `hearaid` has an overall binary positive rate below 1% and is flagged under criterion 3; it remains in the candidate FI pending the prespecified freeze decision.

## Outputs

Tables are under `results/fi_charls/tables/`; figures are under `results/fi_charls/figures/`; the individual-level FI is `data/analysis/charls_fi_2011_2026-07-27.parquet`.
