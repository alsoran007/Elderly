# Discussion (English) — Paper 1 Draft

**Note**: English translation of `paper_discussion_draft_2026-07-30.md` (post-correction version). All numerical values verified against results CSVs and decision_log D-029–D-034 before writing. TRIPOD+AI item cross-references retained.

---

## 4.1 Principal Findings

This study systematically evaluated the cross-cultural transferability of a deficit-accumulation Frailty Index (FI) for predicting four-year all-cause mortality across six longitudinal ageing cohorts spanning China, South Korea, the United States, 27 European countries and Mexico — one of the largest cross-cultural FI mortality prediction studies to date (76,074 complete-case participants aged ≥60 years; 10,790 four-year deaths). The results reveal a consistent two-tier structure: FI model **discrimination** (C-index 0.72–0.84) remained robust across cultural transfer without retraining, preserving clinically meaningful risk ranking; whereas **calibration** (the absolute accuracy of predicted event rates) showed systematic drift, driven primarily by baseline mortality-rate differences between the development and target cohorts, and largely correctable through intercept recalibration. Of six pre-registered hypotheses, H1, H2, H4 and H5 were supported, H3 was not supported, and H6 was partially supported. All findings are based on analyses conducted after SAP lock (commit 9bc7b85), with strict outcome blinding maintained throughout.

---

## 4.2 Incremental Predictive Value of FI Beyond Demographics (H1)

Adding FI to the demographic model increased C-index from 0.736 (age, sex, period) to 0.771 in the CHARLS development set, an increment of ΔC = 0.035 (p < 0.001), meeting the pre-specified H1 threshold (ΔC ≥ 0.02). This increment is consistent with prior reports from Western cohorts[REF-5,REF-6] and explicitly extends that finding to rural community-dwelling older adults in China, indicating that the independent predictive contribution of FI beyond basic demographic information is cross-culturally general.

The mechanism underlying this increment reflects the FI's core information content as a "biological age" composite: while chronological age captures the mean trajectory of time-driven biological ageing, FI accumulates observed health deficits across comorbidity, function, nutrition and cognition, encoding individual heterogeneity that is independent of calendar age. This multi-system comprehensiveness allows FI to maintain conceptual comparability across cultural settings and healthcare systems, in contrast to instruments that depend on a single performance protocol (e.g., grip-strength cut-points, gait speed thresholds), which are often difficult to compare directly across cohorts because of measurement protocol variation.

---

## 4.3 Dissociation of Discrimination and Calibration: Two Independent Dimensions of Transferability (H2, H4)

The most methodologically consequential finding of this study is the pattern of **stable discrimination alongside drifting calibration**. In the Asian-pool → global validation framework (Aim 3), the full L0-to-L3 recalibration ladder increased C-index by only 0.000–0.003 (HRS +0.003, SHARE +0.002, MHAS +0.000), while O:E ratios moved from systematic bias (HRS 0.821, SHARE 0.599, MHAS 0.677) to 1.000 after L1 adjustment (H2 supported). The same pattern appeared consistently in Aim 1 (CHARLS → CLHLS: C = 0.839, O:E = 1.247) and Aim 2 (three LOCO rounds: C = 0.759–0.835, O:E = 1.000 after L1 in all rounds), establishing this discrimination–calibration dissociation as a structural feature of FI cross-cultural transfer rather than a chance finding in a single cohort pair.

The mechanism sustaining robust discrimination is tied to the relative-ranking property of the C-index. The C-index measures how accurately the model ranks individuals by relative mortality risk, not the absolute probability level. As a cumulative deficit proportion, FI's relative ranking fundamentally reflects the degree to which an individual's health state deviates from the age-matched norm — and a high-deficit individual in China, the United States or Mexico will tend to have relatively higher mortality risk regardless of country-level absolute mortality differences. This relative relationship is insensitive to cross-national differences in absolute death rates, which is why discrimination is preserved. Calibration, by contrast, requires the predicted absolute probability to match the target cohort's empirical event rate — which inherently depends on the development cohort's baseline rate — and necessarily drifts when target event rates deviate substantially (CLHLS 46.3% vs. CHARLS 10.2%; SHARE 8.7% vs. Asian pool 22.9%).[REF-11,REF-14]

H4 further quantifies the attributable sources of calibration failure. A simple L1 intercept update — adjusting the intercept using only the target-cohort event rate, requiring no re-collection of predictor data or model retraining — explained **87.5% of recoverable IPA gain in HRS** (0.193 → 0.209), **93.9% in SHARE** (0.028 → 0.114) and **78.2% in MHAS** (−0.002 → 0.063), all computed against the full L0→L3 recoverable span. For every target cohort examined, a single lightweight recalibration was therefore sufficient to raise a cross-cultural model's calibration performance to a practically useful level, at very low operational cost.

MHAS presents an important exception. The frozen Asian-pool model yielded L0 IPA = −0.002 in MHAS — meaning Brier score worse than a null (event-rate-only) model — because the highly unequal composition of the Asian training pool (mean event rate 22.9%, dominated by CLHLS at 46.3%) drove the model to systematically over-predict a low-event-rate target cohort (MHAS 10.2%). After L1 adjustment IPA rose to 0.063, but the calibration slope remained 0.686 (well below 1.0), indicating that MHAS required L2 slope recalibration to achieve acceptable absolute accuracy. This result shows that when training-set event-rate composition is highly unbalanced, pooled training may simultaneously introduce slope drift, necessitating higher-level recalibration; L1 alone is insufficient in this case.

---

## 4.4 Expanding the Training Set Did Not Improve Cross-Cohort Transferability (H3: Null Result and Its Implications)

The non-support of H3 is the most theoretically challenging null finding of this study. Intuitively, extending the training data from a single Chinese cohort (CHARLS) to multiple Asian cohorts might be expected to improve the model's adaptability to new populations. However, down-sampling bootstrap analysis (200 replications, reduced to CHARLS size to exclude the sample-size confound) showed that adding a second Asian cohort changed C-index by only ±0.001 (Round B +0.001, Round C −0.001), well below the 0.02 clinical relevance threshold and without a stable direction.

This result exposes a fundamental epistemological constraint on cross-cohort prediction modelling: training-set diversity can improve generalisation across the training distribution, but when the target cohort has structural differences from the training set through measurement non-equivalence, adding more training cohorts cannot compensate. The 41 FI deficits are operationalised across cohorts through different instruments, cut-points and linguistic contexts; the same deficit label may encode subtly different health concepts in different cohorts. The H4 finding reinforces this point: calibration failure is primarily driven by target-cohort event-rate drift — an intrinsic property of the target population that cannot be avoided by training-set selection.

The practical implication for resource allocation in multi-centre ageing research is direct: rather than investing heavily in incorporating more cohorts into joint training to improve model transportability, it is more efficient to collect a small amount of data in the target population for L1 recalibration. L1 requires only the target population's baseline four-year mortality rate — a readily available figure — and demonstrated substantial calibration improvement (SHARE: IPA 0.028 → 0.114). This strategy deserves serious consideration in future international multi-cohort research frameworks.

---

## 4.5 Cross-Cohort Heterogeneity in Feature Importance (H6: Exploratory Analysis)

Cohort-specific logistic models on FI_core (19 strictly common items) plus age showed that **age ranked first in all six cohorts** (H6 criterion 1: met), and self-rated health (`shlt`) was the most consistently top-ranked FI item (top 3 in CHARLS, HRS, SHARE and MHAS). However, the importance rankings of individual FI_core items showed substantial cross-cohort heterogeneity: the median pairwise Spearman rank correlation across the six cohorts was 0.41 (range 0.10–0.67), falling well short of the pre-registered H6 threshold of 0.70 (H6 criterion 2: not met). H6 is therefore partially supported.

The consistent dominance of age is biologically expected: the age–mortality relationship is the strongest and most robust predictive association in virtually all human populations. More scientifically informative is the cross-cohort heterogeneity in individual deficit importance. The particularly low Spearman correlations for KLoSA versus other cohorts (KLoSA–CHARLS: 0.099; KLoSA–HRS: 0.096) are attributable to the demographic profile of the KLoSA 60+ sample: this community-dwelling Korean cohort was relatively young (median ~71 years), ADL positive rates were only 2–7% (dressing, toileting near floor effects), reducing the relative statistical weight of ADL items in modelling; food preparation difficulty (`mealsa`, ranked 2nd in KLoSA) and cancer (`cancre`, ranked 3rd) gained relative importance. This pattern resembles CLHLS (`mealsa` also 2nd), suggesting that in cohorts with generally low functional impairment rates, difficulty with meal preparation is a particularly prominent mortality predictor.

An important scope caveat applies to this analysis: standardised coefficient magnitudes (|β_standardised|) served as the feature importance proxy, consistent with the linear logistic framework of the main model. This measure is insensitive to non-linear contributions and interaction effects; results should be treated as exploratory rather than definitive. SHAP values from non-linear models (e.g., gradient boosting) may reveal more nuanced contribution patterns and represent a natural extension for future work.

---

## 4.6 Comparative Cross-Cohort Stability of FI and Intrinsic Capacity (H5: Supplementary Analysis)

As a pre-specified supplementary analysis, we compared the cross-cohort C-index shift magnitude between FI (Model B: `event ~ fi_full + age`) and the WHO Intrinsic Capacity (IC) five-domain framework (Model C: `event ~ IC five domains + age`) in the CHARLS → CLHLS framework. FI showed |ΔC| = 0.052 versus IC's |ΔC| = 0.095, indicating a smaller cross-cohort shift for FI — supporting H5 (FI has greater cross-cohort discriminative stability than IC).

However, this conclusion must be read under three important caveats. First, **CLHLS IC measurements are binary proxies**: because continuous physical performance and cognitive test scores could not be extracted from CLHLS raw files in real time, the five IC domains were represented using binary FI items as proxies for continuous measures (grip strength, gait speed, peak flow, cognitive scores, etc.); this may artificially amplify IC's apparent instability in CLHLS and therefore overestimate IC's cross-cohort instability relative to FI. Second, **the two models start from different baselines**: CHARLS internal C was 0.761 for FI versus 0.711 for IC, a gap of ~0.05; direct comparison of |ΔC| is somewhat ambiguous when internal baselines differ. Third, **C-index increased for both models in CLHLS** (FI: 0.761 → 0.813; IC: 0.711 → 0.806), partly reflecting the mechanical C-statistic amplification in a high-event-rate cohort (46.3% vs. 10.2%) rather than a genuine improvement in transportability.

In summary, the current H5 results provide preliminary supporting evidence that FI has greater cross-cultural discriminative stability than IC. A complete test — including external validation with continuous IC measures in CLHLS and systematic multi-cohort comparison — will be the central research question of Paper 2 (decision D-012).

---

## 4.7 Clinical and Public Health Implications

The findings carry practical relevance at three levels.

**Global utility without retraining**: The 41-item Gateway-harmonised FI maintained C-index > 0.72 across East Asia (CHARLS, CLHLS, KLoSA), North America (HRS), Europe (SHARE) and Latin America (MHAS) without any retraining — a range of five distinct cultural and healthcare contexts. This means FI can serve as a cross-nationally comparable standardised frailty screening tool, drawing on data already collected in existing ageing surveys without additional dedicated measurement.

**Low-cost local recalibration with high yield**: L1 intercept recalibration — requiring only an estimate of the target population's four-year mortality rate — produced substantial calibration gains. SHARE IPA rose from marginal (0.028) to substantive (0.114); the operational threshold is minimal. Where small-scale validation data can be collected in the target population, L2 slope recalibration further improves absolute risk accuracy (MHAS IPA: 0.063 → 0.082), but L1 is adequate for most settings.

**Prediction, not intervention**: This model is a pure predictive instrument and makes no causal claims. FI is a composite indicator of multi-system health status, not a single modifiable risk factor.[REF-18] Clinical use should be confined to risk stratification in conjunction with clinical judgement and patient preferences; the model should not be used alone to drive treatment decisions.

---

## 4.8 Limitations

The study has eight principal limitations.

(1) **FI items are not fully equivalent across cohorts**: MHAS had only 27 of 41 canonical stems; HRS was missing 8 items (including BMI and memory self-rating), substituted by documented proxy variables; dyslipidaemia and kidney disease used measurement-behaviour proxies rather than diagnosis variables. These differences may affect the cross-cohort comparability of absolute FI values.

(2) **Incomplete CHARLS cross-wave ID linkage**: The householdID-based bridging rule yielded linkage rates of 85.5% (2015 wave) and 81.3% (2018 wave); approximately 14–19% of participants could not have follow-up status confirmed, potentially introducing selective attrition bias.

(3) **Education not adjusted in the primary model**: Education was available in all six cohorts (100% linkage, 0.00–0.53% missing), but was excluded from the primary model to preserve the pre-registered specification, since the availability audit post-dated outcome unblinding. Post hoc sensitivity analysis SA-3 showed that adding education left Aim 1 performance essentially unchanged (ΔC = −0.0009, ΔO:E = −0.0067), indicating the FI already captures most of the education-related mortality signal. Two caveats remain: harmonising the three survey-specific education scales (CHARLS 11-level, CLHLS years-of-schooling, KLoSA 4-level) to the ISCED 3-level standard required judgement calls made after unblinding — notably the classification of CHARLS *sishu* (traditional Chinese tutoring, no direct ISCED equivalent), the collapsing of illiterate and semi-literate categories, and the year cut-points for CLHLS, whose oldest members were schooled under pre-1949 systems; and residual confounding by other socioeconomic dimensions (income, occupation, wealth) was not examined.

(4) **22.9% missing outcome in CLHLS**: Although the IPCW sensitivity analysis demonstrated that complete-case results are robust to informative censoring (ΔC = +0.0008), this missingness rate exceeds the 10% standard warning threshold and must be explicitly acknowledged.

(5) **CLHLS IC measurements are binary proxies in H5**: The current H5 conclusion is exploratory; full validation with continuous IC measurements is deferred to Paper 2.

(6) **Highly unbalanced event rates in the Asian training pool**: CLHLS event rate (46.3%) greatly exceeds CHARLS (10.2%) and KLoSA (9.6%); CLHLS dominates the pooled mean, potentially introducing slope drift — confirmed by MHAS post-L1 slope of 0.686.

(7) **Non-causal framework**: FI coefficients in this study should not be interpreted as causally modifiable effect sizes.

(8) **European validation excludes the United Kingdom**: ELSA was removed from Aim 3 because its follow-up death records covered only through 2012, yielding zero events in the required 2012–2016 window (decision D-013). European validation therefore relies entirely on SHARE; conclusions cannot be directly generalised to older adults in the United Kingdom.

---

## 4.9 Strengths

The study has four principal strengths. (1) **Scale and geographic coverage**: 76,074 complete-case participants aged ≥60 years and 10,790 four-year deaths across six countries/regions spanning East Asia, North America, Europe and Latin America — one of the largest cross-cultural FI mortality prediction studies to date. (2) **Pre-registration and outcome blinding**: All analytic decisions were locked in the SAP before any outcome–predictor analyses (commit 9bc7b85), with a complete decision audit trail (D-001 to D-034) satisfying the TRIPOD+AI and PROBAST-AI audit-trail requirements. (3) **Attribution-decomposition recalibration framework**: The L0–L3 ladder decomposes performance loss into attributable event-rate drift (L1), slope drift (L2) and parameter heterogeneity (L3), providing an operationally useful methodological reference for cross-cultural model transfer research. (4) **Open data and full reproducibility**: All six cohorts are available through official application; the full analytic codebase is publicly archived on GitHub with complete version-controlled reproducibility.

---

*English draft completed: 2026-07-30*
*Source: `paper_discussion_draft_2026-07-30.md` (post-correction: event total 10,790; KLoSA feature interpretation corrected)*
