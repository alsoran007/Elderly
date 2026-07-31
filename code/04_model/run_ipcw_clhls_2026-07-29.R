# run_ipcw_clhls_2026-07-29.R
# IPCW sensitivity analysis for CLHLS 2,072 NA outcomes
# SAP §12.3: missing outcome > 20% requires IPCW or sensitivity discussion
# Compares Aim1 unweighted metrics vs IPCW-weighted metrics

suppressPackageStartupMessages({
  library(arrow); library(survival); library(pROC)
})
OUT <- "D:/AI_project/project3/results/ipcw"
dir.create(OUT, recursive=TRUE, showWarnings=FALSE)

cat("=== CLHLS IPCW Sensitivity Analysis ===\n")

# ── 1. Load data ──────────────────────────────────────────────────────────────
cl_fi  <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/clhls_fi_2011_2026-07-29.parquet"))
cl_out <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/clhls_outcome_2026-07-28.parquet"))

# ── 2. Full eligible dataset (FI-eligible 60+, excluding prebaseline deaths) ──
cl_full <- merge(
  cl_fi[cl_fi$age_60_plus == TRUE & !cl_fi$fi_excluded, c("id","fi_full","age")],
  cl_out[cl_out$prebaseline_death == FALSE, c("id","female","event_4y")],
  by = "id", all.x = TRUE
)
cl_full <- cl_full[!is.na(cl_full$fi_full) & !is.na(cl_full$age), ]
cl_full$observed <- as.integer(!is.na(cl_full$event_4y))
cat(sprintf("Full eligible: N=%d | observed=%d | censored=%d (%.1f%%)\n",
            nrow(cl_full), sum(cl_full$observed),
            sum(1-cl_full$observed), mean(1-cl_full$observed)*100))

# ── 3. Aim1 frozen 4-year predictions for ALL eligible ────────────────────────
coef_csv <- read.csv("D:/AI_project/project3/results/aim1/model_b_charls_coefficients_2026-07-29.csv",
                     stringsAsFactors=FALSE)
gc <- function(term) coef_csv$estimate[coef_csv$term == term]

# Female: use 0 (male) for any NAs — check how many
cat(sprintf("female NA: %d\n", sum(is.na(cl_full$female))))
female_val <- ifelse(is.na(cl_full$female), 0L, cl_full$female)

lp_base  <- gc("(Intercept)") + gc("fi_full")*cl_full$fi_full +
            gc("age")*cl_full$age + gc("female")*female_val
h1 <- plogis(lp_base)
h2 <- plogis(lp_base + gc("factor(period)2"))
cl_full$pred_4y <- 1 - (1-h1)*(1-h2)

cat(sprintf("Predicted 4y mortality: mean=%.4f  min=%.4f  max=%.4f\n",
            mean(cl_full$pred_4y), min(cl_full$pred_4y), max(cl_full$pred_4y)))

# ── 4. Censoring model: P(observed=1 | fi_full, age, female) ──────────────────
cat("\n=== Censoring model ===\n")
cens_fit <- glm(observed ~ fi_full + age + female,
                data = cl_full[!is.na(cl_full$female), ],
                family = binomial)
print(summary(cens_fit)$coefficients)

# Predict P(observed) for all (including those with NA female → impute with mean)
female_for_cens <- ifelse(is.na(cl_full$female),
                          mean(cl_full$female, na.rm=TRUE),
                          cl_full$female)
cl_full$p_obs <- predict(cens_fit,
                         newdata=data.frame(fi_full=cl_full$fi_full,
                                            age=cl_full$age,
                                            female=female_for_cens),
                         type="response")
cl_full$ipcw <- ifelse(cl_full$observed == 1, 1/cl_full$p_obs, NA_real_)
cc <- cl_full[cl_full$observed == 1, ]
cat(sprintf("\nIPCW weights (complete cases): mean=%.3f  median=%.3f  max=%.3f\n",
            mean(cc$ipcw), median(cc$ipcw), max(cc$ipcw)))

# Truncate extreme weights at 99th percentile
w99 <- quantile(cc$ipcw, 0.99)
cc$ipcw_trunc <- pmin(cc$ipcw, w99)
cat(sprintf("Truncated weights (99th=%.3f): mean=%.3f  max=%.3f\n",
            w99, mean(cc$ipcw_trunc), max(cc$ipcw_trunc)))

# ── 5. Unweighted metrics (replicating Aim1) ──────────────────────────────────
cat("\n=== Unweighted (complete case) ===\n")
roc_u  <- suppressMessages(roc(cc$event_4y, cc$pred_4y, quiet=TRUE))
c_u    <- as.numeric(auc(roc_u))
oe_u   <- mean(cc$event_4y) / mean(cc$pred_4y)
lp_u   <- qlogis(pmin(pmax(cc$pred_4y, 1e-7), 1-1e-7))
sl_u   <- coef(glm(event_4y ~ lp_u, data=cc, family=binomial))[2]
brier_u<- mean((cc$event_4y - cc$pred_4y)^2)
ipa_u  <- 1 - brier_u / mean((cc$event_4y - mean(cc$event_4y))^2)
cat(sprintf("C=%.4f  OE=%.4f  slope=%.4f  Brier=%.5f  IPA=%.4f\n",
            c_u, oe_u, sl_u, brier_u, ipa_u))

# ── 6. IPCW-weighted metrics ──────────────────────────────────────────────────
cat("\n=== IPCW-weighted ===\n")
conc_w <- concordance(event_4y ~ pred_4y, data=cc, weights=cc$ipcw_trunc)
c_w    <- conc_w$concordance
oe_w   <- weighted.mean(cc$event_4y, cc$ipcw_trunc) /
          weighted.mean(cc$pred_4y,  cc$ipcw_trunc)
brier_w<- weighted.mean((cc$event_4y - cc$pred_4y)^2, cc$ipcw_trunc)
ipa_w  <- 1 - brier_w / weighted.mean((cc$event_4y - weighted.mean(cc$event_4y, cc$ipcw_trunc))^2,
                                       cc$ipcw_trunc)
# Weighted calibration slope
cc$w_scaled <- cc$ipcw_trunc / mean(cc$ipcw_trunc)
sl_w <- coef(glm(event_4y ~ lp_u, data=cc, family=binomial,
                 weights=cc$w_scaled))[2]
cat(sprintf("C=%.4f  OE=%.4f  slope=%.4f  Brier=%.5f  IPA=%.4f\n",
            c_w, oe_w, sl_w, brier_w, ipa_w))

# ── 7. Censoring rates by FI tertile (MAR check) ─────────────────────────────
cat("\n=== Censoring by FI tertile ===\n")
cl_full$fi_tert <- cut(cl_full$fi_full,
                       breaks=quantile(cl_full$fi_full, c(0,.33,.67,1), na.rm=TRUE),
                       include.lowest=TRUE, labels=c("Low","Mid","High"))
tert_tab <- aggregate(cbind(N=observed, censored=1-observed) ~ fi_tert,
                      data=cl_full,
                      FUN=function(x) c(n=length(x), cens_rate=mean(1-x)))
print(tert_tab)

# ── 8. Save results ───────────────────────────────────────────────────────────
metrics_df <- data.frame(
  analysis   = c("unweighted_aim1","ipcw_weighted"),
  n          = nrow(cc),
  events     = sum(cc$event_4y),
  c_index    = round(c(c_u, c_w), 4),
  oe_ratio   = round(c(oe_u, oe_w), 4),
  cal_slope  = round(c(sl_u, sl_w), 4),
  brier      = round(c(brier_u, brier_w), 5),
  ipa        = round(c(ipa_u, ipa_w), 4)
)
write.csv(metrics_df, file.path(OUT,"ipcw_clhls_metrics_2026-07-29.csv"), row.names=FALSE)

## Censoring-model coefficients, weight summary and tertile censoring rates were
## previously only printed to console / embedded in the .md report, so the
## manuscript's IPCW figures had no machine-readable source. Emitted as CSV here
## (gap D3 from the 2026-07-31 numeric provenance audit).
cens_coef <- as.data.frame(summary(cens_fit)$coefficients)
names(cens_coef) <- c("estimate","std_error","z_value","p_value")
cens_coef$term <- rownames(cens_coef)
cens_coef <- cens_coef[, c("term","estimate","std_error","z_value","p_value")]
write.csv(cens_coef, file.path(OUT,"ipcw_clhls_censoring_model_2026-07-29.csv"),
          row.names=FALSE)

wt_raw <- cc$ipcw[is.finite(cc$ipcw)]
wt_tr  <- cc$ipcw_trunc[is.finite(cc$ipcw_trunc)]
wt_summary <- data.frame(
  statistic = c("n_complete_case",
                "raw_mean","raw_median","raw_min","raw_max","raw_sd",
                "trunc_p99_cutoff",
                "trunc_mean","trunc_median","trunc_min","trunc_max","trunc_sd"),
  value = c(length(wt_tr),
            mean(wt_raw), median(wt_raw), min(wt_raw), max(wt_raw), sd(wt_raw),
            w99,
            mean(wt_tr), median(wt_tr), min(wt_tr), max(wt_tr), sd(wt_tr))
)
write.csv(wt_summary, file.path(OUT,"ipcw_clhls_weight_summary_2026-07-29.csv"),
          row.names=FALSE)

## Tertile censoring rates (reported in manuscript 3.7).
## NB: aggregate() returns a matrix column per LHS variable; the censoring rate
## lives in tert_tab$N[,"cens_rate"] because the FUN was applied to `observed`,
## so mean(1-x) there is the censored proportion. tert_tab$censored[,"cens_rate"]
## is its complement and must not be used.
tert_out <- data.frame(
  fi_tertile  = as.character(tert_tab$fi_tert),
  n           = as.numeric(tert_tab$N[, "n"]),
  censor_rate = as.numeric(tert_tab$N[, "cens_rate"])
)
write.csv(tert_out, file.path(OUT,"ipcw_clhls_tertile_censoring_2026-07-29.csv"),
          row.names=FALSE)

delta_c <- c_w - c_u
report <- paste0(
"# CLHLS IPCW Sensitivity Report (2026-07-29)\n\n",
"## Background\n",
"SAP §12.3 requires sensitivity analysis when missing outcomes > 20%.\n",
sprintf("CLHLS FI-eligible 60+ (excl prebaseline deaths): **%d persons**\n", nrow(cl_full)),
sprintf("Complete outcomes (event_4y known): **%d (%.1f%%)**\n", nrow(cc), nrow(cc)/nrow(cl_full)*100),
sprintf("Censored (event_4y=NA): **%d (%.1f%%)**\n\n", sum(1-cl_full$observed), mean(1-cl_full$observed)*100),
"## Censoring Model\n",
sprintf("Predictors of being observed: fi_full (p=%.3f), age (p=%.3f), female (p=%.3f)\n",
        summary(cens_fit)$coefficients["fi_full",4],
        summary(cens_fit)$coefficients["age",4],
        summary(cens_fit)$coefficients["female",4]),
sprintf("Interpretation: %s\n\n",
        ifelse(any(summary(cens_fit)$coefficients[-1,4] < 0.05),
               "Censoring is NOT completely random — IPCW is necessary.",
               "No strong predictor of censoring — MAR likely, complete-case valid.")),
"## Performance Comparison\n\n",
"| Metric | Unweighted (Aim1) | IPCW-weighted | Δ |\n",
"|---|---|---|---|\n",
sprintf("| C-index | %.4f | %.4f | **%+.4f** |\n", c_u, c_w, delta_c),
sprintf("| O:E | %.4f | %.4f | %+.4f |\n", oe_u, oe_w, oe_w-oe_u),
sprintf("| Cal slope | %.4f | %.4f | %+.4f |\n", sl_u, sl_w, sl_w-sl_u),
sprintf("| Brier | %.5f | %.5f | %+.5f |\n", brier_u, brier_w, brier_w-brier_u),
sprintf("| IPA | %.4f | %.4f | %+.4f |\n\n", ipa_u, ipa_w, ipa_w-ipa_u),
"## Conclusion\n",
sprintf("IPCW-weighted C-index = %.4f vs unweighted = %.4f (ΔC = %+.4f).\n",
        c_w, c_u, delta_c),
ifelse(abs(delta_c) < 0.005,
       "The difference is negligible (ΔC < 0.005). The complete-case Aim1 analysis is robust to informative censoring.\n",
       sprintf("The difference is non-negligible (ΔC = %+.4f). Informative censoring may bias the complete-case results.\n", delta_c))
)
writeLines(report, file.path(OUT,"ipcw_clhls_report_2026-07-29.md"))
cat("\nIPCW analysis complete.\n")
print(metrics_df)
