# Results (English) — Paper 1 Draft

**Note**: English translation of `paper_results_draft_2026-07-29.md`. All numerical values independently verified against results CSVs (aim1, aim2, aim3, ipcw, h6_shap, h5_ic) before writing. Tables 1–3 are placed inline as in the submission manuscript. H5 verdict reflects post-correction status (D-034).

---

## 3.1 Participants and Cohort Overview

All six cohorts completed FI computability screening for participants aged ≥60 years. The analytic samples available for modelling and their outcome distributions are summarised in Table 1. CHARLS, CLHLS and KLoSA form the Asian development pool; HRS, SHARE and MHAS serve as external validation cohorts. The FI-eligible counts listed in Table 1 represent participants meeting the computability threshold; the complete-case analytic sample additionally requires an observed four-year outcome and non-missing covariates.

**Table 1. Baseline characteristics and four-year outcomes by cohort**

| Cohort | Role | FI-eligible ≥60 N | FI median | Complete-case N | Events | Event rate |
|---|---|---:|---:|---:|---:|---:|
| CHARLS | Development | 7,551 | 0.200 | 7,546 | 771 | 10.2% |
| CLHLS | Aim 1 / Asian pool | 9,207 | 0.169 | 7,095† | 3,282 | 46.3% |
| KLoSA | Asian pool | 5,289 | 0.095 | 5,288 | 510 | 9.6% |
| HRS | External validation | 10,707 | 0.287 | 10,707 | 2,138 | 20.0% |
| SHARE | External validation | 36,361 | 0.169 | 36,352 | 3,165 | 8.7% |
| MHAS | External validation | 9,094 | 0.220 | 9,081 | 924 | 10.2% |

†2,112 FI-eligible CLHLS participants (22.9%) had missing four-year outcomes and were excluded from complete-case analyses.  
FI median: cohort-specific 60+ subset. Event rate: events / complete-case N.

The FI median was lowest in KLoSA (0.095) and highest in HRS (0.287); the remaining cohorts ranged from 0.169 to 0.220. The low KLoSA median is consistent with this cohort's relatively young, community-dwelling sample and low ADL/IADL deficit rates; no coding errors were identified in data quality checks. FI maximum values did not exceed 1.0 in any cohort. MHAS used 27 cohort-available stems with a pre-specified computability threshold; HRS used documented substitutions for eight unavailable items (see Methods §5).

---

## 3.2 FI Distribution and Data Completeness

FI construction followed the locked 41-item specification (decision D-020), with ordinal health items uniformly rescaled to [0, 1] before inclusion. CHARLS, CLHLS, KLoSA, HRS and SHARE each achieved 41/41 stems (with validated substitutions for HRS); MHAS achieved 27/41 cohort-available stems under the cohort-specific threshold.

FI distributions showed marked cohort heterogeneity: KLoSA median 0.095, HRS 0.287, SHARE and CLHLS both 0.169. This heterogeneity reflects differences in case-mix, item availability and underlying event rates, and means that a single numeric FI threshold cannot serve as a universal frailty cut-point across cohorts without adjusting for cohort context.

CLHLS required particular attention for outcome missingness. Of 9,207 FI-eligible participants, 7,095 had an observable four-year outcome; 2,112 (22.9%) had missing `event_4y`, comprising 45 pre-baseline deaths (flagged not-at-risk) and 2,067 participants with irrecoverable follow-up or death dates. Complete-case analysis did not assign survival status to participants with unknown outcomes. Education could not be reliably harmonised in the analytic files; the primary analysis is therefore unadjusted for education (see Limitations).

---

## 3.3 Model Development in CHARLS

The CHARLS development dataset comprised 7,546 participants contributing 14,551 complete person-period rows across risk periods 1–2, with 771 deaths. Model A included age, sex and a period indicator; Model B added FI. Coefficient estimates are shown in Table 2.

**Table 2. Pooled logistic regression coefficients, CHARLS development set**

| Model | Term | β | SE | p |
|---|---|---:|---:|---|
| **Model A** | Age (per year) | 0.1108 | — | <0.001 |
| | Female | −0.3523 | — | <0.001 |
| | Period 2 vs. 1 | 0.4233 | — | <0.001 |
| **Model B** | Intercept | −10.4820 | 0.3608 | <0.001 |
| | **FI (per unit)** | **3.5467** | 0.2450 | <10⁻⁴⁷ |
| | **Age (per year)** | **0.0936** | 0.0050 | <10⁻⁷⁹ |
| | Female | −0.5155 | 0.0790 | <10⁻¹⁰ |
| | Period 2 vs. 1 | 0.4753 | 0.0781 | <10⁻⁹ |

FI = frailty index (range 0–1). Model A: `event ~ age + female + period`; Model B: `event ~ fi_full + age + female + period`. SE not reported for Model A in the archived output.

Model A achieved an apparent C-index of 0.7355. Adding FI raised the Model B apparent C-index to **0.7705**, an increment of **ΔC = 0.0351**. The pre-specified H1 threshold (ΔC ≥ 0.02 for FI beyond age and sex) was therefore **met, and H1 is supported**.

Internal validation by person-level bootstrap (B = 200) yielded mean optimism of **0.0004** (SD 0.0085; 95% bootstrap interval −0.015 to +0.019), giving an **optimism-corrected C-index of 0.7701** (shrinkage factor 0.9995). The negligible optimism indicates that Model B, with four predictors and 771 events (EPV = 193), showed essentially no overfitting; apparent and corrected estimates are interchangeable to three decimal places. Because education was not included, these estimates should nonetheless be interpreted as preliminary model development results.

---

## 3.4 Aim 1: External Validation in CLHLS

CHARLS Model B coefficients were frozen and applied to CLHLS using the discrete-time cumulative risk formula. Among 7,095 complete-case CLHLS participants, 3,282 deaths were observed (event rate **46.3%**, versus 10.2% in the development cohort).

Discrimination was well preserved: **C-index = 0.8389** (500-replication bootstrap 95% CI 0.8301–0.8481). Calibration showed systematic drift: **O:E ratio = 1.2473**, calibration intercept = 0.5976, calibration slope = 0.9393, indicating that the frozen model under-predicted mortality risk by approximately 25% overall while preserving risk ranking and gradient. Brier score was 0.17509 and IPA was 0.2957. Decision curve analysis was completed.

The decile-level calibration pattern showed under-prediction concentrated in the mid-risk range: predicted versus observed risk was 4.0% vs. 4.9% in decile 1, 23.8% vs. 40.3% in decile 5, 47.2% vs. 65.9% in decile 7, and 90.3% vs. 88.9% in decile 10 — a pattern of substantial mid-range under-prediction with convergence at both extremes, consistent with transporting a low-event-rate model to a high-event-rate cohort.

---

## 3.5 Aim 2: Leave-One-Cohort-Out Transfer Within Asia

All LOCO analyses used the uniform specification `event ~ fi_full + age`, omitting sex because KLoSA lacked a harmonised sex variable (Methods §6). Results are summarised in Table 3.

**Table 3. LOCO and Asian-pool external validation performance**

| Analysis | Train | Test | Level | C-index (95% CI) | O:E | Cal. slope | IPA |
|---|---|---|---|---|---:|---:|---:|
| Baseline | CHARLS | CLHLS | raw | 0.8334 (0.8246–0.8417) | 1.276 | 0.990 | 0.2815 |
| Baseline | CHARLS | KLoSA | raw | 0.8023 (0.7825–0.8220) | 0.971 | 1.179 | 0.1610 |
| Round A | CLHLS+KLoSA | CHARLS | raw | 0.7588 (0.7400–0.7780) | 0.669 | 0.851 | 0.0597 |
| Round A | CLHLS+KLoSA | CHARLS | L1 | 0.7588 (0.7435–0.7762) | 1.000 | 0.851 | 0.1136 |
| Round B | CHARLS+KLoSA | CLHLS | raw | 0.8346 (0.8268–0.8448) | 1.266 | 0.936 | 0.2859 |
| Round B | CHARLS+KLoSA | CLHLS | L1 | 0.8346 (0.8249–0.8443) | 1.000 | 0.936 | 0.3368 |
| Round C | CHARLS+CLHLS | KLoSA | raw | 0.8011 (0.7824–0.8218) | 0.758 | 1.076 | 0.1482 |
| Round C | CHARLS+CLHLS | KLoSA | L1 | 0.8011 (0.7800–0.8232) | 1.000 | 1.076 | 0.1608 |
| Aim 3 | Asian pool | HRS | L0 | 0.7901 (0.7807–0.7992) | 0.821 | 0.967 | 0.1927 |
| Aim 3 | Asian pool | HRS | L3 | 0.7929 (0.7818–0.8038) | 1.000 | 1.000 | 0.2111 |
| Aim 3 | Asian pool | SHARE | L0 | 0.7780 (0.7699–0.7873) | 0.599 | 0.838 | 0.0276 |
| Aim 3 | Asian pool | SHARE | L3 | 0.7797 (0.7721–0.7878) | 1.000 | 1.000 | 0.1194 |
| Aim 3 | Asian pool | MHAS | L0 | 0.7243 (0.7040–0.7432) | 0.677 | 0.686 | −0.0022 |
| Aim 3 | Asian pool | MHAS | L3 | 0.7245 (0.7055–0.7431) | 1.000 | 1.000 | 0.0817 |

raw / L0 = frozen model, no adjustment; L1 = intercept update; L3 = full refit in target cohort. Asian pool = CHARLS + CLHLS + KLoSA (N = 19,934; 4,563 events; event rate 22.9%).

Discrimination was stable across all three LOCO rounds (C = 0.759–0.835). Raw O:E ratios were 0.669 (Round A), 1.266 (Round B) and 0.758 (Round C); after L1 intercept update all reached exactly 1.000 while C-index remained unchanged, and IPA improved substantially (Round A 0.060 → 0.114; Round B 0.286 → 0.337).

The down-sampling comparison (200 bootstrap replications, reduced to the CHARLS sample size of 7,551 to remove the sample-size confound) showed ΔC of **+0.0013** for Round B and **−0.0013** for Round C relative to the CHARLS-only baseline — both far below the pre-specified 0.02 clinical relevance threshold and inconsistent in direction. Adding a second Asian cohort therefore produced no meaningful discrimination gain, and **H3 is not supported**. This supports the interpretation that the principal barriers to cross-cohort transfer are measurement non-equivalence and event-rate drift rather than insufficient training-cohort diversity.

---

## 3.6 Aim 3: Asian Pool to HRS, SHARE and MHAS

CHARLS, CLHLS and KLoSA were pooled into an Asian training set (N = 19,934; 4,563 events; event rate 22.9%; FI β = 3.838, age β = 0.1112, intercept = −10.891). Frozen coefficients were applied separately to each validation cohort across the L0–L3 recalibration ladder (Table 3; Figure 5).

In HRS, the frozen model achieved L0 C-index 0.7901, O:E 0.8205, slope 0.9671 and IPA 0.1927; after L3 these were 0.7929, 1.000, 1.000 and 0.2111. In SHARE, L0 values were C-index 0.7780, O:E 0.599, slope 0.8381 and IPA 0.0276; after L3, 0.7797, 1.000, 1.000 and 0.1194. In MHAS, L0 values were C-index 0.7243, O:E 0.6769, slope 0.6859 and IPA −0.0022; after L3, 0.7245, 1.000, 1.000 and 0.0817.

Discrimination changed minimally from L0 to L3 (HRS +0.0028, SHARE +0.0017, MHAS +0.0002), whereas intercept and slope updates markedly improved calibration in every cohort. **H2 (discrimination decay smaller than calibration decay) is therefore supported.**

**H4 is also supported**: L1 intercept update alone — requiring only the target-cohort event rate — accounted for **87.5% of the total recoverable IPA gain in HRS** ([0.2088 − 0.1927] / [0.2111 − 0.1927]), **93.9% in SHARE** ([0.1138 − 0.0276] / [0.1194 − 0.0276]), and **78.2% in MHAS** ([0.0634 − (−0.0022)] / [0.0817 − (−0.0022)]). Event-rate drift was thus the dominant attributable source of calibration failure in all three validation cohorts, exceeding the pre-specified 50% threshold in each case. Percentages are computed against the full L0→L3 recoverable span.

MHAS was the weakest validation cohort. Its L0 IPA of −0.0022 indicates a Brier score marginally worse than a null model, arising because the Asian pool's high mean event rate (22.9%, driven by CLHLS at 46.3%) systematically over-predicted risk in a 10.2% event-rate target. IPA rose to 0.0634 after L1 and 0.0816 after L2; the persistent post-L1 slope of 0.686 confirms that MHAS required slope recalibration in addition to intercept adjustment to achieve reliable absolute risk estimates.

Within SHARE, country-level C-indices across 19 participating countries ranged from 0.6911 to 0.8564 with a median of approximately 0.768, indicating reasonable geographic generalisation of the Asian-pool model within Europe while confirming that country-level event rates and case-mix still influence discrimination.

---

## 3.7 IPCW Sensitivity Analysis for Missing CLHLS Outcomes

Among CLHLS FI-eligible participants, 22.9% had missing four-year outcomes. The censoring model showed that observation was predicted by higher FI (β = +0.652, p = 0.0004) and older age (β = +0.0115, p < 0.0001), while sex was not significant (β = −0.078, p = 0.130), indicating that censoring was mildly informative rather than completely at random. Censoring rates by FI tertile were 25.2% (low), 24.1% (middle) and 19.6% (high). IPCW weights were narrow (mean 1.292, median 1.291, maximum 1.451 after 99th-percentile truncation).

IPCW-weighted analysis yielded C-index **0.8397** versus 0.8389 unweighted (**ΔC = +0.0008**); O:E moved from 1.2473 to 1.2547, calibration slope from 0.9393 to 0.9458, Brier score from 0.17509 to 0.17399, and IPA from 0.2957 to 0.2967. All differences were negligible, indicating that the Aim 1 complete-case results are robust to informative censoring.

---

## 3.8 H6: Cross-Cohort Consistency of Feature Importance

Cohort-specific logistic models on FI_core (19 items) plus age identified **age as the single most important feature in all six cohorts**. Other top-ranked features varied by cohort: self-rated health (`shlt`) entered the top 3 in CHARLS, HRS, SHARE and MHAS, while meal-preparation difficulty (`mealsa`) ranked second in both CLHLS and KLoSA.

The median pairwise Spearman rank correlation of feature importance across the six cohorts was **0.4105** (range 0.0962–0.6677). The lowest concordance was KLoSA–HRS (0.0962), followed by KLoSA–CHARLS (0.0992); the highest were CHARLS–SHARE (0.6677), HRS–SHARE (0.6662) and SHARE–MHAS (0.6617).

**H6 is therefore partially supported**: the pre-specified criterion that age ranks in the top 3 was met in 6/6 cohorts, but the median Spearman ρ ≥ 0.70 criterion was not met (observed 0.41), indicating substantive cross-cohort heterogeneity in the predictive importance of individual deficits.

---

## 3.9 Supplementary Analysis: FI versus Intrinsic Capacity (H5)

In the pre-specified supplementary comparison within the CHARLS → CLHLS framework, Model B (FI + age) achieved apparent C-index 0.7608 in CHARLS and external C-index 0.8131 in CLHLS (|ΔC| = 0.052). Model C (IC five domains + age) achieved 0.7105 and 0.8060 respectively (|ΔC| = 0.095). Model D (FI + IC + age) achieved 0.7217 and 0.8123 (|ΔC| = 0.091).

FI showed the smallest cross-cohort C-index shift, and **H5 is supported**. Three caveats constrain this conclusion: CLHLS IC domains were represented by binary FI-item proxies rather than continuous measurements; the CHARLS internal baselines differed by approximately 0.05 between models; and C-index rose for both models in CLHLS partly through mechanical amplification in a high-event-rate cohort. Full IC external validation with continuous measures is deferred to Paper 2 (decision D-012). Bootstrap confidence intervals for the H5 comparison did not converge and only point estimates are reported.

---

## 3.10 Summary of Pre-Registered Hypothesis Verdicts

| Hypothesis | Pre-specified criterion | Observed | Verdict |
|---|---|---|---|
| **H1** | FI adds ΔC ≥ 0.02 beyond age + sex | ΔC = 0.0351 | **Supported** |
| **H2** | Discrimination decay < calibration decay on transfer | ΔC(L0→L3) ≤ 0.003; O:E 0.60–1.25 → 1.00 | **Supported** |
| **H3** | Multi-cohort training improves transfer (ΔC ≥ 0.02) | \|ΔC\| ≤ 0.0013 (down-sampled) | **Not supported** |
| **H4** | Event-rate + case-mix drift explain ≥50% of loss | L1 alone explains 87.5% (HRS), 93.9% (SHARE), 78.2% (MHAS) | **Supported** |
| **H5** | FI more stable across cohorts than IC | \|ΔC\| 0.052 (FI) vs. 0.095 (IC) | **Supported** (supplementary; exploratory) |
| **H6** | Age in top 3 in all cohorts AND median ρ ≥ 0.70 | Age 1st in 6/6; median ρ = 0.4105 | **Partially supported** |

---

*English draft completed: 2026-07-30*
*Source: `paper_results_draft_2026-07-29.md`; all values verified against results CSVs*
*Note: §3.9 (H5) and §3.10 expanded relative to the Chinese draft, which combined these into a single §3.9*
