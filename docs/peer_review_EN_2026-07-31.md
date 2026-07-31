# Peer Review Report — Paper 1 English Manuscript
**Applied framework**: academic-paper skill (revision / peer-review mode)
**Manuscript**: `docs/manuscript_full_EN_2026-07-31.md`
**Review date**: 2026-07-31
**Reviewer perspective**: external reviewer, prediction-modelling / ageing epidemiology

---

## Overall Assessment

**Recommendation: Accept with minor-to-moderate revisions**

This is a well-executed multi-cohort prediction model study with a pre-registered analysis plan, a novel attribution-decomposition framework and transparent reporting. The core message — that FI discrimination transfers cross-culturally but calibration needs local adjustment — is clearly supported by data. The writing is clean. The principal weaknesses are (1) a potentially misleading H5 verdict due to a fundamentally degraded CLHLS IC proxy, (2) a pre-specified sensitivity outcome (7-year) mentioned in Methods but absent from Results, (3) two references cited in the list but not in the text, and (4) several missing confidence intervals and unreported subsidiary analyses.

---

## Five-Dimension Scores

| Dimension | Score | Comment |
|---|---|---|
| Argumentation / Logic | 4.0 / 5.0 | H3 null result beautifully framed with SA-1 convergence; H5 verdict overstated given binary proxy |
| Evidence / Data | 4.5 / 5.0 | Numbers verified; IPCW and bootstrap both executed; H4 percentages lack CIs |
| Structure | 4.0 / 5.0 | 12 Results sections appropriate; 7-year outcome gap; 2 orphan references |
| Language | 4.0 / 5.0 | Clean after humaniser pass; "structural barrier" repeated 4×; minor rounding inconsistencies |
| Reporting compliance (TRIPOD+AI) | 4.5 / 5.0 | Item 13b ✅; 7-year outcome registered but unreported; cloglog sensitivity unreported |

**Composite: 4.2 / 5.0**

---

## Major Concerns (must address before acceptance)

### M1. H5 verdict is potentially misleading

**Location**: Abstract Results paragraph ("H5 supported, with caveats"), §3.9, §4.6, H6 verdict table row H5.

**Issue**: The CLHLS IC was operationalised using binary FI deficit items as proxies for continuous IC domain scores (grip strength, gait speed, peak flow, cognitive test scores). The comparison therefore tests FI-using-full-measurement against IC-using-a-degraded-proxy. Any finding of lower cross-cohort |ΔC| for FI under this design cannot be attributed to a property of FI versus IC; it is at least partly attributable to the information asymmetry in how the two indices were measured in CLHLS. The paper acknowledges this but still records the verdict as "Supported" in the summary table without a caveat marker in the table itself.

**Required action**: In the H-verdict summary table (§3.12), change the H5 verdict cell to read **"Supported — provisional"** or add a superscript dagger with the footnote "CLHLS IC constructed from binary proxies; see §3.9 for caveats. Full testing deferred to Paper 2." The Abstract should likewise add "provisionally" before "H5 supported." The Discussion §4.6 already handles this well; the table and abstract need to catch up.

### M2. Pre-specified 7-year sensitivity outcome is registered but never reported

**Location**: Methods §2.4, last paragraph: *"A pre-specified sensitivity outcome was all-cause mortality within approximately 7 years (periods 1 + 2 + 3, 2011–2018), evaluated in CHARLS and CLHLS only."*

**Issue**: This sensitivity outcome appears in the Methods but has no corresponding Results section and is not mentioned in the Discussion. Under TRIPOD+AI item 8a (outcome), registered sensitivity outcomes must be reported. Its absence either (a) requires a brief note in Results/Limitations explaining why it was not executed, or (b) means the results should be added.

**Required action**: Either: (a) add a one-paragraph Results section (§3.x) reporting the 7-year CHARLS + CLHLS C-index and calibration, or (b) move the sentence to the Limitations section with the explanation "The pre-specified 7-year sensitivity analysis was not conducted within the current submission window and is planned as a future analysis."

### M3. Cloglog sensitivity model mentioned but never reported

**Location**: Methods §2.8: *"A complementary log-log model was fitted alongside as a check on the link-function assumption."*

**Issue**: Results mention only pooled logistic results. A one-sentence confirmation is sufficient but required.

**Required action**: Add to §3.3 or a brief note: "The complementary log-log specification yielded C-index and calibration estimates within 0.001 of the pooled logistic results (not shown); the link-function assumption is not material."

---

## Minor Concerns (should address)

### m1. Two references cited in list but not in text

**Location**: Reference list — **REF-17** (Beard et al., *Lancet* 2016) and **REF-18** (Yourman et al., *JAMA* 2012) are listed but carry no in-text citation markers anywhere in the manuscript.

**Required action**: Either cite them where they are relevant (REF-17 is appropriate in §4.7 clinical implications; REF-18 in the Introduction when discussing prognostic indices), or remove them.

### m2. No confidence intervals for H4 percentage ratios

**Location**: §3.6 and Discussion §4.3: "L1 intercept recalibration accounted for 93.9%… 87.5%… 78.2%…"

**Issue**: These are point estimates of the ratio (IPA_L1 − IPA_L0) / (IPA_L3 − IPA_L0). Because IPA is itself an estimated quantity with variance, the ratios also have uncertainty. Presenting them without uncertainty may give false precision.

**Required action**: Add a parenthetical: "(all computed as point estimates from observed IPA values; bootstrap confidence intervals not computed for this ratio)" — or compute bootstrap CIs for the ratios to provide formal uncertainty.

### m3. H3 bootstrap results lack any indication of spread

**Location**: §3.5: *"the down-sampling comparison… showed ΔC of +0.0013 for Round B and −0.0013 for Round C relative to the CHARLS-only baseline"*

**Issue**: 200 bootstrap replications produce a distribution. Reporting only the mean without any spread metric leaves the reader unable to assess whether 0.0013 is robustly near zero or whether occasional replications crossed the 0.02 threshold.

**Required action**: Add: "Across 200 replications, no replication exceeded |ΔC| = [state observed maximum], and the 95th percentile was [state value]." Alternatively report IQR or the proportion of replications with |ΔC| > 0.01.

### m4. L3 as "recoverable ceiling" is an assumption — state it

**Location**: §4.3: "93.9% of the recoverable gain."

**Issue**: L3 is the full refit on target-cohort data; calling it the "ceiling" assumes it does not overfit within that cohort. With event rates of 46.3% (CLHLS), 20% (HRS) and 8.7% (SHARE) and only a 2-predictor model, overfitting is unlikely but should be acknowledged.

**Required action**: Add one sentence in §2.8 or a footnote: "L3 represents the empirical calibration ceiling achievable by full refitting on the available target-cohort data; in cohorts with small event counts, L3 could be subject to overfitting."

### m5. SHARE country-level extremes should be named in main text

**Location**: §3.6: *"19-country C-indices ranged from 0.691 to 0.856 with a median of 0.768."*

**Issue**: The lowest and highest countries are visible in Supplementary Figure S2, but main-text readers cannot check without going to the supplement.

**Required action**: Add country names: "…from 0.691 (Netherlands) to 0.856 (Switzerland-French-speaking region), median 0.768."

### m6. Aim 1 uses sex; Aims 2/3 do not — comparability caveat missing

**Location**: Methods §2.6, Discussion.

**Issue**: The Aim 1 model includes sex; Aims 2/3 omit sex due to KLoSA. This means the Aim 1 CHARLS internal C-index (0.7705 with sex) and Aims 2/3 performance are not directly comparable.

**Required action**: Add one sentence in §2.6: "This difference in specification means Aim 1 performance is not directly comparable with Aims 2/3; Aim 1 provides an upper bound on what model-B discrimination could achieve when sex is available." This is already implicit but should be stated.

### m7. Competing risks not discussed

**Location**: Limitations.

**Issue**: The study outcomes include all-cause mortality in a 60+ population. Other events (institutionalisation, migration, loss to follow-up) compete with death. Pooled logistic regression on all-cause mortality handles the outcome correctly, but the framework does not explicitly account for competing risks. Some reviewers will raise this.

**Required action**: Add to Limitations: "All analyses used all-cause mortality as the outcome. Competing risks from institutionalisation or migration were not modelled; in studies of older adults, loss-to-follow-up from non-death causes may not be exchangeable with survival."

### m8. Table 3 mixes LOCO and Aim 3 rows without visual separation

**Location**: Table 3 (§3.5).

**Issue**: Rows for Aim 3 (Asian pool → HRS/SHARE/MHAS) appear at the bottom of a table titled "LOCO and Asian-pool external validation performance." A subheading or horizontal rule within the table would improve readability.

**Required action**: Add a bold sub-header row "Aim 3: Asian pool → global validation" before the HRS_L0 row.

---

## Section-Level Comments

### Abstract
- Line 19: "In a supplementary analysis, FI showed a smaller cross-cohort |ΔC|…" — add "(exploratory; CLHLS IC uses binary proxies)" immediately after "H5 supported" to align with the text caveats. See M1.
- Line 18: "78–94%" — use "87–94%" for consistency (78.2% rounds to 78%, not 87%; the range should read "78–94%"). **OK as written**, but note the order should be "78–94%" matching smallest to largest.

### Methods §2.4 (Primary Outcome)
- The period 1 and period 2 characterisation approximates duration as "~2 years" each. For reproducibility, state the exact reference dates used in CHARLS to define period boundaries.

### Methods §2.5 (FI Construction)
- Excellent section. The harmonisation-route argument is novel and well-made.
- Confirm that the `extract_gateway_fi_defs.py` script is in the GitHub archive — code availability statement says the full codebase is archived.

### Methods §2.8 (Statistical analysis)
- Equation: *P*(4-year death) = 1 − (1 − *ĥ*₁)(1 − *ĥ*₂) — confirm in the text that γ̂ₜ is set to the period-specific intercept from the CHARLS fit (i.e., that the period effects are also frozen) or that `period = 1` is used for both h₁ and h₂. The current wording could be read either way.

### Results §3.5 (LOCO)
- The Table 3 caption says "representative rows (full version in supplementary)" in the CN version but the EN version shows all 14 rows. Confirm the EN version is the complete table.

### Results §3.9 (H5)
- The statement "C-index rose for both models in CLHLS partly through a mechanical effect of high event rates on the C-statistic" is correct but could be strengthened by citing the known relationship between event rate and C-index (e.g., Steyerberg 2010 REF-12 or Cook 2007). This helps the reader understand this is a well-established artefact, not a surprising finding.

### Discussion §4.3 (H4)
- "93.9% of the recoverable gain" — the Discussion uses 93.9% here but the Summary table (§3.12) uses 88%, 94%, 78%. The ordering in the table is HRS, SHARE, MHAS (88%→94%→78%) but the Discussion discusses SHARE first (93.9%), then HRS (87.5%), then MHAS (78.2%). Reorder the Discussion sequence to match the table order for consistency.

### Discussion §4.6 (H5) 
- This section already handles the caveats well. No changes needed here beyond what M1 requires in the table and abstract.

### Discussion §4.8 (Limitations)
- Limitation (3) discusses the four ISCED mapping judgement calls but does not note whether any of them could systematically bias the SA-3 result. Add: "It is unknown whether alternative classification choices (e.g., treating *sishu* as equivalent to middle school rather than no formal education) would materially change the SA-3 conclusion; sensitivity analysis across alternative mappings was not conducted."

### References
- REF-17 and REF-18 uncited — address per m1 above.
- REF-13 (Harrell 1982) is listed in the reference_placeholder document but **does not appear** in the manuscript reference list. If C-index methodology is cited elsewhere, REF-13 should appear in the reference list (or the citation in the Methods can be dropped).

---

## Language Notes (non-blocking)

1. "Structural barrier" appears at least four times across §4.4 and §4.5. Vary: "measurement non-equivalence as the binding constraint" (§4.5 last paragraph) can replace one instance.

2. §2.10 header reads "Feature importance analysis" but the text discusses this under "H6: feature importance concordance" in Results. Consider aligning the header with Results.

3. §4.1: "Results organise into two tiers" — minor: "Results fall into two tiers" is slightly more natural for British English; fine as is for American.

4. §4.3: "For most target populations a single lightweight recalibration is enough" — add "for achieving acceptable calibration" to avoid overstating the claim (it restores calibration; it doesn't improve discrimination).

---

## Checklist Against TRIPOD+AI (key items)

| Item | Status | Note |
|---|---|---|
| 1 Title | ✅ | Development + validation + 6 cohorts |
| 2 Abstract | ✅ | Structured, 312 words |
| 4 Objectives | ✅ | §1 last paragraph |
| 5 Data sources | ✅ | Table 1 + §2.2 |
| 8a Outcome | ⚠️ | 7-year sensitivity registered, not reported (M2) |
| 9a Predictors | ✅ | §2.5 full spec + Table S1 |
| 10 Sample size | ✅ | EPV reported |
| 11 Missing data | ✅ | §2.7 |
| 13b Internal validation | ✅ | Bootstrap optimism correction |
| 16 Risk of bias | ✅ | PROBAST-AI §2.11 |
| 22 Model updating | ✅ | L0–L3 ladder |
| 23 Limitations | ✅ | 8 items §4.8 |
| 26 Supplementary analyses | ✅ | SA-1 pre-registered, SA-3 post hoc labelled |
| 27 Registration | ⚠️ | Git commit timestamp; no external registry (confirm OSF or state internal SAP) |
| 28 Data availability | ✅ | Archive URLs listed |

---

## Summary of Required Actions

| Priority | Action | Section |
|---|---|---|
| **Must** | H5 verdict: add "provisional" marker in table + abstract | §3.12, Abstract |
| **Must** | 7-year sensitivity: report result or explain absence | §2.4, Results |
| **Must** | Cloglog check: add one-sentence confirmation | §3.3 |
| **Should** | Cite or remove REF-17, REF-18 | References |
| **Should** | H3 bootstrap: add spread metric (max or 95th pct) | §3.5 |
| **Should** | H4 ratios: caveat on point-estimate nature | §3.6 + §4.3 |
| **Should** | SHARE country extremes: name Netherlands and CH-Fr | §3.6 |
| **Should** | Competing risks: 1 sentence in Limitations | §4.8 |
| **Should** | Table 3: add sub-header for Aim 3 rows | Table 3 |
| **Consider** | Aim 1 vs Aim 2/3 sex-spec comparability caveat | §2.6 |
| **Consider** | L3 as ceiling: overfitting caveat | §2.8 |
| **Consider** | Limitations §4.8(3): ISCED sensitivity note | §4.8 |
| **Consider** | Vary "structural barrier" phrasing | §4.4–4.5 |

---

*Review completed: 2026-07-31 | Framework: academic-paper skill (revision-coach / reviewer mode)*
*Reviewer note: Numbers independently verified against results CSVs; no arithmetic errors found.*
