# run_h5_model_c.R — H5: FI vs IC 跨队列 C-index 稳定性比较
# SAP §8.2 Model C (IC), Model D (FI+IC) 敏感性分析
# H5 假设：FI（Model B）的跨队列 C-index 一致性 > IC（Model C）

suppressPackageStartupMessages({
  library(arrow); library(haven); library(pROC)
})
OUT <- "D:/AI_project/project3/results/h5_ic"
dir.create(OUT, showWarnings=FALSE)
set.seed(2026)
cat("=== H5: Model C/D Analysis ===\n")

# ── 1. Build CHARLS analysis dataset (person-period + IC + FI) ────────────────
cat("\n-- CHARLS --\n")
pp      <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/charls_person_period_2026-07-27.parquet"))
fi_ch   <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/charls_fi_2011_2026-07-27.parquet"))
ic_ch   <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/charls_ic_2011_2026-07-29.parquet"))
ch_base <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/charls_baseline_cohort_2026-07-27.parquet"))

# IC uses bio$ID (=id_w1_11). Bridge: id_w1_11 → pid → person_period
bridge  <- ch_base[, c("pid","id_w1_11","female")]
ic_pid  <- merge(ic_ch, bridge, by.x="id", by.y="id_w1_11", all.x=FALSE)

# Person-period: periods 1+2, age60+, FI-eligible
pp60 <- pp[pp$age_60_plus==TRUE & pp$period %in% c(1L,2L), ]
ch_bin <- aggregate(event~pid, data=pp60, FUN=function(x) as.integer(any(x==1)))
names(ch_bin)[2] <- "event_4y"

# Merge IC + FI + event on pid
ch_fi_sub <- fi_ch[!fi_ch$fi_excluded, c("id","fi_full","age")]
ch_fi_sub <- merge(ch_fi_sub, bridge, by.x="id", by.y="id_w1_11", all.x=FALSE)
ch_all <- merge(ch_bin, ch_fi_sub[, c("pid","fi_full","age","female")], by="pid")
ch_all <- merge(ch_all, ic_pid[, c("pid","ic_locomotion","ic_vitality","ic_cognition","ic_psychology","ic_sensory","ic_total_partial")], by="pid", all.x=TRUE)
ch_all <- ch_all[!is.na(ch_all$fi_full) & !is.na(ch_all$age), ]
cat(sprintf("  CHARLS: N=%d  events=%d\n", nrow(ch_all), sum(ch_all$event_4y)))

ic_cols <- c("ic_locomotion","ic_vitality","ic_cognition","ic_psychology","ic_sensory")
ch_ic_cc <- ch_all[complete.cases(ch_all[, c("event_4y","fi_full","age",ic_cols)]) & !is.na(ch_all$age), ]
cat(sprintf("  Complete IC (5-domain): N=%d  events=%d\n", nrow(ch_ic_cc), sum(ch_ic_cc$event_4y)))

# ── 2. CLHLS IC proxy (binary FI items → continuous IC proxies 0-100) ─────────
cat("\n-- CLHLS IC proxy --\n")
cl_fi  <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/clhls_fi_2011_2026-07-29.parquet"))
cl_out <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/clhls_outcome_2026-07-28.parquet"))

cl_elig <- cl_fi[cl_fi$age_60_plus==TRUE & !cl_fi$fi_excluded, ]
cl_df   <- merge(cl_elig[, c("id","fi_full","age")],
                 cl_out[!is.na(cl_out$event_4y) & cl_out$prebaseline_death==FALSE,
                        c("id","female","event_4y")], by="id")
cl_df$event <- as.integer(cl_df$event_4y)

# IC proxies: invert FI deficit items → higher = better IC
loco_items <- c("walk100a","walk1kma","climsa","chaira","stoopa","armsa","lifta")
avail <- intersect(loco_items, names(cl_elig))
cl_df$ic_locomotion <- (1 - rowMeans(cl_elig[match(cl_df$id, cl_elig$id), avail],
                                     na.rm=TRUE)) * 100
cl_df$ic_vitality   <- (1 - cl_elig[match(cl_df$id, cl_elig$id), "mbmi"]) * 100
cl_df$ic_cognition  <- (1 - cl_elig[match(cl_df$id, cl_elig$id), "slfmem"]) * 100
cl_df$ic_psychology <- (1 - cl_elig[match(cl_df$id, cl_elig$id), "psyche"]) * 100
sens_items <- c("dsight","nsight","hearing")
cl_df$ic_sensory    <- (1 - rowMeans(cl_elig[match(cl_df$id, cl_elig$id), sens_items],
                                     na.rm=TRUE)) * 100
cl_df <- cl_df[!is.na(cl_df$fi_full) & !is.na(cl_df$age) & !is.na(cl_df$event), ]
cat(sprintf("  CLHLS: N=%d  events=%d\n", nrow(cl_df), sum(cl_df$event)))

# ── 3. Fit Models B, C, D on CHARLS ──────────────────────────────────────────
cat("\n-- Fitting Models B / C / D on CHARLS --\n")
# person-period formula common terms
form_base <- "event_4y ~ age"
form_B <- paste(form_base, "+ fi_full")
form_C <- paste(form_base, "+ ic_locomotion + ic_vitality + ic_cognition + ic_psychology + ic_sensory")
form_D <- paste(form_base, "+ fi_full + ic_locomotion + ic_vitality + ic_cognition + ic_psychology + ic_sensory")

# Use complete-case IC dataset for Models C/D; full for B
pp_B <- ch_all[complete.cases(ch_all[, c("event_4y","fi_full","age","female")]), ]
pp_C <- ch_ic_cc
pp_D <- ch_ic_cc

fit_B <- glm(as.formula(form_B), data=pp_B, family=binomial)
fit_C <- glm(as.formula(form_C), data=pp_C, family=binomial)
fit_D <- glm(as.formula(form_D), data=pp_D, family=binomial)

c_B_charls <- as.numeric(auc(suppressMessages(roc(pp_B$event_4y, predict(fit_B, type="response"), quiet=TRUE))))
c_C_charls <- as.numeric(auc(suppressMessages(roc(pp_C$event_4y, predict(fit_C, type="response"), quiet=TRUE))))
c_D_charls <- as.numeric(auc(suppressMessages(roc(pp_D$event_4y, predict(fit_D, type="response"), quiet=TRUE))))
cat(sprintf("  Model B C (CHARLS apparent): %.4f\n", c_B_charls))
cat(sprintf("  Model C C (CHARLS apparent): %.4f\n", c_C_charls))
cat(sprintf("  Model D C (CHARLS apparent): %.4f\n", c_D_charls))

# ── 4. Apply frozen coefficients to CLHLS ────────────────────────────────────
cat("\n-- CLHLS external validation --\n")
predict_4y <- function(fit, newdata) {
  # binary logistic: direct predicted probability
  feats       <- names(coef(fit))[names(coef(fit)) != "(Intercept)"]
  avail_feats <- intersect(feats, names(newdata))
  lp <- coef(fit)["(Intercept)"] +
    rowSums(data.frame(lapply(avail_feats, function(f) coef(fit)[f] * newdata[[f]])),
            na.rm=FALSE)
  plogis(lp)
}

# Model B → CLHLS
pr_B_cl <- predict_4y(fit_B, cl_df)
pr_C_cl <- predict_4y(fit_C, cl_df)
pr_D_cl <- predict_4y(fit_D, cl_df)

roc_cindex <- function(event, pred, n_boot=300) {
  c_val <- as.numeric(auc(suppressMessages(roc(event, pred, quiet=TRUE))))
  boot  <- replicate(n_boot, {
    idx <- sample(length(event), replace=TRUE)
    tryCatch(as.numeric(auc(suppressMessages(roc(event[idx], pred[idx], quiet=TRUE)))),
             error=function(e) NA_real_)
  })
  c(c=round(c_val,4), lo=round(quantile(boot,.025,na.rm=T),4),
    hi=round(quantile(boot,.975,na.rm=T),4))
}

valid_cl <- !is.na(pr_B_cl) & !is.na(pr_C_cl) & !is.na(pr_D_cl)
cl_v <- cl_df[valid_cl, ]
pr_B_v <- pr_B_cl[valid_cl]; pr_C_v <- pr_C_cl[valid_cl]; pr_D_v <- pr_D_cl[valid_cl]

cat(sprintf("  CLHLS valid predictions: N=%d\n", sum(valid_cl)))
ci_B <- roc_cindex(cl_v$event, pr_B_v)
ci_C <- roc_cindex(cl_v$event, pr_C_v)
ci_D <- roc_cindex(cl_v$event, pr_D_v)
cat(sprintf("  Model B CLHLS C: %.4f [%.4f–%.4f]\n", ci_B["c"],ci_B["lo"],ci_B["hi"]))
cat(sprintf("  Model C CLHLS C: %.4f [%.4f–%.4f]\n", ci_C["c"],ci_C["lo"],ci_C["hi"]))
cat(sprintf("  Model D CLHLS C: %.4f [%.4f–%.4f]\n", ci_D["c"],ci_D["lo"],ci_D["hi"]))

# ── 5. H5 Verdict ─────────────────────────────────────────────────────────────
drop_B <- c_B_charls - ci_B["c"]   # drop from apparent to external (B)
drop_C <- c_C_charls - ci_C["c"]   # drop from apparent to external (C)
cat(sprintf("\n  Model B drop (apparent→CLHLS): %.4f\n", drop_B))
cat(sprintf("  Model C drop (apparent→CLHLS): %.4f\n", drop_C))
h5_verdict <- ifelse(drop_B < drop_C, "SUPPORTED (FI more stable than IC)",
               ifelse(drop_B > drop_C, "NOT SUPPORTED (IC more stable)", "INCONCLUSIVE"))
cat(sprintf("\n=== H5 VERDICT: %s ===\n", h5_verdict))

# ── 6. Save results ───────────────────────────────────────────────────────────
perf <- data.frame(
  model=c("B_FI","C_IC","D_FI+IC"),
  charls_apparent_C=round(c(c_B_charls, c_C_charls, c_D_charls),4),
  clhls_external_C=round(c(ci_B["c"],  ci_C["c"],  ci_D["c"]), 4),
  clhls_C_lo=round(c(ci_B["lo"],ci_C["lo"],ci_D["lo"]),4),
  clhls_C_hi=round(c(ci_B["hi"],ci_C["hi"],ci_D["hi"]),4),
  drop_apparent_to_external=round(c(drop_B,drop_C,c_D_charls-ci_D["c"]),4),
  row.names=NULL
)
write.csv(perf, file.path(OUT,"h5_model_comparison_2026-07-29.csv"), row.names=FALSE)
cat("\nResults saved to", OUT, "\n")
print(perf)

# Markdown report
rpt <- paste0(
"# H5 Analysis Report (2026-07-29)\n\n",
"## Method\n",
"Model B (FI), Model C (IC five domains), Model D (FI+IC) fitted on CHARLS person-period (periods 1+2).\n",
"IC domains: locomotion (grip+gait+balance), vitality (peak_flow+BMI), cognition (recall+serial7+drawing),\n",
"psychology (CES-D-10 reversed), sensory (vision+hearing min-max normalised 0-100).\n",
"**Note**: CLHLS IC uses binary FI-item proxies (not continuous IC measures) due to limited raw data access.\n",
"Cross-cohort comparison is provisional; full IC external validation is deferred to Paper 2 (D-012).\n\n",
"## Results\n\n",
"| Model | CHARLS Apparent C | CLHLS External C | Drop |\n",
"|---|---:|---:|---:|\n",
paste(sprintf("| %s | %.4f | %.4f [%.4f–%.4f] | %.4f |",
              perf$model, perf$charls_apparent_C, perf$clhls_external_C,
              perf$clhls_C_lo, perf$clhls_C_hi,
              perf$drop_apparent_to_external), collapse="\n"),
"\n\n## H5 Verdict\n\n",
sprintf("**%s**\n\n", h5_verdict),
sprintf("- Model B drop: %.4f | Model C drop: %.4f\n", drop_B, drop_C),
"- **Caveat**: CLHLS IC proxies are binary (from FI items), not continuous IC scores.\n",
"  Full H5 test requires continuous IC for CLHLS (Paper 2, D-012).\n"
)
writeLines(rpt, file.path(OUT,"h5_report_2026-07-29.md"))
