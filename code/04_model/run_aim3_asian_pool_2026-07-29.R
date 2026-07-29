# run_aim3_asian_pool_2026-07-29.R
# Aim 3: Asian pool (CHARLS+CLHLS+KLoSA) → HRS, SHARE, MHAS
# Full L0-L3 recalibration ladder | Model: event ~ fi_full + age
# R: D:/LeStoreDownload/R/R-4.4.1/bin/x64/Rscript.exe --vanilla run_aim3_asian_pool_2026-07-29.R

suppressPackageStartupMessages({
  library(arrow); library(haven); library(pROC)
})
set.seed(2026)
OUT <- "D:/AI_project/project3/results/aim3"
dir.create(file.path(OUT,"figures"), recursive=TRUE, showWarnings=FALSE)

# ── Helper functions (same as Aim2) ──────────────────────────────────────────
compute_metrics <- function(event, pred, label="", n_boot=300) {
  pred <- pmin(pmax(pred, 1e-7), 1-1e-7); lp <- qlogis(pred)
  roc_obj <- suppressMessages(roc(event, pred, quiet=TRUE))
  c_val   <- as.numeric(auc(roc_obj))
  boot_c  <- replicate(n_boot, {
    idx <- sample(length(event), replace=TRUE)
    tryCatch(as.numeric(auc(suppressMessages(roc(event[idx], pred[idx], quiet=TRUE)))), error=function(e) NA_real_)
  })
  oe  <- mean(event) / mean(pred)
  m_ci <- glm(event ~ 1 + offset(lp), family=binomial, control=glm.control(maxit=100))
  m_sl <- glm(event ~ lp, family=binomial, control=glm.control(maxit=100))
  brier <- mean((event - pred)^2); ipa <- 1 - brier/mean((event - mean(event))^2)
  list(label=label, n=length(event), events=sum(event), event_rate=mean(event),
       c_index=round(c_val,4), c_lo=round(quantile(boot_c,.025,na.rm=T),4),
       c_hi=round(quantile(boot_c,.975,na.rm=T),4),
       oe=round(oe,4), cal_intercept=round(coef(m_ci),4),
       cal_slope=round(coef(m_sl)[2],4), brier=round(brier,5), ipa=round(ipa,4))
}

recal_ladder <- function(event, pred, fi, age, label) {
  lp <- qlogis(pmin(pmax(pred,1e-7),1-1e-7))
  # L0: frozen
  m0 <- compute_metrics(event, pred, paste0(label,"_L0"))
  # L1: intercept update
  a1 <- coef(glm(event~1+offset(lp), family=binomial, control=glm.control(maxit=100)))
  m1 <- compute_metrics(event, plogis(lp+a1), paste0(label,"_L1"))
  # L2: slope + intercept (2-parameter recal)
  sl <- glm(event~lp, family=binomial, control=glm.control(maxit=100))
  p2 <- plogis(coef(sl)[1] + coef(sl)[2]*lp)
  m2 <- compute_metrics(event, p2, paste0(label,"_L2"))
  # L3: full refit in target cohort (oracle ceiling)
  df3 <- data.frame(event=event, fi_full=fi, age=age)
  fit3 <- glm(event~fi_full+age, data=df3, family=binomial)
  p3 <- predict(fit3, type="response")
  m3 <- compute_metrics(event, p3, paste0(label,"_L3"))
  list(L0=m0, L1=m1, L2=m2, L3=m3)
}

cal_plot <- function(event, pred, title, outpath) {
  df <- data.frame(event=event, pred=pred)
  df$dec <- cut(pred, quantile(pred,probs=seq(0,1,.1)), include.lowest=TRUE, labels=FALSE)
  ag <- aggregate(cbind(obs=event,pre=pred)~dec, data=df, FUN=mean)
  png(outpath, width=700, height=650)
  plot(ag$pre, ag$obs, pch=19, col="steelblue", cex=1.4,
       xlim=c(0,1), ylim=c(0,1), xlab="Predicted", ylab="Observed", main=title)
  abline(0,1,lty=2,col="gray60"); lines(lowess(pred,event),col="tomato",lwd=2)
  dev.off()
}

# ── 1. Rebuild Asian pool (from Aim2 verified data) ──────────────────────────
cat("=== 1. Building Asian pool ===\n")
pp      <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/charls_person_period_2026-07-27.parquet"))
ch_base <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/charls_baseline_cohort_2026-07-27.parquet"))
ch_fi   <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/charls_fi_2011_2026-07-27.parquet"))
pp60    <- pp[pp$age_60_plus==TRUE & pp$period %in% c(1L,2L), ]
ch_bin  <- aggregate(event~pid, data=pp60, FUN=function(x) as.integer(any(x==1)))
names(ch_bin)[2] <- "event_4y"
ch_temp <- merge(ch_bin, ch_base[,c("pid","id_w1_11")], by="pid")
ch_df   <- merge(ch_temp, ch_fi[!ch_fi$fi_excluded, c("id","fi_full","age")],
                 by.x="id_w1_11", by.y="id")
ch_df$event <- ch_df$event_4y
ch_df <- ch_df[!is.na(ch_df$event) & !is.na(ch_df$fi_full) & !is.na(ch_df$age), ]

cl_fi  <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/clhls_fi_2011_2026-07-29.parquet"))
cl_out <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/clhls_outcome_2026-07-28.parquet"))
cl_df  <- merge(cl_fi[cl_fi$age_60_plus==TRUE & !cl_fi$fi_excluded, c("id","fi_full","age")],
                cl_out[!is.na(cl_out$event_4y) & cl_out$prebaseline_death==FALSE,
                       c("id","event_4y")], by="id")
cl_df$event <- as.integer(cl_df$event_4y)
cl_df <- cl_df[!is.na(cl_df$event) & !is.na(cl_df$fi_full) & !is.na(cl_df$age), ]

kl_fi  <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/klosa_fi_2012_2026-07-29.parquet"))
kl_aud <- read.csv("D:/AI_project/project3/results/current_four_year_event_audit/klosa_four_year_event_audit_2026-07-28.csv", stringsAsFactors=FALSE)
kl_aud$event <- kl_aud$event_exact_4y=="True"; kl_aud$pre <- kl_aud$death_before_baseline=="True"
kl_aud$pid_n <- as.numeric(kl_aud$person_id)
kl_fi$pid_n  <- as.numeric(suppressWarnings(haven::zap_labels(kl_fi$pid)))
kl_df <- merge(kl_fi[kl_fi$age_60_plus==TRUE & !kl_fi$fi_excluded, c("pid_n","fi_full","age")],
               kl_aud[!kl_aud$pre, c("pid_n","event")], by="pid_n")
kl_df <- kl_df[!is.na(kl_df$event) & !is.na(kl_df$fi_full) & !is.na(kl_df$age), ]

# Fit Asian pool model
pool <- rbind(
  ch_df[, c("fi_full","age","event")],
  cl_df[, c("fi_full","age","event")],
  kl_df[, c("fi_full","age","event")]
)
cat(sprintf("Asian pool: N=%d  events=%d  rate=%.1f%%\n",
            nrow(pool), sum(pool$event), mean(pool$event)*100))
fit_pool <- glm(event ~ fi_full + age, data=pool, family=binomial)
cat(sprintf("Pool coef: FI=%.3f  age=%.4f  intercept=%.3f\n",
            coef(fit_pool)["fi_full"], coef(fit_pool)["age"], coef(fit_pool)["(Intercept)"]))

# ── 2. HRS validation dataset ─────────────────────────────────────────────────
cat("\n=== 2. Building HRS dataset ===\n")
hrs_exit <- as.data.frame(read_parquet("D:/AI_project/project3/data/interim/hrs_exit_deaths_2026-07-27.parquet"))
hrs_fi   <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/hrs_fi_2012_2026-07-29.parquet"))
hrs_fi$id9   <- sprintf("%09d", as.integer(as.character(hrs_fi$hhidpn)))
hrs_exit$id9 <- sprintf("%09d", as.integer(as.character(hrs_exit$hhidpn)))
died4y_hrs <- hrs_exit$id9[hrs_exit$in_4y_window==TRUE]
hrs_elig   <- hrs_fi[hrs_fi$age_60_plus==TRUE & !hrs_fi$fi_excluded, ]
hrs_df     <- data.frame(id=hrs_elig$id9, fi_full=hrs_elig$fi_full, age=hrs_elig$age,
                         event=as.integer(hrs_elig$id9 %in% died4y_hrs))
hrs_df <- hrs_df[!is.na(hrs_df$fi_full) & !is.na(hrs_df$age), ]
cat(sprintf("HRS: N=%d  events=%d  rate=%.1f%%\n",
            nrow(hrs_df), sum(hrs_df$event), mean(hrs_df$event)*100))

# ── 3. SHARE validation dataset ──────────────────────────────────────────────
cat("\n=== 3. Building SHARE dataset ===\n")
sh_fi  <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/share_fi_2011_2026-07-29.parquet"))
sh_aud <- read.csv("D:/AI_project/project3/results/current_four_year_event_audit/share_four_year_event_audit_2026-07-28.csv", stringsAsFactors=FALSE)
sh_aud$event <- sh_aud$event_exact_4y == "True"
sh_aud$pre   <- sh_aud$death_before_baseline == "True"
sh_df <- merge(
  sh_fi[sh_fi$age_60_plus==TRUE & !sh_fi$fi_excluded, c("id","fi_full","age")],
  sh_aud[!sh_aud$pre, c("person_id","event")],
  by.x="id", by.y="person_id"
)
sh_df <- sh_df[!is.na(sh_df$event) & !is.na(sh_df$fi_full) & !is.na(sh_df$age), ]
sh_df$country <- sub("-.*","", sh_df$id)   # 2-letter country code from id prefix
cat(sprintf("SHARE: N=%d  events=%d  rate=%.1f%%  countries=%d\n",
            nrow(sh_df), sum(sh_df$event), mean(sh_df$event)*100,
            length(unique(sh_df$country))))

# ── 4. MHAS validation dataset ────────────────────────────────────────────────
cat("\n=== 4. Building MHAS dataset ===\n")
mh_fi  <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/mhas_fi_2012_2026-07-28.parquet"))
mh_aud <- read.csv("D:/AI_project/project3/results/current_four_year_event_audit/mhas_four_year_event_audit_2026-07-28.csv", stringsAsFactors=FALSE)
mh_aud$event <- mh_aud$event_exact_4y == "True"
mh_aud$pre   <- mh_aud$death_before_baseline == "True"
mh_fi$pid_n  <- as.numeric(as.character(mh_fi$rahhidnp))
mh_aud$pid_n <- as.numeric(mh_aud$person_id)
mh_df <- merge(
  mh_fi[mh_fi$age_60_plus==TRUE & !mh_fi$fi_excluded, c("pid_n","fi_full","age")],
  mh_aud[!mh_aud$pre, c("pid_n","event")],
  by="pid_n"
)
mh_df <- mh_df[!is.na(mh_df$event) & !is.na(mh_df$fi_full) & !is.na(mh_df$age), ]
cat(sprintf("MHAS: N=%d  events=%d  rate=%.1f%%\n",
            nrow(mh_df), sum(mh_df$event), mean(mh_df$event)*100))

# ── 5. Apply Asian pool model → each validation cohort, L0-L3 ladder ─────────
cat("\n=== 5. L0-L3 Recalibration Ladder ===\n")
all_results <- list()

for (info in list(
  list(df=hrs_df, name="HRS"),
  list(df=sh_df,  name="SHARE"),
  list(df=mh_df,  name="MHAS")
)) {
  df <- info$df; nm <- info$name
  pred <- predict(fit_pool, newdata=df[,c("fi_full","age")], type="response")
  ladder <- recal_ladder(df$event, pred, df$fi_full, df$age, nm)
  for (lv in c("L0","L1","L2","L3")) {
    m <- ladder[[lv]]
    cat(sprintf("  %s %s: C=%.4f  OE=%.3f  slope=%.3f  IPA=%.4f\n",
                nm, lv, m$c_index, m$oe, m$cal_slope, m$ipa))
    all_results[[paste0(nm,"_",lv)]] <- m
  }
  # Calibration plots (L0 and L1)
  cal_plot(df$event, pred,
           sprintf("%s: Asian pool (L0, raw)", nm),
           file.path(OUT,"figures",sprintf("cal_%s_L0_2026-07-29.png", tolower(nm))))
  lp <- qlogis(pmin(pmax(pred,1e-7),1-1e-7))
  a1 <- coef(glm(df$event~1+offset(lp), family=binomial, control=glm.control(maxit=100)))
  cal_plot(df$event, plogis(lp+a1),
           sprintf("%s: Asian pool (L1 recal)", nm),
           file.path(OUT,"figures",sprintf("cal_%s_L1_2026-07-29.png", tolower(nm))))
}

# ── 6. SHARE within-country C-index (discrimination stability) ────────────────
cat("\n=== 6. SHARE within-country C-index ===\n")
countries <- sort(unique(sh_df$country))
country_metrics <- lapply(countries, function(cc) {
  sub_df <- sh_df[sh_df$country == cc, ]
  if (sum(sub_df$event) < 5 || nrow(sub_df) < 20) return(NULL)
  pred_c <- predict(fit_pool, newdata=sub_df[,c("fi_full","age")], type="response")
  c_val  <- tryCatch(as.numeric(auc(suppressMessages(roc(sub_df$event, pred_c, quiet=TRUE)))),
                     error=function(e) NA_real_)
  data.frame(country=cc, n=nrow(sub_df), events=sum(sub_df$event),
             event_rate=mean(sub_df$event), c_index=round(c_val,4))
})
cc_df <- do.call(rbind, Filter(Negate(is.null), country_metrics))
cat(sprintf("SHARE within-country C-index: median=%.4f  range=[%.4f, %.4f]  n_countries=%d\n",
            median(cc_df$c_index, na.rm=TRUE),
            min(cc_df$c_index, na.rm=TRUE),
            max(cc_df$c_index, na.rm=TRUE),
            nrow(cc_df)))
write.csv(cc_df, file.path(OUT,"aim3_share_country_cindex_2026-07-29.csv"), row.names=FALSE)

# ── 7. Output ─────────────────────────────────────────────────────────────────
perf_df <- do.call(rbind, lapply(all_results, function(m) as.data.frame(m, stringsAsFactors=FALSE)))
write.csv(perf_df, file.path(OUT,"aim3_performance_table_2026-07-29.csv"), row.names=FALSE)

# Markdown report
rpt <- paste0(
"# Aim 3 Report (2026-07-29)\n\n",
"## Asian pool training set\n",
sprintf("| Cohort | N | Events | Rate |\n|---|---:|---:|---:|\n"),
sprintf("| CHARLS | %d | %d | %.1f%% |\n", nrow(ch_df), sum(ch_df$event), mean(ch_df$event)*100),
sprintf("| CLHLS  | %d | %d | %.1f%% |\n", nrow(cl_df), sum(cl_df$event), mean(cl_df$event)*100),
sprintf("| KLoSA  | %d | %d | %.1f%% |\n", nrow(kl_df), sum(kl_df$event), mean(kl_df$event)*100),
sprintf("| **Pool total** | **%d** | **%d** | **%.1f%%** |\n\n",
        nrow(pool), sum(pool$event), mean(pool$event)*100),
"Asian pool model: `event ~ fi_full + age` (no female — cross-cohort consistency)\n\n",
sprintf("Coefficients: FI=%.3f  age=%.4f  intercept=%.3f\n\n",
        coef(fit_pool)["fi_full"], coef(fit_pool)["age"], coef(fit_pool)["(Intercept)"]),
"## L0-L3 recalibration ladder\n\n",
"| Cohort | Level | N | Events | Rate | C-index | O:E | Cal slope | IPA |\n",
"|---|---|---:|---:|---:|---:|---:|---:|---:|\n"
)
for (nm in c("HRS","SHARE","MHAS")) {
  df_cur <- switch(nm, HRS=hrs_df, SHARE=sh_df, MHAS=mh_df)
  for (lv in c("L0","L1","L2","L3")) {
    m <- all_results[[paste0(nm,"_",lv)]]
    rpt <- paste0(rpt, sprintf("| %s | %s | %d | %d | %.1f%% | %.4f | %.3f | %.3f | %.4f |\n",
                               nm, lv, m$n, m$events, m$event_rate*100,
                               m$c_index, m$oe, m$cal_slope, m$ipa))
  }
}
rpt <- paste0(rpt, sprintf(
"\n## SHARE within-country discrimination\n",
"- Median C-index: %.4f (range %.4f–%.4f, %d countries)\n",
"- Full table: aim3_share_country_cindex_2026-07-29.csv\n",
median(cc_df$c_index,na.rm=T), min(cc_df$c_index,na.rm=T),
max(cc_df$c_index,na.rm=T), nrow(cc_df)))
writeLines(rpt, file.path(OUT,"aim3_report_2026-07-29.md"))
cat("\nAim 3 complete. All files written to", OUT, "\n")
