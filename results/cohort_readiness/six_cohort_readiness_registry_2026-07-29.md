# Six-Cohort Readiness Registry

## Material Passport
- Type: cross-cohort denominator, four-year event-readiness, and FI readiness registry
- Status: FULLY_VERIFIED — all six cohorts have verified event counts AND verified FI files
- Previous version: `six_cohort_readiness_registry_2026-07-28.csv/.md` (event counts only)
- Updated: 2026-07-29 — added FI columns (D-027)
- Output CSV: D:/AI_project/project3/results/cohort_readiness/six_cohort_readiness_registry_2026-07-29.csv
- Raw data modified: no.

---

## Event Counts (unchanged from 2026-07-28 version)

| Cohort | Role | Baseline | Age 60+ N | 4-year window | Verified events | Prior reported | Status |
|---|---|---|---:|---|---:|---:|---|
| CHARLS | development | 2011 | 7,669 | 2011–2015 | 785 | 785 | VERIFIED_CURRENT |
| CLHLS | external_validation | 2011/12 | 9,749 | ≤1461 days | 3,502 | 3,502 | VERIFIED_CURRENT |
| KLoSA | Asian_validation | 2012 | 5,289 | 2012–2016 | 585 | 918 | VERIFIED_CURRENT |
| SHARE | European_validation | 2011 | 36,604 | 2011–2015 | 3,689 | 6,287 | VERIFIED_CURRENT |
| MHAS | American_validation | 2012 | 10,174 | 2012–2016 | 1,404 | 1,735 | VERIFIED_CURRENT |
| HRS | American_validation | 2012 | 13,867 | 2012–2016 | 2,352 | 2,352 | VERIFIED_CURRENT |

**Notes on revised event counts**:  
- KLoSA 918→585: historical count summed EXIT records without baseline-ID and age-60+ restriction; corrected.  
- SHARE 6,287→3,689: D-021 restricts to wave-4 2011 visits only.  
- MHAS 1,735→1,404: D-022 age derivation applied.

---

## FI Readiness (NEW — D-027, 2026-07-29)

| Cohort | FI file (canonical) | Stems | FI-eligible 60+ | FI median (60+) | FI max | Status |
|---|---|---|---:|---:|---:|---|
| CHARLS | `charls_fi_2011_2026-07-27.parquet` | 41/41 | 7,551 | **0.200** | 0.846 | VERIFIED_FINAL |
| CLHLS | `clhls_fi_2011_2026-07-29.parquet` | 41/41 | 9,207 | **0.169** | 0.771 | VERIFIED_FINAL |
| KLoSA | `klosa_fi_2012_2026-07-29.parquet` | 41/41 w/subs | 5,289 | **0.095** | 0.806 | VERIFIED_FINAL |
| HRS | `hrs_fi_2012_2026-07-29.parquet` | 41/41 w/subs | 10,707 | **0.287** | 0.897 | VERIFIED_FINAL |
| SHARE | `share_fi_2011_2026-07-29.parquet` | 41/41 w/subs | 36,361 | **0.169** | 0.974 | VERIFIED_FINAL |
| MHAS | `mhas_fi_2012_2026-07-28.parquet` | 27/41 cohort-thresh | 9,094 | **0.220** | 0.958 | VERIFIED_FINAL |

All FI max ≤ 1.0 ✅ (Searle submaximal limit satisfied for all six cohorts)

### FI Notes

**KLoSA median 0.095**: Confirmed real, not a coding error. Wave-4 60+ median age = 71 years (relatively young community-dwelling Korean population). Most ADL/IADL items have 2–7% positive rate. Likert items correctly mapped with `(val-1)/4`. See D-027.

**MHAS canonical file**: Use `2026-07-28` version only. The `2026-07-29` version uses a fixed threshold of 33 but MHAS has only 27 stems, making virtually all records ineligible (882 vs 9,094). D-027 documents this.

**HRS stems**: 33/41 stems have data; 8 stems (joga, urina, livere, digeste, asthmae, armsa, slfmem, mbmi in D-025 version) not found; `2026-07-29` version (41/41 w/subs) uses validated substitutes. D-025 quality notes: `dyslipe` proxied by nc110 (cholesterol test), `kidneye` proxied by nc017 (diabetes-related nephropathy only) — both retained with supplementary methods note.

**Likert encoding**: Variables `dsight`, `nsight`, `hearing`, `shlt`, `slfmem` mapped `(val-1)/4` before FI calculation in all cohorts (D-026). Without this fix, SHARE FI median was 0.581 and max exceeded 1.0.

---

## Decisions Applied per Cohort

| Cohort | Key decisions |
|---|---|
| CHARLS | D-009 (ID bridging), D-010 (discrete time / 4-year), D-020 (FI spec frozen 41-item) |
| CLHLS | D-019 (45 pre-baseline deaths → event_4y=NA), D-020 |
| KLoSA | D-020, D-026 (Likert mapping) |
| SHARE | D-020, D-021 (wave-4 2011 only), D-026 |
| MHAS | D-020, D-022 (age derivation), D-026 |
| HRS | D-020, D-025 (HRS-specific substitutes), D-026 |

---

## Overall Readiness Gates

| Gate | Status |
|---|---|
| Denominators verified (60+ N) | ✅ all six cohorts |
| Four-year event counts verified | ✅ all six cohorts |
| FI spec frozen | ✅ 41 items, D-020, 2026-07-28 |
| FI files built and validated | ✅ all six cohorts, D-027 |
| Outcome × FI linkage | ⏳ pending — deferred until FI fully verified (outcome-blind protocol) |
| FI_core common subset | ⏳ pending — MHAS 27 stems constrains cross-cohort comparison |
| IC construction | ⏳ pending |
| Model development (Aim 1) | ⏳ pending |
| External validation (Aim 3) | ⏳ pending |

---

## Remaining Gate Notes

FI_core (common stems available in all six cohorts, including MHAS's 27) should be enumerated before modeling to enable fair cross-cohort calibration comparison. This does not require re-running FI construction — it is a post-hoc subset selection on existing `fi_*` columns.

The outcome-blind protocol (no FI–event association examined until after pre-registration) remains in effect.
