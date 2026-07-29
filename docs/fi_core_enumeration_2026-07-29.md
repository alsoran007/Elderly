# FI_core Enumeration Report

Execution date: 2026-07-29
Source scope: exactly the six task-specified analysis parquet files.
Positive rate is the proportion with deficit value exactly equal to 1 among age 60+ rows; ordinal items are therefore reported using the task-specified exact-1 rule.

## Executive Summary

- Total canonical stems: 41
- FI_core (all 6 cohorts): 19 stems
- FI_core_5of6: 32 stems
- Age 60+ rows: CHARLS=7669; CLHLS=9749; KLoSA=5289; HRS=13867; SHARE=36604; MHAS=10174
- Coverage matrix: D:/AI_project/project3/results/fi_core/fi_core_coverage_matrix_2026-07-29.csv

The MHAS file is the required 2026-07-28 version. HRS and KLoSA substitute columns are not silently relabeled as canonical concepts; only exact canonical columns count toward FI_core.

## Full Coverage Matrix

| stem | domain | CHARLS_rate | CLHLS_rate | KLoSA_rate | HRS_rate | SHARE_rate | MHAS_rate | n_cohorts | in_FI_core | in_FI_core_5of6 | missing_cohorts | warning |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
hibpe | comorbidity | 0.321 | 0.295 | 0.067 | 0.682 | 0.490 | 0.594 | 6 | TRUE | TRUE |  | cross_cohort_high_low_rate
dyslipe | comorbidity | 0.105 | 0.044 | NA | NA | 0.303 | NA | 3 | FALSE | FALSE | KLoSA,HRS,MHAS | 
diabe | comorbidity | 0.071 | 0.043 | 0.025 | 0.267 | 0.158 | 0.264 | 6 | TRUE | TRUE |  | 
cancre | comorbidity | 0.010 | 0.009 | 0.014 | 0.186 | 0.089 | 0.036 | 6 | TRUE | TRUE |  | very_low_positive_rate
lunge | comorbidity | 0.141 | 0.122 | 0.007 | 0.118 | 0.090 | NA | 5 | FALSE | TRUE | MHAS | very_low_positive_rate
livere | comorbidity | 0.040 | 0.006 | 0.003 | NA | 0.080 | NA | 4 | FALSE | FALSE | HRS,MHAS | very_low_positive_rate
hearte | comorbidity | 0.160 | 0.127 | 0.017 | 0.301 | 0.201 | NA | 5 | FALSE | TRUE | MHAS | 
stroke | comorbidity | 0.037 | 0.086 | 0.012 | 0.095 | 0.069 | 0.044 | 6 | TRUE | TRUE |  | 
kidneye | comorbidity | 0.066 | 0.009 | NA | 0.121 | NA | NA | 3 | FALSE | FALSE | KLoSA,SHARE,MHAS | very_low_positive_rate
digeste | comorbidity | 0.220 | 0.055 | NA | NA | NA | NA | 2 | FALSE | FALSE | KLoSA,HRS,SHARE,MHAS | 
psyche | comorbidity | 0.016 | 0.150 | 0.009 | 0.185 | 0.100 | NA | 5 | FALSE | TRUE | MHAS | very_low_positive_rate
arthre | comorbidity | 0.367 | 0.144 | 0.025 | 0.672 | 0.323 | 0.311 | 6 | TRUE | TRUE |  | cross_cohort_high_low_rate
asthmae | comorbidity | 0.055 | 0.011 | NA | NA | 0.386 | NA | 3 | FALSE | FALSE | KLoSA,HRS,MHAS | 
dressa | adl | 0.083 | 0.131 | 0.017 | 0.183 | 0.102 | 0.120 | 6 | TRUE | TRUE |  | 
batha | adl | 0.111 | 0.240 | 0.024 | 0.186 | 0.080 | 0.067 | 6 | TRUE | TRUE |  | 
eata | adl | 0.053 | 0.086 | 0.016 | 0.096 | 0.025 | 0.044 | 6 | TRUE | TRUE |  | 
beda | adl | 0.091 | 0.115 | 0.018 | 0.150 | 0.051 | 0.102 | 6 | TRUE | TRUE |  | 
toilta | adl | 0.180 | 0.133 | 0.016 | 0.148 | 0.034 | 0.079 | 6 | TRUE | TRUE |  | 
urina | adl | 0.070 | 0.066 | 0.021 | 0.283 | 0.079 | NA | 5 | FALSE | TRUE | MHAS | 
housewka | iadl | 0.155 | 0.562 | 0.036 | 0.271 | 0.153 | NA | 5 | FALSE | TRUE | MHAS | 
mealsa | iadl | 0.150 | 0.371 | 0.051 | 0.081 | 0.056 | 0.064 | 6 | TRUE | TRUE |  | 
shopa | iadl | 0.149 | 0.370 | 0.038 | 0.099 | 0.090 | 0.123 | 6 | TRUE | TRUE |  | 
moneya | iadl | 0.185 | 0.239 | 0.037 | 0.072 | 0.061 | 0.033 | 6 | TRUE | TRUE |  | 
medsa | iadl | 0.103 | 0.351 | 0.020 | 0.055 | 0.028 | 0.032 | 6 | TRUE | TRUE |  | 
walk100a | mobility | 0.028 | 0.256 | NA | 0.535 | 0.152 | NA | 4 | FALSE | FALSE | KLoSA,MHAS | 
walk1kma | mobility | 0.244 | 0.477 | NA | 0.371 | 0.032 | NA | 4 | FALSE | FALSE | KLoSA,MHAS | 
joga | mobility | 0.659 | 0.531 | NA | 0.683 | NA | 0.645 | 4 | FALSE | FALSE | KLoSA,SHARE | 
climsa | mobility | 0.515 | 0.520 | NA | 0.434 | 0.348 | 0.499 | 5 | FALSE | TRUE | KLoSA | 
chaira | mobility | 0.347 | 0.310 | NA | 0.427 | 0.233 | 0.340 | 5 | FALSE | TRUE | KLoSA | 
stoopa | mobility | 0.383 | 0.128 | NA | 0.515 | 0.367 | 0.474 | 5 | FALSE | TRUE | KLoSA | 
armsa | mobility | 0.144 | 0.061 | NA | 0.196 | 0.118 | 0.159 | 5 | FALSE | TRUE | KLoSA | 
lifta | mobility | 0.195 | 0.453 | NA | 0.303 | 0.265 | 0.294 | 5 | FALSE | TRUE | KLoSA | 
dimea | mobility | 0.067 | NA | NA | 0.095 | 0.055 | 0.093 | 4 | FALSE | FALSE | CLHLS,KLoSA | 
dsight | sensory | 0.310 | 0.244 | 0.014 | 0.048 | 0.055 | NA | 5 | FALSE | TRUE | MHAS | 
nsight | sensory | 0.261 | 0.125 | 0.012 | 0.073 | 0.111 | NA | 5 | FALSE | TRUE | MHAS | 
hearing | sensory | 0.211 | 0.475 | 0.014 | 0.071 | 0.050 | 0.144 | 6 | TRUE | TRUE |  | 
shlt | general_health | 0.312 | 0.014 | 0.309 | 0.093 | 0.142 | 0.156 | 6 | TRUE | TRUE |  | 
painfr | general_health | 0.346 | 0.621 | 0.444 | 0.360 | 0.591 | 0.395 | 6 | TRUE | TRUE |  | 
fall | general_health | 0.190 | 0.380 | 0.025 | 0.369 | 0.062 | 0.432 | 6 | TRUE | TRUE |  | 
slfmem | general_health | 0.401 | 0.034 | NA | 0.056 | 0.068 | 0.099 | 5 | FALSE | TRUE | KLoSA | 
mbmi | anthropometry | 0.146 | 0.298 | 0.065 | 0.334 | 0.229 | 0.341 | 6 | TRUE | TRUE |  | 

## FI_core Stems by Domain

### comorbidity (5/13)
- hibpe: CHARLS=0.321, CLHLS=0.295, KLoSA=0.067, HRS=0.682, SHARE=0.490, MHAS=0.594
- diabe: CHARLS=0.071, CLHLS=0.043, KLoSA=0.025, HRS=0.267, SHARE=0.158, MHAS=0.264
- cancre: CHARLS=0.010, CLHLS=0.009, KLoSA=0.014, HRS=0.186, SHARE=0.089, MHAS=0.036
- stroke: CHARLS=0.037, CLHLS=0.086, KLoSA=0.012, HRS=0.095, SHARE=0.069, MHAS=0.044
- arthre: CHARLS=0.367, CLHLS=0.144, KLoSA=0.025, HRS=0.672, SHARE=0.323, MHAS=0.311

### adl (5/6)
- dressa: CHARLS=0.083, CLHLS=0.131, KLoSA=0.017, HRS=0.183, SHARE=0.102, MHAS=0.120
- batha: CHARLS=0.111, CLHLS=0.240, KLoSA=0.024, HRS=0.186, SHARE=0.080, MHAS=0.067
- eata: CHARLS=0.053, CLHLS=0.086, KLoSA=0.016, HRS=0.096, SHARE=0.025, MHAS=0.044
- beda: CHARLS=0.091, CLHLS=0.115, KLoSA=0.018, HRS=0.150, SHARE=0.051, MHAS=0.102
- toilta: CHARLS=0.180, CLHLS=0.133, KLoSA=0.016, HRS=0.148, SHARE=0.034, MHAS=0.079

### iadl (4/5)
- mealsa: CHARLS=0.150, CLHLS=0.371, KLoSA=0.051, HRS=0.081, SHARE=0.056, MHAS=0.064
- shopa: CHARLS=0.149, CLHLS=0.370, KLoSA=0.038, HRS=0.099, SHARE=0.090, MHAS=0.123
- moneya: CHARLS=0.185, CLHLS=0.239, KLoSA=0.037, HRS=0.072, SHARE=0.061, MHAS=0.033
- medsa: CHARLS=0.103, CLHLS=0.351, KLoSA=0.020, HRS=0.055, SHARE=0.028, MHAS=0.032

### mobility (0/9)
- None

### sensory (1/3)
- hearing: CHARLS=0.211, CLHLS=0.475, KLoSA=0.014, HRS=0.071, SHARE=0.050, MHAS=0.144

### general_health (3/4)
- shlt: CHARLS=0.312, CLHLS=0.014, KLoSA=0.309, HRS=0.093, SHARE=0.142, MHAS=0.156
- painfr: CHARLS=0.346, CLHLS=0.621, KLoSA=0.444, HRS=0.360, SHARE=0.591, MHAS=0.395
- fall: CHARLS=0.190, CLHLS=0.380, KLoSA=0.025, HRS=0.369, SHARE=0.062, MHAS=0.432

### anthropometry (1/1)
- mbmi: CHARLS=0.146, CLHLS=0.298, KLoSA=0.065, HRS=0.334, SHARE=0.229, MHAS=0.341

## Stems Excluded from FI_core

The following stems have at least one missing cohort. The missing_cohorts field identifies the limiting cohort(s); column fields in the CSV preserve the exact source column mapping.

- dyslipe (comorbidity): missing KLoSA,HRS,MHAS; FI_core_5of6=FALSE
- lunge (comorbidity): missing MHAS; FI_core_5of6=TRUE
- livere (comorbidity): missing HRS,MHAS; FI_core_5of6=FALSE
- hearte (comorbidity): missing MHAS; FI_core_5of6=TRUE
- kidneye (comorbidity): missing KLoSA,SHARE,MHAS; FI_core_5of6=FALSE
- digeste (comorbidity): missing KLoSA,HRS,SHARE,MHAS; FI_core_5of6=FALSE
- psyche (comorbidity): missing MHAS; FI_core_5of6=TRUE
- asthmae (comorbidity): missing KLoSA,HRS,MHAS; FI_core_5of6=FALSE
- urina (adl): missing MHAS; FI_core_5of6=TRUE
- housewka (iadl): missing MHAS; FI_core_5of6=TRUE
- walk100a (mobility): missing KLoSA,MHAS; FI_core_5of6=FALSE
- walk1kma (mobility): missing KLoSA,MHAS; FI_core_5of6=FALSE
- joga (mobility): missing KLoSA,SHARE; FI_core_5of6=FALSE
- climsa (mobility): missing KLoSA; FI_core_5of6=TRUE
- chaira (mobility): missing KLoSA; FI_core_5of6=TRUE
- stoopa (mobility): missing KLoSA; FI_core_5of6=TRUE
- armsa (mobility): missing KLoSA; FI_core_5of6=TRUE
- lifta (mobility): missing KLoSA; FI_core_5of6=TRUE
- dimea (mobility): missing CLHLS,KLoSA; FI_core_5of6=FALSE
- dsight (sensory): missing MHAS; FI_core_5of6=TRUE
- nsight (sensory): missing MHAS; FI_core_5of6=TRUE
- slfmem (general_health): missing KLoSA; FI_core_5of6=TRUE

## Quality Warnings

- hibpe: cross_cohort_high_low_rate
- cancre: very_low_positive_rate
- lunge: very_low_positive_rate
- livere: very_low_positive_rate
- kidneye: very_low_positive_rate
- psyche: very_low_positive_rate
- arthre: cross_cohort_high_low_rate

## SAP Impact

FI_core (19 items) will be used as the sensitivity analysis against FI_full (41 items, cohort-specific threshold). The unified sensitivity threshold is ceiling(0.8 x 19) = 16. FI_core_5of6 (32 items) is an expanded coverage diagnostic and is not the primary sensitivity set unless explicitly approved.

## Mapping Notes

- CHARLS, CLHLS, and SHARE use the canonical column names directly in the analysis parquet.
- MHAS uses r3-prefixed canonical columns and contains 27 of the 41 canonical stems.
- HRS and KLoSA contain additional cohort-specific substitute columns. Those columns are retained in the source FI files but are not counted as canonical FI_core coverage without an explicit equivalence decision.

