# Aim 1 denominator audit (2026-07-29)

The analysis follows the explicit task rules and the CLHLS outcome v2 censoring convention.

- CHARLS person-period period 1-2, age 60+, FI eligible: 14,660 rows, 7,552 persons before predictor complete-case filtering; 14,551 rows, 7,546 persons and 771 events after removing 10 rows with missing female.
- The task note's CHARLS example of 785 events corresponds to age-60+ rows before excluding FI-ineligible records; the prespecified FI-eligible rule yields 771 events.
- CLHLS FI eligible: 9,207 persons. Of these, 40 have prebaseline death and are excluded from the fixed-window validation set.
- Among the remaining CLHLS FI-eligible persons, 2,072 have `event_4y=NA` because follow-up is lost or a death date cannot be constructed. These are not coded as survivors.
- Strict complete-outcome external validation therefore uses 7,095 persons and 3,282 observed four-year deaths. This is the denominator used for C-index, calibration, Brier, IPA, and DCA.
- The task note's `9,207/3,502` example mixes the FI-eligible denominator with the all-outcome event count and is not a valid complete binary-outcome denominator under the outcome v2 rules.

The lost/unknown cases require censoring-aware or IPCW validation if the target analysis must use the full FI-eligible denominator.
