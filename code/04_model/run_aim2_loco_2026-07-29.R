# run_aim2_loco_2026-07-29.R
# Aim 2: LOCO Round A/B/C + downsampling control + L1 recalibration
# SAP §10.2 | Model: event ~ fi_full + age (no female — KLoSA parquet lacks it)
# R: D:/LeStoreDownload/R/R-4.4.1/bin/x64/Rscript.exe --vanilla run_aim2_loco_2026-07-29.R

suppressPackageStartupMessages({
  library(arrow); library(haven); library(pROC); library(dcurves); library(ggplot2)
})
set.seed(2026)
OUT <- "D:/AI_project/project3/results/aim2"
dir.create(file.path(OUT, "figures"), recursive=TRUE, showWarnings=FALSE)

# ── 1. Load & build cohort datasets ──────────────────────────────────────────
cat("=== 1. Loading data ===\n")

# CHARLS: 4-year binary from person-period (periods 1+2, age60+, FI-eligible)
# died_2015 only has 2015-wave deaths (435); person-period captures period-1 deaths too
pp        <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/charls_person_period_2026-07-27.parquet"))
ch_base   <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/charls_baseline_cohort_2026-07-27.parquet"))
ch_fi     <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/charls_fi_2011_2026-07-27.parquet"))
pp60      <- pp[pp$age_60_plus == TRUE & pp$period %in% c(1L, 2L), ]
ch_bin    <- aggregate(event ~ pid, data = pp60, FUN = function(x) as.integer(any(x == 1)))
names(ch_bin)[2] <- "event_4y"
ch_bridge <- ch_base[, c("pid", "id_w1_11", "female")]
ch_temp   <- merge(ch_bin, ch_bridge, by = "pid")
ch_df     <- merge(ch_temp,
                   ch_fi[!ch_fi$fi_excluded, c("id", "fi_full", "age")],
                   by.x = "id_w1_11", by.y = "id")
ch_df$event <- ch_df$event_4y
ch_df <- ch_df[!is.na(ch_df$event) & !is.na(ch_df$fi_full) & !is.na(ch_df$age), ]
cat(sprintf("CHARLS: N=%d  events=%d  rate=%.1f%%
",
            nrow(ch_df), sum(ch_df$event), mean(ch_df$event)*100))

# CLHLS binary (event_4y already integer/logical from parquet)
cl_fi  <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/clhls_fi_2011_2026-07-29.parquet"))
cl_out <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/clhls_outcome_2026-07-28.parquet"))
cl_df  <- merge(cl_fi[cl_fi$age_60_plus==TRUE & !cl_fi$fi_excluded, c("id","fi_full","age")],
                cl_out[!is.na(cl_out$event_4y) & cl_out$prebaseline_death==FALSE,
                       c("id","event_4y","female")], by="id")
cl_df$event <- as.integer(cl_df$event_4y)
cl_df  <- cl_df[!is.na(cl_df$event) & !is.na(cl_df$fi_full) & !is.na(cl_df$age), ]
cat(sprintf("CLHLS:  N=%d  events=%d  rate=%.1f%%\n",
            nrow(cl_df), sum(cl_df$event), mean(cl_df$event)*100))

# KLoSA binary (event_exact_4y = "True"/"False" strings)
kl_fi  <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/klosa_fi_2012_2026-07-29.parquet"))
kl_aud <- read.csv("D:/AI_project/project3/results/current_four_year_event_audit/klosa_four_year_event_audit_2026-07-28.csv",
                   stringsAsFactors=FALSE)
kl_aud$event  <- kl_aud$event_exact_4y == "True"
kl_aud$pre    <- kl_aud$death_before_baseline == "True"
kl_aud$pid_n  <- as.numeric(kl_aud$person_id)
kl_fi$pid_n   <- as.numeric(zap_labels(kl_fi$pid))
kl_df  <- merge(kl_fi[kl_fi$age_60_plus==TRUE & !kl_fi$fi_excluded, c("pid_n","fi_full","age")],
                kl_aud[!kl_aud$pre, c("pid_n","event")], by="pid_n")
kl_df  <- kl_df[!is.na(kl_df$event) & !is.na(kl_df$fi_full) & !is.na(kl_df$age), ]
cat(sprintf("KLoSA:  N=%d  events=%d  rate=%.1f%%\n",
            nrow(kl_df), sum(kl_df$event), mean(kl_df$event)*100))

# ── 2. Helper functions ───────────────────────────────────────────────────────
compute_metrics <- function(event, pred, label="", n_boot=300) {
  pred <- pmin(pmax(pred, 1e-7), 1-1e-7)
  lp   <- qlogis(pred)
  roc_obj  <- suppressMessages(roc(event, pred, quiet=TRUE))
  c_val    <- as.numeric(auc(roc_obj))
  boot_c   <- replicate(n_boot, {
    idx <- sample(length(event), replace=TRUE)
    tryCatch(as.numeric(auc(suppressMessages(roc(event[idx], pred[idx], quiet=TRUE)))),
             error=function(e) NA_real_)
  })
  oe   <- mean(event) / mean(pred)
  m_ci <- glm(event ~ 1 + offset(lp), family=binomial, control=glm.control(maxit=100))
  m_sl <- glm(event ~ lp,             family=binomial, control=glm.control(maxit=100))
  brier <- mean((event - pred)^2)
  ipa   <- 1 - brier / mean((event - mean(event))^2)
  list(label=label, n=length(event), events=sum(event), event_rate=mean(event),
       c_index=round(c_val,4), c_lo=round(quantile(boot_c,.025,na.rm=T),4),
       c_hi=round(quantile(boot_c,.975,na.rm=T),4),
       oe=round(oe,4), cal_intercept=round(coef(m_ci),4), cal_slope=round(coef(m_sl)[2],4),
       brier=round(brier,5), ipa=round(ipa,4))
}

l1_recal <- function(pred, event) {
  lp  <- qlogis(pmin(pmax(pred,1e-7),1-1e-7))
  alp <- coef(glm(event ~ 1 + offset(lp), family=binomial, control=glm.control(maxit=100)))
  plogis(lp + alp)
}

run_loco <- function(train_list, test_df, rname) {
  tr <- do.call(rbind, lapply(train_list, function(d) d[, c("event","fi_full","age")]))
  fit <- glm(event ~ fi_full + age, data=tr, family=binomial)
  cat(sprintf("  [%s] coef: FI=%.3f age=%.4f\n", rname, coef(fit)["fi_full"], coef(fit)["age"]))
  pr  <- predict(fit, newdata=test_df[,c("fi_full","age")], type="response")
  pr_l1 <- l1_recal(pr, test_df$event)
  list(fit=fit, pred=pr, pred_l1=pr_l1,
       m=compute_metrics(test_df$event, pr, paste0(rname,"_raw")),
       m_l1=compute_metrics(test_df$event, pr_l1, paste0(rname,"_L1")))
}

downsample_boot <- function(train_list, test_df, n_target, n_iter=200) {
  tr <- do.call(rbind, lapply(train_list, function(d) d[, c("event","fi_full","age")]))
  replicate(n_iter, {
    idx <- sample(nrow(tr), n_target, replace=FALSE)
    fit_d <- glm(event ~ fi_full + age, data=tr[idx,], family=binomial)
    pr_d  <- predict(fit_d, newdata=test_df[,c("fi_full","age")], type="response")
    tryCatch(as.numeric(auc(suppressMessages(roc(test_df$event, pr_d, quiet=TRUE)))),
             error=function(e) NA_real_)
  })
}

cal_plot <- function(event, pred, title, outpath) {
  df <- data.frame(event=event, pred=pred)
  df$decile <- cut(pred, quantile(pred, probs=seq(0,1,.1)), include.lowest=TRUE, labels=FALSE)
  ag <- aggregate(cbind(obs=event, pre=pred) ~ decile, data=df, FUN=mean)
  png(outpath, width=700, height=650)
  plot(ag$pre, ag$obs, pch=19, col="steelblue", cex=1.4,
       xlim=c(0,1), ylim=c(0,1), xlab="Predicted", ylab="Observed", main=title)
  abline(0,1, lty=2, col="gray60"); lines(lowess(pred, event), col="tomato", lwd=2)
  dev.off()
}

# ── 3. Standardise columns ────────────────────────────────────────────────────
ch <- ch_df[, c("fi_full","age","event")]
cl <- cl_df[, c("fi_full","age","event")]
kl <- kl_df[, c("fi_full","age","event")]

# ── 4. CHARLS-only baselines (for Round B & C comparison) ────────────────────
cat("\n=== CHARLS-only baselines ===\n")
fit_ch_only <- glm(event ~ fi_full + age, data=ch, family=binomial)
cat(sprintf("  CHARLS-only coef: FI=%.3f age=%.4f\n",
            coef(fit_ch_only)["fi_full"], coef(fit_ch_only)["age"]))

# CHARLS → CLHLS
pr_ch2cl    <- predict(fit_ch_only, newdata=cl[,c("fi_full","age")], type="response")
m_ch2cl     <- compute_metrics(cl$event, pr_ch2cl, "CHARLS_only->CLHLS_raw")
m_ch2cl_l1  <- compute_metrics(cl$event, l1_recal(pr_ch2cl, cl$event), "CHARLS_only->CLHLS_L1")
cat(sprintf("  CHARLS→CLHLS  C=%.4f  OE=%.3f  slope=%.3f\n",
            m_ch2cl$c_index, m_ch2cl$oe, m_ch2cl$cal_slope))

# CHARLS → KLoSA
pr_ch2kl    <- predict(fit_ch_only, newdata=kl[,c("fi_full","age")], type="response")
m_ch2kl     <- compute_metrics(kl$event, pr_ch2kl, "CHARLS_only->KLoSA_raw")
m_ch2kl_l1  <- compute_metrics(kl$event, l1_recal(pr_ch2kl, kl$event), "CHARLS_only->KLoSA_L1")
cat(sprintf("  CHARLS→KLoSA  C=%.4f  OE=%.3f  slope=%.3f\n",
            m_ch2kl$c_index, m_ch2kl$oe, m_ch2kl$cal_slope))

# ── 5. LOCO Rounds ────────────────────────────────────────────────────────────
cat("\n=== LOCO Rounds ===\n")
cat("Round A: CLHLS+KLoSA → CHARLS\n")
rA <- run_loco(list(cl, kl), ch, "RoundA")
cat(sprintf("  Raw  C=%.4f  OE=%.3f  slope=%.3f\n", rA$m$c_index, rA$m$oe, rA$m$cal_slope))
cat(sprintf("  L1   C=%.4f  OE=%.3f  slope=%.3f\n", rA$m_l1$c_index, rA$m_l1$oe, rA$m_l1$cal_slope))

cat("Round B: CHARLS+KLoSA → CLHLS\n")
rB <- run_loco(list(ch, kl), cl, "RoundB")
cat(sprintf("  Raw  C=%.4f  OE=%.3f  slope=%.3f\n", rB$m$c_index, rB$m$oe, rB$m$cal_slope))
cat(sprintf("  L1   C=%.4f  OE=%.3f  slope=%.3f\n", rB$m_l1$c_index, rB$m_l1$oe, rB$m_l1$cal_slope))

cat("Round C: CHARLS+CLHLS → KLoSA\n")
rC <- run_loco(list(ch, cl), kl, "RoundC")
cat(sprintf("  Raw  C=%.4f  OE=%.3f  slope=%.3f\n", rC$m$c_index, rC$m$oe, rC$m$cal_slope))
cat(sprintf("  L1   C=%.4f  OE=%.3f  slope=%.3f\n", rC$m_l1$c_index, rC$m_l1$oe, rC$m_l1$cal_slope))

# ── 6. Downsampling bootstrap (Rounds B & C, 200 iter) ───────────────────────
cat("\n=== Downsampling bootstrap (200 iter) ===\n")
n_ch <- nrow(ch)
cat(sprintf("  Target size: %d (CHARLS N)\n", n_ch))

cat("  Round B downsampling (CHARLS+KLoSA → CLHLS)...\n")
boot_B <- downsample_boot(list(ch, kl), cl, n_ch, 200)
cat(sprintf("  boot_B C median=%.4f  [%.4f, %.4f]\n",
            median(boot_B, na.rm=T), quantile(boot_B,.025,na.rm=T), quantile(boot_B,.975,na.rm=T)))

cat("  Round C downsampling (CHARLS+CLHLS → KLoSA)...\n")
boot_C <- downsample_boot(list(ch, cl), kl, n_ch, 200)
cat(sprintf("  boot_C C median=%.4f  [%.4f, %.4f]\n",
            median(boot_C, na.rm=T), quantile(boot_C,.025,na.rm=T), quantile(boot_C,.975,na.rm=T)))

# H3 verdict
delta_B_full     <- rB$m$c_index   - m_ch2cl$c_index
delta_B_downsamp <- median(boot_B, na.rm=T) - m_ch2cl$c_index
delta_C_full     <- rC$m$c_index   - m_ch2kl$c_index
delta_C_downsamp <- median(boot_C, na.rm=T) - m_ch2kl$c_index
cat(sprintf("\n  H3 check:\n"))
cat(sprintf("  Round B: full ΔC=%.4f | downsampled ΔC=%.4f vs CHARLS-only\n", delta_B_full, delta_B_downsamp))
cat(sprintf("  Round C: full ΔC=%.4f | downsampled ΔC=%.4f vs CHARLS-only\n", delta_C_full, delta_C_downsamp))

# ── 7. Calibration plots ──────────────────────────────────────────────────────
cal_plot(ch$event, rA$pred,    "Round A: CLHLS+KLoSA → CHARLS (raw)",
         file.path(OUT,"figures","cal_roundA_raw_2026-07-29.png"))
cal_plot(ch$event, rA$pred_l1, "Round A: CLHLS+KLoSA → CHARLS (L1 recal)",
         file.path(OUT,"figures","cal_roundA_L1_2026-07-29.png"))
cal_plot(cl$event, rB$pred_l1, "Round B: CHARLS+KLoSA → CLHLS (L1 recal)",
         file.path(OUT,"figures","cal_roundB_L1_2026-07-29.png"))
cal_plot(kl$event, rC$pred_l1, "Round C: CHARLS+CLHLS → KLoSA (L1 recal)",
         file.path(OUT,"figures","cal_roundC_L1_2026-07-29.png"))

# ── 8. Performance table CSV ──────────────────────────────────────────────────
all_metrics <- list(
  m_ch2cl,  m_ch2cl_l1,
  m_ch2kl,  m_ch2kl_l1,
  rA$m,  rA$m_l1,
  rB$m,  rB$m_l1,
  rC$m,  rC$m_l1
)
perf_df <- do.call(rbind, lapply(all_metrics, function(m) as.data.frame(m, stringsAsFactors=FALSE)))
write.csv(perf_df, file.path(OUT,"aim2_loco_performance_2026-07-29.csv"), row.names=FALSE)
cat("\nPerformance table written.\n")

# ── 9. Markdown report ────────────────────────────────────────────────────────
h3_B <- ifelse(delta_B_downsamp > 0, "SUPPORTED (downsampled ΔC > 0)",
               ifelse(delta_B_full > 0, "AMBIGUOUS (full > 0 but downsampled ≤ 0)", "NOT SUPPORTED"))
h3_C <- ifelse(delta_C_downsamp > 0, "SUPPORTED (downsampled ΔC > 0)",
               ifelse(delta_C_full > 0, "AMBIGUOUS (full > 0 but downsampled ≤ 0)", "NOT SUPPORTED"))
report <- paste0(
"# Aim 2 LOCO Report (2026-07-29)\n\n",
"## Cohort summary\n",
sprintf("| Cohort | N | Events | Event rate |\n|---|---:|---:|---:|\n"),
sprintf("| CHARLS | %d | %d | %.1f%% |\n", nrow(ch), sum(ch$event), mean(ch$event)*100),
sprintf("| CLHLS  | %d | %d | %.1f%% |\n", nrow(cl), sum(cl$event), mean(cl$event)*100),
sprintf("| KLoSA  | %d | %d | %.1f%% |\n", nrow(kl), sum(kl$event), mean(kl$event)*100),
"\n## Model specification\n",
"Binary logistic regression: `event ~ fi_full + age` (no female — KLoSA parquet lacks sex variable)\n\n",
"## LOCO performance\n\n",
"| Round | Train | Test | C-index | O:E | Cal slope | Brier | IPA |\n",
"|---|---|---|---:|---:|---:|---:|---:|\n",
sprintf("| A raw    | CLHLS+KLoSA | CHARLS | %.4f | %.3f | %.3f | %.4f | %.4f |\n",
        rA$m$c_index, rA$m$oe, rA$m$cal_slope, rA$m$brier, rA$m$ipa),
sprintf("| A L1     | CLHLS+KLoSA | CHARLS | %.4f | %.3f | %.3f | %.4f | %.4f |\n",
        rA$m_l1$c_index, rA$m_l1$oe, rA$m_l1$cal_slope, rA$m_l1$brier, rA$m_l1$ipa),
sprintf("| B raw    | CHARLS+KLoSA | CLHLS | %.4f | %.3f | %.3f | %.4f | %.4f |\n",
        rB$m$c_index, rB$m$oe, rB$m$cal_slope, rB$m$brier, rB$m$ipa),
sprintf("| B L1     | CHARLS+KLoSA | CLHLS | %.4f | %.3f | %.3f | %.4f | %.4f |\n",
        rB$m_l1$c_index, rB$m_l1$oe, rB$m_l1$cal_slope, rB$m_l1$brier, rB$m_l1$ipa),
sprintf("| C raw    | CHARLS+CLHLS | KLoSA | %.4f | %.3f | %.3f | %.4f | %.4f |\n",
        rC$m$c_index, rC$m$oe, rC$m$cal_slope, rC$m$brier, rC$m$ipa),
sprintf("| C L1     | CHARLS+CLHLS | KLoSA | %.4f | %.3f | %.3f | %.4f | %.4f |\n",
        rC$m_l1$c_index, rC$m_l1$oe, rC$m_l1$cal_slope, rC$m_l1$brier, rC$m_l1$ipa),
"\n## CHARLS-only baselines\n\n",
"| Model | Test | C-index | O:E | Cal slope |\n|---|---|---:|---:|---:|\n",
sprintf("| CHARLS-only raw | CLHLS | %.4f | %.3f | %.3f |\n", m_ch2cl$c_index, m_ch2cl$oe, m_ch2cl$cal_slope),
sprintf("| CHARLS-only L1  | CLHLS | %.4f | %.3f | %.3f |\n", m_ch2cl_l1$c_index, m_ch2cl_l1$oe, m_ch2cl_l1$cal_slope),
sprintf("| CHARLS-only raw | KLoSA | %.4f | %.3f | %.3f |\n", m_ch2kl$c_index, m_ch2kl$oe, m_ch2kl$cal_slope),
sprintf("| CHARLS-only L1  | KLoSA | %.4f | %.3f | %.3f |\n", m_ch2kl_l1$c_index, m_ch2kl_l1$oe, m_ch2kl_l1$cal_slope),
"\n## H3 verdict (downsampling control)\n\n",
sprintf("- **Round B** (adding KLoSA to CHARLS, test=CLHLS): ΔC full=%.4f, downsampled=%.4f → **%s**\n", delta_B_full, delta_B_downsamp, h3_B),
sprintf("- **Round C** (adding CLHLS to CHARLS, test=KLoSA): ΔC full=%.4f, downsampled=%.4f → **%s**\n", delta_C_full, delta_C_downsamp, h3_C),
"\n## Education note\n",
"Female was excluded from all LOCO models for cross-cohort consistency (KLoSA FI parquet lacks sex variable).\n",
"This differs from Aim 1 (which used fi_full + age + female on CHARLS person-period).\n"
)
writeLines(report, file.path(OUT,"aim2_loco_report_2026-07-29.md"))

# Save bootstrap distributions
boot_df <- data.frame(
  round=c(rep("B_CHARLS_KLoSA_CLHLS",200), rep("C_CHARLS_CLHLS_KLoSA",200)),
  c_index_downsampled=c(boot_B, boot_C)
)
write.csv(boot_df, file.path(OUT,"aim2_downsample_bootstrap_2026-07-29.csv"), row.names=FALSE)

cat("\nAim 2 LOCO complete. All files written to", OUT, "\n")
