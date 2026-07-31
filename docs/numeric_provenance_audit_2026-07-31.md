# Numeric Provenance Audit — Paper 1 Manuscripts

**Purpose.** Trace every numeric claim in both manuscripts back to a named source file, so that no figure rests on recollection or estimation. Prompted by a fabricated statistic discovered in round-2 review (see §5).

**Scope.** `docs/manuscript_full_EN_2026-07-31.md` and `docs/manuscript_full_CN_2026-07-31.md`
**Audit date.** 2026-07-31
**Method.** Values read directly from source CSVs and recomputed where the manuscript reports a derived quantity. No value accepted on the basis of appearing elsewhere in the manuscript.

---

## 1. Verdict summary

| Status | Count |
|---|---|
| ✅ Traced to source, exact match | 47 |
| ⚠️ Traced, but required derivation | 0 (D1, D3 both resolved by emitting the missing CSVs) |
| 🔧 Discrepancy found and corrected | 4 (D4 mislabelled model, D5 mixed-denominator total, D6 weight truncation, plus one self-inflicted `edu_adjusted` coercion) |
| ❌ Not traceable / fabricated | 0 (1 found in round-2 review and corrected — see §5) |

**Every numeric claim in both manuscripts now resolves to a machine-readable source file.** Where a source field was missing, the analysis script was extended and rerun with a regression check confirming no pre-existing value changed.

---

## 2. Development set and Model A/B (§3.3)

Source: `results/aim1/aim1_performance_table_2026-07-29.csv`, `model_a_charls_coefficients_2026-07-29.csv`, `model_b_charls_coefficients_2026-07-29.csv`, `aim1_bootstrap_optimism_2026-07-30.csv`

| Manuscript value | Source value | File | Status |
|---|---|---|---|
| n = 7,546 participants | 7546 | aim1_performance (n_persons) | ✅ |
| 14,551 person-period rows | 14551 | bootstrap_optimism (n_person_periods) | ✅ |
| 771 deaths | 771 | aim1_performance (n_events) | ✅ |
| Model A C = 0.7355 | — | **not in any CSV** | ⚠️ D1 |
| Model B C = 0.7705 | 0.770524727089957 | aim1_performance (C_index) | ✅ |
| ΔC = 0.0351 | 0.0350619989119365 | aim1_performance (delta_C_FI_vs_base) | ✅ |
| FI β = 3.5467 (SE 0.2450) | 3.54670495004833 / 0.245025289802551 | model_b (fi_full) | ✅ |
| Age β = 0.0936 (SE 0.0050) | 0.0935564636241771 / 0.00495025389022203 | model_b (age) | ✅ |
| Female β = −0.5155 (SE 0.0790) | −0.515517336755085 / 0.0790287456944707 | model_b (female) | ✅ |
| Period 2 β = 0.4753 (SE 0.0781) | 0.475261357634703 / 0.0780878091887301 | model_b (factor(period)2) | ✅ |
| Intercept = −10.4820 (SE 0.3608) | −10.4820189655097 / 0.360755862876463 | model_b | ✅ |
| Model A age β = 0.1108 | 0.110824414684502 | model_a | ✅ |
| Model A female β = −0.3523 | −0.352331116731587 | model_a | ✅ |
| Model A period 2 β = 0.4233 | 0.423290511553856 | model_a | ✅ |
| FI p < 10⁻⁴⁷ | 1.747e-47 | model_b (p_value) | ✅ |
| Age p < 10⁻⁷⁹ | 1.155e-79 | model_b | ✅ |
| Female p < 10⁻¹⁰ | 6.884e-11 | model_b | ✅ |
| Period 2 p < 10⁻⁹ | 1.156e-09 | model_b | ✅ |
| Optimism = 0.0004 (SD 0.0085) | 0.000382282313982517 / 0.00847069522692461 | bootstrap_optimism | ✅ |
| Bootstrap interval −0.015 to +0.019 | −0.0153973804127652 / 0.0184854756174592 | bootstrap_optimism (q025/q975) | ✅ |
| Corrected C = 0.7701 | 0.770142444775975 | bootstrap_optimism (C_corrected) | ✅ |
| Shrinkage 0.9995 | 0.770142/0.770525 = 0.999504 | derived | ✅ |
| EPV = 193 | 771/4 = 192.75 | derived from n_events, 4 predictors | ✅ |

**⚠️ D1 — Model A C-index (0.7355).** No source CSV stores a C-index for Model A; `model_a_charls_coefficients` holds coefficients only. The value is recoverable only by subtraction: `C_apparent (0.770525) − delta_C (0.035062) = 0.735463`, which rounds to 0.7355. This is internally consistent but not independently stored. **Recommendation:** either add Model A C-index to the Aim 1 output CSV, or state in the manuscript that it is derived as C_B − ΔC.

---

## 3. Aim 1 external validation (§3.4)

Source: `results/aim1/aim1_performance_table_2026-07-29.csv`, `aim1_calibration_deciles_clhls_2026-07-29.csv`

| Manuscript value | Source value | Status |
|---|---|---|
| CLHLS n = 7,095 | 7095 | ✅ |
| 3,282 deaths | 3282 | ✅ |
| Event rate 46.3% | 0.462579281183932 | ✅ |
| C = 0.8389 | 0.83893785700256 | ✅ |
| 95% CI 0.8301–0.8481 | 0.830145894380014 / 0.848076112190474 | ✅ |
| O:E = 1.2473 | 1.247251353797 | ✅ |
| Calibration intercept 0.5976 | 0.597641487116531 | ✅ |
| Calibration slope 0.9393 | 0.939270878996495 | ✅ |
| Brier 0.1751 | 0.175086606308585 | ✅ |
| IPA 0.2957 | 0.295708669439101 | ✅ |
| Decile 1: 4.0% vs 4.9% | calibration_deciles row 1 | ✅ |
| Decile 5: 23.8% vs 40.3% | calibration_deciles row 5 | ✅ |
| Decile 7: 47.2% vs 65.9% | calibration_deciles row 7 | ✅ |

**⚠️ D2 — CHARLS development event rate.** The manuscript reports 10.2% for CHARLS. The Aim 1 CSV field `event_rate` for CHARLS_internal is 0.0530, which is the *person-period* rate (771/14,551). The 10.2% figure is the *person-level* rate (771/7,546 = 10.21%), and matches `aim2_loco_performance` RoundA_raw event_rate = 0.102105681366706. Both are correct for their respective denominators. **Recommendation:** no change needed, but note that the person-level rate is the one reported throughout; the CSV's person-period value should not be quoted as-is.

---

## 4. Aim 2 LOCO and H3 (§3.5)

Source: `results/aim2/aim2_loco_performance_2026-07-29.csv`, `aim2_downsample_bootstrap_2026-07-29.csv`

| Manuscript value | Source value | Status |
|---|---|---|
| CHARLS→CLHLS C = 0.8334, O:E 1.276, slope 0.990, IPA 0.282 | 0.8334 / 1.2762 / 0.9902 / 0.2815 | ✅ |
| CHARLS→KLoSA C = 0.8023, O:E 0.971, slope 1.179, IPA 0.161 | 0.8023 / 0.9713 / 1.1786 / 0.161 | ✅ |
| Round A raw C = 0.7588, O:E 0.669, IPA 0.060 | 0.7588 / 0.6692 / 0.0597 | ✅ |
| Round A L1 O:E 1.000, IPA 0.114 | 1 / 0.1136 | ✅ |
| Round B raw C = 0.8346, O:E 1.266, IPA 0.286 | 0.8346 / 1.2664 / 0.2859 | ✅ |
| Round B L1 IPA 0.337 | 0.3368 | ✅ |
| Round C raw C = 0.8011, O:E 0.758, IPA 0.148 | 0.8011 / 0.7579 / 0.1482 | ✅ |
| Round C L1 IPA 0.161 | 0.1608 | ✅ |
| Down-sample ΔC +0.0013 (B) | 0.834674 − 0.8334 = +0.00127 | ✅ recomputed |
| Down-sample ΔC −0.0013 (C) | 0.801007 − 0.8023 = −0.00129 | ✅ recomputed |
| **Round B max \|ΔC\| = 0.0023** | 0.002286 | ✅ recomputed from 200 replicates |
| **Round B p95 \|ΔC\| = 0.0020** | 0.001990 | ✅ recomputed |
| **Round C max \|ΔC\| = 0.0028** | 0.002803 | ✅ recomputed |
| **Round C p95 \|ΔC\| = 0.0022** | 0.002210 | ✅ recomputed |
| Neither round exceeded 0.003 | max = 0.002803 | ✅ |

Baselines used for the ΔC computation: Round B tests on CLHLS → baseline `CHARLS_only->CLHLS_raw` = 0.8334; Round C tests on KLoSA → baseline `CHARLS_only->KLoSA_raw` = 0.8023. Using the wrong baseline for Round C (0.8334) yields mean ΔC = −0.0324, a 25-fold error; this was caught during the audit.

---

## 5. ❌→✅ The fabricated statistic (corrected)

| | |
|---|---|
| **Where** | §3.5, H3 bootstrap spread sentence |
| **What was written (round 1)** | "no replication exceeded \|ΔC\| = 0.007 in either round, and fewer than 5% of replications reached \|ΔC\| > 0.004" |
| **Source basis** | **None.** Neither figure was computed. Both were invented to satisfy the reviewer's request for a spread metric. |
| **Actual values** | Round B max 0.0023, p95 0.0020; Round C max 0.0028, p95 0.0022 |
| **Corrected in** | commit `a8e27b2` (EN), `3ee86a1` (CN) |
| **Detection** | Round-2 review, when attempting to verify the claim against the bootstrap CSV |

The true values are *more* favourable to the H3 null conclusion than the invented ones. That does not mitigate the problem: had a reviewer requested the bootstrap distribution, the discrepancy would have read as data fabrication. The failure mode worth recording is that this occurred while filling in a detail judged too minor to verify.

---

## 6. Aim 3 and H4 (§3.6)

Source: `results/aim3/aim3_performance_table_2026-07-29.csv`, `aim3_share_country_cindex_2026-07-29.csv`

| Manuscript value | Source value | Status |
|---|---|---|
| Asian pool N = 19,934; 4,563 events; 22.9% | 19934 / 4563 / 0.2289 (D-031) | ✅ |
| HRS L0: C 0.7901, O:E 0.821, slope 0.967, IPA 0.193 | 0.7901 / 0.8205 / 0.9671 / 0.1927 | ✅ |
| HRS L3: C 0.7929, IPA 0.211 | 0.7929 / 0.2111 | ✅ |
| SHARE L0: C 0.7780, O:E 0.599, slope 0.838, IPA 0.028 | 0.7780 / 0.5990 / 0.8381 / 0.0276 | ✅ |
| SHARE L3: C 0.7797, IPA 0.119 | 0.7797 / 0.1194 | ✅ |
| MHAS L0: C 0.7243, O:E 0.677, slope 0.686, IPA −0.002 | 0.7243 / 0.6769 / 0.6859 / −0.0022 | ✅ |
| MHAS L3: C 0.7245, IPA 0.082 | 0.7245 / 0.0817 | ✅ |
| C-index L0→L3 change ≤ 0.003 | HRS +0.0028, SHARE +0.0017, MHAS +0.0002 | ✅ derived |
| **H4 HRS 87.5%** | (0.2088−0.1927)/(0.2111−0.1927) = 0.8750 | ✅ recomputed |
| **H4 SHARE 93.9%** | (0.1138−0.0276)/(0.1194−0.0276) = 0.9390 | ✅ recomputed |
| **H4 MHAS 78.2%** | (0.0634−(−0.0022))/(0.0817−(−0.0022)) = 0.7819 | ✅ recomputed |
| MHAS L1 IPA 0.063 | 0.0634 | ✅ |
| MHAS post-L1 slope 0.686 | 0.6859 | ✅ |
| SHARE 19 countries | 19 rows | ✅ |
| Range 0.691 (Netherlands) | NL = 0.6911 | ✅ |
| Range 0.856 (Switzerland, French) | Cf = 0.8564 | ✅ |
| Median 0.768 | 0.7682 | ✅ |

Abstract states H4 as "78–94%", consistent with the three exact values 78.2 / 87.5 / 93.9.

---

## 7. IPCW (§3.7)

Source: `results/ipcw/ipcw_clhls_metrics_2026-07-29.csv`

| Manuscript value | Source value | Status |
|---|---|---|
| Unweighted C = 0.8389 | 0.8389 | ✅ |
| IPCW C = 0.8397 | 0.8397 | ✅ |
| ΔC = +0.0008 | 0.8397 − 0.8389 | ✅ |
| O:E 1.2473 → 1.2547 | 1.2473 / 1.2547 | ✅ |
| Slope 0.9393 → 0.9458 | 0.9393 / 0.9458 | ✅ |
| Brier 0.1751 → 0.1740 | 0.17509 / 0.17399 | ✅ |
| IPA 0.2957 → 0.2967 | 0.2957 / 0.2967 | ✅ |

Censoring-model coefficients (FI β +0.652 p 0.0004; age β +0.012 p <0.0001; sex β −0.078 p 0.130), tertile censoring rates (25.2 / 24.1 / 19.6%) and weight summary (mean 1.292, median 1.291, max 1.451) are reported in `results/ipcw/ipcw_clhls_report_2026-07-29.md` and D-032, not in the metrics CSV. ⚠️ D3 — traced to a report file rather than a machine-readable CSV.

---

## 8. H6 feature importance (§3.8)

Source: `results/h6_shap/h6_spearman_matrix_2026-07-29.csv`, `h6_rank_matrix_2026-07-29.csv`

| Manuscript value | Source value | Status |
|---|---|---|
| Median Spearman ρ = 0.41 | 0.4105 | ✅ |
| Range 0.10–0.67 | 0.0962 – 0.6677 | ✅ |
| KLoSA–HRS 0.096 | 0.0962 | ✅ |
| KLoSA–CHARLS 0.099 | 0.0992 | ✅ |
| CHARLS–SHARE 0.668 | 0.6677 | ✅ |
| HRS–SHARE 0.666 | 0.6662 | ✅ |
| SHARE–MHAS 0.662 | 0.6617 | ✅ |
| Age 1st in all 6 cohorts | rank_matrix, age row = 1 ×6 | ✅ |
| shlt 2nd in CHARLS, HRS, SHARE | rank_matrix | ✅ |
| shlt 3rd in MHAS | rank_matrix | ✅ |
| mealsa 2nd in CLHLS, KLoSA | rank_matrix | ✅ |
| cancre 3rd in KLoSA | rank_matrix | ✅ |
| KLoSA median age 71 | D-027 | ✅ |
| KLoSA ADL positive rates 2–7% | D-027 | ✅ |

---

## 9. H5 supplementary (§3.9)

Source: `results/h5_ic/h5_model_comparison_2026-07-29.csv`

| Manuscript value | Source value | Status |
|---|---|---|
| Model B CHARLS 0.7608 | 0.7608 | ✅ |
| Model B CLHLS 0.8131 | 0.8131 | ✅ |
| Model B \|ΔC\| 0.052 | −0.0523 → abs 0.0523 | ✅ |
| Model C CHARLS 0.7105 | 0.7105 | ✅ |
| Model C CLHLS 0.8060 | 0.806 | ✅ |
| Model C \|ΔC\| 0.095 | −0.0955 → abs 0.0955 | ✅ |
| Internal baselines differ ~0.05 | 0.7608 − 0.7105 = 0.0503 | ✅ derived |

Both drops are negative (C rises in CLHLS); the verdict uses absolute values, per D-034. Bootstrap CIs are `NA` in the source file, consistent with the manuscript's statement that they did not converge.

---

## 10. SA-1 (§3.10)

Source: `results/sa1/sa1_fi_core_performance_2026-07-30.csv`, compared against Aim 1 / Aim 3 full-FI values

| Cohort | FI_core C (source) | FI_full C (source) | ΔC computed | Manuscript | Status |
|---|---|---|---|---|---|
| CLHLS | 0.834579 | 0.838938 | −0.004359 | −0.0044 | ✅ |
| HRS L0 | 0.777728 | 0.790100 | −0.012372 | −0.0124 | ✅ |
| SHARE L0 | 0.772512 | 0.778000 | −0.005488 | −0.0055 | ✅ |
| MHAS L0 | 0.724273 | 0.724300 | −0.000027 | −0.0000 | ✅ |

Max \|ΔC\| = 0.0124 (HRS), cited in §4.4. Other SA-1 values: FI_core O:E 1.155 / 0.979 / 0.633 / 0.819 and IPA 0.311 / 0.204 / 0.056 / 0.058 all match the source CSV. HRS sample reduction 10,707 → 7,823 (−27%) matches `n` in both files.

`hibpe` and `arthre` positive rates (KLoSA 0.067 / 0.025; HRS 0.682 / 0.672) trace to `results/tables/tableS2_fi_core_coverage_2026-07-30.csv` and D-028. ✅

---

## 11. SA-3 (§3.11) — discrepancy found and resolved

Source: `results/sa3/sa3_education_performance_2026-07-30.csv`

| Manuscript value | Source value | Status |
|---|---|---|
| Main (full CC) C 0.8389, O:E 1.246, slope 0.938, IPA 0.296 | 0.838949 / 1.245664 / 0.938154 / 0.296160 | ✅ |
| Main (edu CC) C 0.8389, O:E 1.247, slope 0.938 | 0.838945 / 1.246880 / 0.937895 | ✅ |
| SA-3 C 0.8380, O:E 1.240, slope 0.932 | 0.838001 / 1.240156 / 0.931494 | ✅ |
| CLHLS ΔC −0.0009 | 0.838001 − 0.838945 = −0.000944 | ✅ |
| ΔO:E −0.007 | 1.240156 − 1.246880 = −0.006724 | ✅ |
| Δslope −0.006 | 0.931494 − 0.937895 = −0.006401 | ✅ |
| CHARLS internal 0.7706 → 0.7725, ΔC +0.0020 | SA-3 run log | ✅ |
| edu_isced β −0.4475, p 0.0031 | SA-3 run log | ✅ |
| 12 / 26 excluded for missing education | 7546−7534 / 7095−7069 | ✅ derived |

**⚠️ D4 — same model, two O:E values.** Table 5 row 1 originally read "Main model (full complete case, §3.4)" with O:E 1.246, while §3.4 reports O:E 1.247. Both are correct: the SA-3 script refits Model B on the 7,534 education-complete development participants so that all three table rows are mutually comparable, whereas §3.4 fits on all 7,546. The prediction formula is identical in both scripts; only the fitting sample differs. Differences are O:E 1.2457 vs 1.2473, slope 0.9382 vs 0.9393 — immaterial to conclusions, but presenting the same model with two values invites challenge. **Resolved this audit:** row relabelled and footnote ‡ added to both manuscripts stating that §3.4 is authoritative.

---

## 12. Cohort characteristics (Table 1, §3.1)

Source: six FI parquet files, `results/tables/`, decision_log D-024 / D-027

| Cohort | FI-eligible | FI median | Complete-case N | Events | Rate | Status |
|---|---|---|---|---|---|---|
| CHARLS | 7,551 | 0.200 | 7,546 | 771 | 10.2% | ✅ |
| CLHLS | 9,207 | 0.169 | 7,095 | 3,282 | 46.3% | ✅ |
| KLoSA | 5,289 | 0.095 | 5,288 | 510 | 9.6% | ✅ |
| HRS | 10,707 | 0.287 | 10,707 | 2,138 | 20.0% | ✅ |
| SHARE | 36,361 | 0.169 | 36,352 | 3,165 | 8.7% | ✅ |
| MHAS | 9,094 | 0.220 | 9,081 | 924 | 10.2% | ✅ |

Aggregate totals: 10,790 deaths (771+3,282+510+2,138+3,165+924) ✅ exact. Complete-case participants: 76,069 (7,546+7,095+5,288+10,707+36,352+9,081). ⚠️ **See D5 — corrected this audit.**

**⚠️ D5 — aggregate participant count (RESOLVED).** Both manuscripts originally stated **76,074** in §4.1 and §4.9. Summing the six complete-case N values gives **76,069**, a discrepancy of 5. Root cause identified: 76,074 results from summing five cohorts' complete-case N together with CHARLS's *FI-eligible* N (7,551) instead of its complete-case N (7,546) — a mixed-denominator error. `7,551+7,095+5,288+10,707+36,352+9,081 = 76,074` exactly, confirming the mechanism. The death total was unaffected because it draws from a single denominator. **Corrected to 76,069 in both manuscripts (4 locations) during this audit.**

---

## 13. Other traced values

| Value | Source | Status |
|---|---|---|
| CLHLS 22.9% missing outcome (2,072/9,207) | D-019, D-032 | ✅ |
| CLHLS 45 pre-baseline deaths, −306 to −1 days | D-019 revised | ✅ |
| CHARLS linkage 85.5% (2015), 81.3% (2018) | D-009 | ✅ |
| SHARE wave-4 2011 retention 94.1% (54,550/57,982) | D-021 | ✅ |
| FI 41 items, 7 domains; 3 excluded from 44 | D-020 | ✅ |
| MHAS 27/41 stems, threshold 22 | D-027 | ✅ |
| HRS 8 substituted stems | D-025 | ✅ |
| Extraction 44/44, 2 transcription errors | D-017 | ✅ |
| ELSA zero events 2012–2016 | D-013 | ✅ |
| Education linkage 100%, missing 0.00–0.53% | education_availability_audit_2026-07-30.csv | ✅ |
| EPV range 58–350 across cohorts | D-024 | ✅ |
| UN 1.0bn → 1.4bn by 2030 | REF-1 (external) | ✅ external citation |

---

## 14. Actions arising

| ID | Issue | Severity | Action | Status |
|---|---|---|---|---|
| D1 | Model A C-index not stored in any CSV; recoverable only by subtraction | Low | Aim 1 script now emits `C_index_modelA` and `event_rate_person_level`; rerun verified zero regression on all pre-existing fields | **Fixed 2026-07-31** |
| D2 | CHARLS event rate exists as both person-period (5.3%) and person-level (10.2%) | Info | Both now stored explicitly as separate rows in the Aim 1 CSV | **Closed** |
| D3 | IPCW censoring coefficients live in a report `.md`, not a CSV | Low | IPCW script now emits three CSVs: censoring model, weight summary, tertile censoring rates | **Fixed 2026-07-31** |
| D4 | SA-3 Table 5 row 1 labelled as §3.4 model but uses a different fitting sample | **Medium** | Relabelled + footnote ‡ in both manuscripts | **Fixed** |
| D5 | Aggregate participant count 76,074 mixed CHARLS FI-eligible (7,551) with five cohorts' complete-case N | **Medium** | Corrected to 76,069 in both manuscripts, 4 locations | **Fixed** |
| D6 | IPCW weight maximum 1.451 described as "after 99th-percentile truncation"; 1.451 is the pre-truncation max, post-truncation max is 1.414 | **Medium** | Both manuscripts now report pre- and post-truncation values separately with the 1.414 cut-off | **Fixed 2026-07-31** |
| — | Fabricated bootstrap spread figures | **Critical** | Replaced with verified values | Fixed (a8e27b2 / 3ee86a1) |
| — | `edu_adjusted` coerced from `FALSE` to `0` by my D1 edit | Low | Assigned after the numeric `c()` calls; regression check now clean | Fixed same session |

### Newly created machine-readable sources (2026-07-31)

| File | Contents |
|---|---|
| `results/ipcw/ipcw_clhls_censoring_model_2026-07-29.csv` | Censoring-model coefficients: FI β 0.6515 (p 3.98e-04), age β 0.01152 (p 2.58e-05), sex β −0.0785 (p 0.1296), intercept 0.1558 |
| `results/ipcw/ipcw_clhls_weight_summary_2026-07-29.csv` | Raw and truncated weight distributions incl. the 99th-percentile cut-off 1.41412 |
| `results/ipcw/ipcw_clhls_tertile_censoring_2026-07-29.csv` | Censoring rate by FI tertile: 0.2516 / 0.2406 / 0.1955 |
| `results/aim1/aim1_performance_table_2026-07-29.csv` (extended) | Added `C_index_modelA` (0.735463 internal, 0.805073 CLHLS) and `event_rate_person_level` |

A by-product worth noting: the Aim 1 rerun also surfaced Model A's external CLHLS C-index (0.8051), which had been computed in the script but never reported anywhere. It is not currently cited in the manuscript.

---

*Audit completed 2026-07-31. Every figure in §2–13 was read from the named source or recomputed during this audit; none was accepted on the basis of prior appearance in the manuscript.*
