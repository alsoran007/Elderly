# Methods (English) — Paper 1 Draft

**Note**: English translation of `paper_methods_draft_2026-07-29.md`. Sections are numbered to match the Chinese source. TRIPOD+AI item tags retained for cross-referencing with `tripod_checklist_2026-07-30.md`. Two gaps identified in the checklist (PROBAST-AI assessment §10b; internal validation optimism note §8.1) are addressed below.

---

## 1. Study Design

This study reports the development and external validation of a clinical prediction model for four-year all-cause mortality in older adults across six international longitudinal ageing cohorts. The study was designed and reported in accordance with the TRIPOD+AI statement[REF-8] and the PROBAST-AI risk-of-bias framework.[REF-9] Three external validation aims were pre-specified: (Aim 1) internal-to-China transferability (CHARLS to CLHLS); (Aim 2) leave-one-cohort-out analysis within an Asian multi-cohort pool; (Aim 3) transfer from the Asian pool to cohorts in the United States, Europe and Mexico. All analytic decisions were locked in a statistical analysis plan (SAP v1.0) before any outcome–predictor associations were examined (git commit 9bc7b85, 2026-07-29).

---

## 2. Data Sources

Six publicly available longitudinal ageing cohorts were used (Table 1).

**Table 1. Cohort overview**

| Cohort | Country/Region | Baseline | Target population | FI-eligible ≥60 N | 4-year events | Event rate |
|---|---|---|---|---:|---:|---:|
| CHARLS | China | 2011 | Community-dwelling ≥45 yrs | 7,551 | 771 | 10.2% |
| CLHLS | China | 2011/12 | Oldest-old ≥65 yrs | 7,095* | 3,282 | 46.3%* |
| KLoSA | South Korea | 2012 | Community-dwelling ≥45 yrs | 5,288 | 510 | 9.6% |
| HRS | United States | 2012 | Community-dwelling ≥51 yrs | 10,707 | 2,138 | 20.0% |
| SHARE | 27 European countries | 2011† | Community-dwelling ≥50 yrs | 36,352* | 3,165 | 8.7%* |
| MHAS | Mexico | 2012 | Community-dwelling ≥50 yrs | 9,081* | 924 | 10.2%* |

*Complete-case analysis sample. †Restricted to wave-4 participants interviewed in 2011 (94.1% of wave-4).  
CHARLS = China Health and Retirement Longitudinal Study; CLHLS = Chinese Longitudinal Healthy Longevity Survey; KLoSA = Korean Longitudinal Study of Ageing; HRS = Health and Retirement Study; SHARE = Survey of Health, Ageing and Retirement in Europe; MHAS = Mexican Health and Aging Study. Cohort profile references: CHARLS,[REF-20] CLHLS,[REF-21] KLoSA,[REF-22] HRS,[REF-23] SHARE,[REF-24] MHAS.[REF-25]

All data were obtained through official application to each data archive. Raw data files were used in read-only mode; all derived analytic files were stored in a separate analysis directory.

---

## 3. Participants

**Common eligibility criteria**: (i) age ≥60 years at baseline; (ii) alive and having completed the personal interview at baseline; (iii) FI computable (see §5).

**Cohort-specific considerations**:
- *CHARLS*: Baseline wave 1 (2011). Because individual identifiers differ in length between wave 1 (11 digits) and subsequent waves (12 digits), cross-wave linkage followed the Gateway-validated rule `pid_w2+ = householdID_w1 + "0" + id_w1[last 2 digits]`, yielding linkage rates of 85.5% (2015 wave) and 81.3% (2018 wave).
- *CLHLS*: Forty-five participants whose recorded death date preceded their baseline interview date (range −306 to −1 days) were flagged as pre-baseline deaths; their outcome variable was set to missing (not-at-risk) and they were excluded from time-to-event analyses.
- *SHARE*: Restricted to participants whose wave-4 interview was conducted in 2011, to align with the 2011–2015 follow-up window used in other cohorts. This retained 94.1% (54,550 of 57,982) of wave-4 records.
- *MHAS*: Age was taken from the direct report (`r3agey`) when available; for participants with missing direct age, it was derived as interview year minus birth year (`r3iwy − rabyear`). Implausible values (<20 or >110 years) were set to missing.
- *KLoSA*: Wave 4 (2012) was used as baseline; only participants present and interviewed at wave 4 were included.

**Exclusion criteria**: Missing baseline age; FI not computable (number of non-missing deficit items below the cohort-specific threshold; see §5).

---

## 4. Primary Outcome

The primary outcome was **four-year all-cause mortality** from baseline.

Because CHARLS death records from 2015 onwards contain only a wave-level indicator (`died_by_wave`) without an exact date, follow-up was modelled using a **discrete-time survival framework**[REF-10] with two risk periods:

- *Period 1*: baseline (2011) to the 2013 exit interview (~2 years)
- *Period 2*: 2013 exit interview to the 2015 wave (~2 years)

The primary binary outcome equals 1 if death occurred in period 1 or 2 (approximately 2011–2015, nominally 4 years) and 0 otherwise. For validation cohorts that recorded exact death dates (CLHLS, HRS, SHARE, MHAS), the equivalent cut-point was **≤1,461 days** (4 × 365.25) after the baseline interview. KLoSA vital status was ascertained from wave-level survival tracking.

A pre-specified **sensitivity outcome** was all-cause mortality within approximately 7 years (periods 1 + 2 + 3, 2011–2018), evaluated in CHARLS and CLHLS only.

---

## 5. Frailty Index Construction

The FI followed the deficit-accumulation model: FI = Σ(deficit scores) / number of non-missing items, bounded [0, 1].[REF-4] Variable definitions for all cohorts were extracted from the Gateway to Global Aging harmonised data scripts (H_CHARLS_long D.2; H_KLoSA_long F)[REF-19] and re-implemented in Python/R without requiring Stata.

The **final 41-item list** (locked 2026-07-28; decision D-020) spans seven domains:

| Domain | Items (n) | Representative deficits |
|---|---|---|
| Chronic conditions | 13 | hypertension, diabetes, cancer, lung disease, heart disease, stroke, psychiatric illness, arthritis, dyslipidaemia, liver, kidney, digestive, asthma |
| ADL | 6 | dressing, bathing, eating, bed/chair transfer, toileting, urinary incontinence |
| IADL | 5 | housework, cooking, shopping, financial management, medication management |
| Mobility | 9 | walking 100 m, walking 1 km, jogging, climbing stairs, rising from chair, stooping, lifting arms, carrying weights, picking up coin |
| Sensory | 3 | near vision, distance vision, hearing |
| General health | 4 | self-rated health, BMI abnormality, chronic pain, falls |
| Cognitive proxy | 1 | memory self-rating (slfmem; available in 5/6 cohorts) |

**Key coding rules**:
- All deficits were dichotomised (0 = absent, 1 = present); Likert-scale items (vision, hearing, self-rated health, memory self-rating) were rescaled as (*raw* − 1) / 4 to [0, 1] before inclusion (decision D-026).
- ADL items used the "some difficulty" variant; the skip-logic imputation rule assigned 0 (not missing) to ADL items where all prerequisite items were answered as "no difficulty" (Gateway `.do` file line 6484).
- BMI deficits used WHO cut-points (<18.5 or ≥30 kg/m²; decision D-015).
- **Computability threshold**: an FI was computed only when the number of non-missing items reached ⌈0.8 × available stems⌉ for that cohort (cohort-specific: MHAS 27/41 stems → threshold 22; all others 41/41 → threshold 33).

Three items from the original 44-candidate list were excluded before analysis (decision D-020): `hearaid` (positive rate <1% in CHARLS; cross-cohort non-comparability), `hlthlm_c` (missing rate 35.1% in CHARLS 60+), and `mbmicata` (redundant with the continuous BMI deficit item).

For HRS, eight stems were unavailable in the harmonised Fat File; documented substitutes were used where feasible (decision D-025). Two substitutions carry measurement-proxy limitations noted in the supplementary methods: `dyslipe` (cholesterol testing behaviour as proxy for diagnosis) and `kidneye` (diabetes-complication kidney disease only).

---

## 6. Covariates

All models included **age** (continuous, years) and **sex** (0 = female, 1 = male) as baseline covariates. Education was planned as a covariate but could not be reliably harmonised from the analytic parquet files across all cohorts; it was excluded from the primary analysis and this is noted as a limitation.

For Aims 2 and 3 (multi-cohort analyses), sex was further omitted from the model specification because the KLoSA FI file did not include a harmonised sex variable. To ensure a common model form across all LOCO and Asian-pool analyses, the uniform specification `event ~ fi_full + age` (without sex) was used. Aim 1 (CHARLS → CLHLS) retained sex: `event ~ fi_full + age + sex`.

---

## 7. Missing Data

**FI missingness** was handled internally by the computability threshold (§5): participants with too many missing deficit items were excluded; no external imputation was applied to FI components.

**Outcome missingness**: Loss to follow-up was treated as censoring and not imputed as survival. In CLHLS, 2,072 of 9,207 FI-eligible participants (22.9%) had a missing 4-year outcome (death date irrecoverable or lost to follow-up). Complete-case analysis was the primary approach; an inverse-probability-of-censoring weighting (IPCW) sensitivity analysis was pre-specified (SAP §12.3) and is reported in §3.7.

**Covariate missingness**: Age and sex were near-complete across all cohorts (<0.5% missing); no imputation was required.

---

## 8. Statistical Analysis

### 8.1 Model Development (CHARLS Development Set)

The development dataset comprised a **person-period long table** with one row per participant per risk period (14,551 rows; 7,551 participants; 771 events across periods 1–2). Two pooled logistic regression models were fitted:

- **Model A (demographic baseline)**: logit(*P*ₜ) = β₀ + β_age·age + β_sex·sex + γₜ
- **Model B (FI model, primary analysis)**: logit(*P*ₜ) = β₀ + β_FI·FI + β_age·age + β_sex·sex + γₜ

where γₜ is a period indicator (period 2 vs. period 1). A complementary log-log (cloglog) model was fitted in parallel as a sensitivity check on the link-function assumption.

Four-year cumulative predicted probability for external cohorts was derived as:

*P*(4-year death) = 1 − (1 − *ĥ*₁)(1 − *ĥ*₂)

where *ĥ*ₜ = logistic(β̂′**x** + γ̂ₜ), with CHARLS-frozen coefficients applied directly without refitting in the validation set.

*Internal discrimination note*: The C-index reported for CHARLS is the **apparent pooled person-period** estimate. No optimism correction (e.g., bootstrap shrinkage) was applied to the primary CHARLS internal estimate; this preliminary version will be updated with a bootstrap-corrected estimate prior to journal submission.

### 8.2 Validation Structure (Three Aims)

**Aim 1 — Internal China transferability**: CHARLS Model B coefficients were frozen and applied to CLHLS; the full performance metric set was computed.

**Aim 2 — Asian multi-cohort LOCO**: Three Leave-One-Cohort-Out rounds:
- Round A: CLHLS + KLoSA train → CHARLS test
- Round B: CHARLS + KLoSA train → CLHLS test
- Round C: CHARLS + CLHLS train → KLoSA test

To separate the effect of training-set diversity from the effect of increased sample size, **down-sampling bootstrap** (200 replications, reduced to CHARLS *n* = 7,551) was used as the control comparison for H3 testing. All LOCO models used the reduced specification `event ~ fi_full + age`.

**Aim 3 — Asian pool → global external validation**: CHARLS, CLHLS and KLoSA were pooled as the Asian training set (N = 19,934; 4,563 events; event rate 22.9%). Frozen Asian-pool coefficients were applied separately to HRS, SHARE and MHAS. An additional analysis reported country-level C-indices within SHARE's 19 participating countries/regions.

### 8.3 Performance Metrics

| Dimension | Metric | Target / Reference |
|---|---|---|
| Discrimination | Harrell's C-index (95% bootstrap CI) | Primary; ≥0.70 considered clinically useful |
| Discrimination | FI incremental discrimination (ΔC = C_B − C_A) | H1 threshold: ΔC ≥ 0.02 |
| Calibration | Observed-to-expected ratio (O:E) | Ideal = 1.0 |
| Calibration | Calibration intercept | Ideal = 0 |
| Calibration | Calibration slope | Ideal = 1.0 |
| Overall | Brier score | Lower is better |
| Overall | Index of Prediction Accuracy (IPA) | 1 − Brier / Brier_null;[REF-12] ≥0 means better than null |

### 8.4 Recalibration Ladder (L0–L3)

For each source–target cohort pair in Aim 3 (and Aim 2 L1 update), four successive recalibration levels were applied:[REF-11]

| Level | Operation | Parameters estimated in target cohort |
|---|---|---|
| **L0** | Frozen model (no adjustment) | — |
| **L1** | Intercept update | α: maximises log-likelihood, slope fixed at 1 |
| **L2** | Intercept + slope update | (α, β_slope): two-parameter calibration on linear predictor |
| **L3** | Full refit | All coefficients of `event ~ fi_full + age` |

This ladder isolates the contribution of event-rate drift (L0→L1), slope drift (L1→L2) and predictor-effect heterogeneity (L2→L3) to overall performance loss.

### 8.5 Sensitivity Analyses

| ID | Analysis | Specification |
|---|---|---|
| SA-1 | FI_core (19 items) | Strict cross-cohort common item set; threshold = ⌈0.8 × 19⌉ = 16 |
| SA-2 | IPCW (CLHLS) | Censoring model: P(observed \| fi_full, age, sex); weights truncated at 99th percentile |

### 8.6 Feature Importance Analysis (H6)

For each cohort, a logistic regression was fitted on FI_core (19 items) plus age. The absolute standardised coefficient |β_standardised| served as a linear-SHAP importance proxy — an exact measure for generalised linear models with main effects. Cross-cohort concordance was assessed using a 6 × 6 Spearman rank-correlation matrix. Pre-registered H6 criteria: (i) age ranks first in all six cohorts; (ii) median pairwise Spearman ρ ≥ 0.70.

---

## 9. Software and Code Availability

All analyses were conducted in R 4.4.1 (R Core Team, 2024). Key packages: `arrow` (parquet I/O), `survival` (C-index), `pROC` (AUC), `tidyverse` (data wrangling). Data harmonisation and FI extraction used Python 3.10.

Analysis code is archived at https://github.com/alsoran007/Elderly, including the SAP pre-registration timestamp (commit 9bc7b85) and all analytic scripts. Raw cohort data must be requested from each archive separately and cannot be shared directly.

---

## 10. Reporting Standards and Pre-registration

This study was reported in full accordance with the **TRIPOD+AI** checklist (Supplementary Table S1).[REF-8] Risk of bias and applicability were assessed using the **PROBAST-AI** framework (Supplementary Table S2).[REF-9]

The SAP (v1.0) was locked before any outcome–predictor analyses using a git commit timestamp (2026-07-29, commit 9bc7b85); amendments are tracked append-only in `docs/SAP_amendments.md`. Results for hypotheses H1–H6 are reported as pre-specified without post-hoc adjustment.

**PROBAST-AI summary assessment** (full table in Supplementary): Risk of bias was judged *low* for the development cohort (CHARLS) across all four PROBAST-AI domains (participants, predictors, outcome, analysis). For external validation cohorts, the outcome domain was rated *moderate concern* for CLHLS (22.9% missing outcome) and *low* for all other cohorts. The analysis domain was rated *low concern* for all cohorts given the pre-registered SAP, complete-case primary analysis with IPCW sensitivity, and the absence of predictor selection after outcome inspection.

---

*English draft completed: 2026-07-30*
*Sections §1–10 complete; corresponds to Chinese source `paper_methods_draft_2026-07-29.md`*
*Next: Discussion EN draft → commit all*

