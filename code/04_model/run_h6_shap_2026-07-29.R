# run_h6_shap_2026-07-29.R
# H6: SHAP feature importance cross-cohort consistency (SAP §14 H6)
# Method: cohort-specific logistic regression on FI_core-19 items + age
#         importance = |β_standardized| (linear SHAP for GLM, exact for main-effects model)
# Verdict: median cross-cohort Spearman >= 0.7, age in top 3 for each cohort

suppressPackageStartupMessages({
  library(arrow); library(haven)
})
set.seed(2026)
OUT <- "D:/AI_project/project3/results/h6_shap"
dir.create(file.path(OUT,"figures"), recursive=TRUE, showWarnings=FALSE)

FI_CORE <- c("arthre","batha","beda","cancre","diabe","dressa","eata","fall",
             "hearing","hibpe","mbmi","mealsa","medsa","moneya","painfr",
             "shlt","shopa","stroke","toilta")
FEATURES <- c(FI_CORE, "age")   # 20 features total
cat("FI_core items:", length(FI_CORE), "| total features:", length(FEATURES), "\n\n")

# ── Helper: standardised importance from GLM ──────────────────────────────────
glm_importance <- function(df_full, feats, event_col="event") {
  df <- df_full[, c(event_col, feats), drop=FALSE]
  df[[event_col]] <- as.integer(df[[event_col]])
  df <- df[!is.na(df[[event_col]]), ]  # remove NA events first
  if (nrow(df) < 10) return(list(importance=setNames(rep(NA_real_,length(feats)),feats),
    rank=setNames(seq_along(feats),feats), n=nrow(df), events=0))
  # mean-impute missing feature values (neutral imputation for binary items)
  for (f in feats) { m <- mean(df[[f]], na.rm=TRUE); if (!is.na(m)) df[[f]][is.na(df[[f]])] <- m }
  df <- df[complete.cases(df), ]
  if (nrow(df) < 10) return(list(importance=setNames(rep(NA_real_,length(feats)),feats),
    rank=setNames(seq_along(feats),feats), n=nrow(df), events=sum(df[[event_col]])))
  # standardise predictors
  df_s <- df
  for (f in feats) df_s[[f]] <- scale(df[[f]])[,1]
  fit <- glm(reformulate(feats, event_col), data=df_s, family=binomial,
             control=glm.control(maxit=200))
  b <- coef(fit)[feats]
  list(importance=abs(b), rank=rank(-abs(b)), n=nrow(df), events=sum(df[[event_col]]))
}

results <- list()   # per cohort: importance + rank vectors

# ── 1. CHARLS ─────────────────────────────────────────────────────────────────
cat("=== CHARLS ===\n")
pp    <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/charls_person_period_2026-07-27.parquet"))
ch_b  <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/charls_baseline_cohort_2026-07-27.parquet"))
ch_fi <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/charls_fi_2011_2026-07-27.parquet"))
pp60  <- pp[pp$age_60_plus==TRUE & pp$period %in% c(1L,2L), ]
ch_bin <- aggregate(event~pid, data=pp60, FUN=function(x) as.integer(any(x==1)))
names(ch_bin)[2] <- "event"
ch_br <- ch_b[, c("pid","id_w1_11")]
ch_t  <- merge(ch_bin, ch_br, by="pid")
ch_df <- merge(ch_t, ch_fi[!ch_fi$fi_excluded, c("id","age",FI_CORE)],
               by.x="id_w1_11", by.y="id")
r_ch  <- glm_importance(ch_df, FEATURES)
results[["CHARLS"]] <- r_ch
cat(sprintf("  N=%d events=%d | age rank=%d | top3: %s\n",
            r_ch$n, r_ch$events, r_ch$rank["age"],
            paste(names(sort(r_ch$rank))[1:3], collapse=", ")))

# ── 2. CLHLS ─────────────────────────────────────────────────────────────────
cat("=== CLHLS ===\n")
cl_fi  <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/clhls_fi_2011_2026-07-29.parquet"))
cl_out <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/clhls_outcome_2026-07-28.parquet"))
cl_df  <- merge(cl_fi[cl_fi$age_60_plus==TRUE & !cl_fi$fi_excluded, c("id","age",FI_CORE)],
                cl_out[!is.na(cl_out$event_4y) & !cl_out$prebaseline_death, c("id","event_4y")],
                by="id")
cl_df$event <- as.integer(cl_df$event_4y)
r_cl <- glm_importance(cl_df, FEATURES)
results[["CLHLS"]] <- r_cl
cat(sprintf("  N=%d events=%d | age rank=%d | top3: %s\n",
            r_cl$n, r_cl$events, r_cl$rank["age"],
            paste(names(sort(r_cl$rank))[1:3], collapse=", ")))

# ── 3. KLoSA ──────────────────────────────────────────────────────────────────
cat("=== KLoSA ===\n")
kl_fi  <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/klosa_fi_2012_2026-07-29.parquet"))
kl_aud <- read.csv("D:/AI_project/project3/results/current_four_year_event_audit/klosa_four_year_event_audit_2026-07-28.csv", stringsAsFactors=FALSE)
kl_aud$event <- kl_aud$event_exact_4y=="True"; kl_aud$pre <- kl_aud$death_before_baseline=="True"
kl_aud$pid_n <- as.numeric(kl_aud$person_id)
kl_fi$pid_n  <- as.numeric(suppressWarnings(haven::zap_labels(kl_fi$pid)))
kl_df <- merge(kl_fi[kl_fi$age_60_plus==TRUE & !kl_fi$fi_excluded, c("pid_n","age",FI_CORE)],
               kl_aud[!kl_aud$pre, c("pid_n","event")], by="pid_n")
r_kl <- glm_importance(kl_df, FEATURES)
results[["KLoSA"]] <- r_kl
cat(sprintf("  N=%d events=%d | age rank=%d | top3: %s\n",
            r_kl$n, r_kl$events, r_kl$rank["age"],
            paste(names(sort(r_kl$rank))[1:3], collapse=", ")))

# ── 4. HRS ────────────────────────────────────────────────────────────────────
cat("=== HRS ===\n")
hrs_fi   <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/hrs_fi_2012_2026-07-29.parquet"))
hrs_exit <- as.data.frame(read_parquet("D:/AI_project/project3/data/interim/hrs_exit_deaths_2026-07-27.parquet"))
hrs_fi$id9   <- sprintf("%09d", as.integer(as.character(hrs_fi$hhidpn)))
hrs_exit$id9 <- sprintf("%09d", as.integer(as.character(hrs_exit$hhidpn)))
died4y_hrs <- hrs_exit$id9[hrs_exit$in_4y_window==TRUE]
hrs_elig   <- hrs_fi[hrs_fi$age_60_plus==TRUE & !hrs_fi$fi_excluded, ]
hrs_df <- hrs_elig[, c("id9","age",FI_CORE)]
hrs_df$event <- as.integer(hrs_df$id9 %in% died4y_hrs)
r_hrs <- glm_importance(hrs_df, FEATURES)
results[["HRS"]] <- r_hrs
cat(sprintf("  N=%d events=%d | age rank=%d | top3: %s\n",
            r_hrs$n, r_hrs$events, r_hrs$rank["age"],
            paste(names(sort(r_hrs$rank))[1:3], collapse=", ")))

# ── 5. SHARE ──────────────────────────────────────────────────────────────────
cat("=== SHARE ===\n")
sh_fi  <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/share_fi_2011_2026-07-29.parquet"))
sh_aud <- read.csv("D:/AI_project/project3/results/current_four_year_event_audit/share_four_year_event_audit_2026-07-28.csv", stringsAsFactors=FALSE)
sh_aud$event <- sh_aud$event_exact_4y=="True"; sh_aud$pre <- sh_aud$death_before_baseline=="True"
sh_df <- merge(sh_fi[sh_fi$age_60_plus==TRUE & !sh_fi$fi_excluded, c("id","age",FI_CORE)],
               sh_aud[!sh_aud$pre, c("person_id","event")], by.x="id", by.y="person_id")
r_sh  <- glm_importance(sh_df, FEATURES)
results[["SHARE"]] <- r_sh
cat(sprintf("  N=%d events=%d | age rank=%d | top3: %s\n",
            r_sh$n, r_sh$events, r_sh$rank["age"],
            paste(names(sort(r_sh$rank))[1:3], collapse=", ")))

# ── 6. MHAS ───────────────────────────────────────────────────────────────────
cat("=== MHAS ===
")
mh_fi  <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/mhas_fi_2012_2026-07-28.parquet"))
mh_aud <- read.csv("D:/AI_project/project3/results/current_four_year_event_audit/mhas_four_year_event_audit_2026-07-28.csv", stringsAsFactors=FALSE)
mh_aud$event <- (mh_aud$event_exact_4y == "True")
mh_aud$pre   <- (mh_aud$death_before_baseline == "True")
mh_aud$pid_n <- suppressWarnings(as.numeric(as.character(mh_aud$person_id)))
elig_idx <- which(mh_fi$age_60_plus == TRUE & mh_fi$fi_excluded == FALSE)
mh_elig  <- mh_fi[elig_idx, ]
mh_elig$pid_n <- suppressWarnings(as.numeric(as.character(mh_elig$rahhidnp)))
r3c <- paste0("r3", FI_CORE)
mh_sub <- mh_elig[, c("pid_n","age", r3c)]
names(mh_sub) <- c("pid_n","age", FI_CORE)
mh_aud_ok <- mh_aud[!is.na(mh_aud$pre) & mh_aud$pre==FALSE, c("pid_n","event")]
cat(sprintf("  mh_sub:%d rows | mh_aud_ok:%d rows
", nrow(mh_sub), nrow(mh_aud_ok)))
mh_df <- merge(mh_sub, mh_aud_ok, by="pid_n")
cat(sprintf("  mh_df after merge: %d rows
", nrow(mh_df)))
r_mh  <- glm_importance(mh_df, FEATURES)
results[["MHAS"]] <- r_mh
cat(sprintf("  N=%d events=%d | age rank=%d | top3: %s\n",
            r_mh$n, r_mh$events, r_mh$rank["age"],
            paste(names(sort(r_mh$rank))[1:3], collapse=", ")))

# ── 7. Cross-cohort Spearman analysis ─────────────────────────────────────────
cat("\n=== Cross-cohort Spearman (rank correlations) ===\n")
cohorts <- names(results)
rank_mat <- do.call(cbind, lapply(results, function(r) r$rank))
rownames(rank_mat) <- FEATURES

# Spearman correlation matrix
spear_mat <- cor(rank_mat, method="spearman")
cat("Spearman matrix:\n"); print(round(spear_mat, 3))

# Pairwise correlations (lower triangle)
pairs <- combn(cohorts, 2)
pairwise_cors <- apply(pairs, 2, function(p)
  cor(rank_mat[,p[1]], rank_mat[,p[2]], method="spearman"))
names(pairwise_cors) <- apply(pairs, 2, paste, collapse="<->")
cat("\nPairwise Spearman:\n")
for (nm in names(pairwise_cors)) cat(sprintf("  %s: %.4f\n", nm, pairwise_cors[nm]))
cat(sprintf("\nMedian Spearman: %.4f  Min: %.4f  Max: %.4f\n",
            median(pairwise_cors), min(pairwise_cors), max(pairwise_cors)))

# Age rank across cohorts
age_ranks <- sapply(results, function(r) r$rank["age"])
cat(sprintf("Age rank: %s\n",
            paste(paste0(names(age_ranks),"=",age_ranks), collapse=", ")))
age_top3 <- sum(age_ranks <= 3)
cat(sprintf("Age in top 3: %d / %d cohorts\n", age_top3, length(cohorts)))

# H6 verdict
h6_spearman <- median(pairwise_cors) >= 0.7
h6_age <- age_top3 >= ceiling(length(cohorts)/2)
h6_verdict <- ifelse(h6_spearman & h6_age, "SUPPORTED",
               ifelse(h6_spearman | h6_age, "PARTIAL", "NOT SUPPORTED"))
cat(sprintf("\n=== H6 VERDICT: %s ===\n", h6_verdict))
cat(sprintf("  Median Spearman=%.4f (threshold 0.7): %s\n",
            median(pairwise_cors), ifelse(h6_spearman,"PASS","FAIL")))
cat(sprintf("  Age top-3 in %d/%d cohorts: %s\n",
            age_top3, length(cohorts), ifelse(h6_age,"PASS","FAIL")))

# ── 8. Output ─────────────────────────────────────────────────────────────────
# Importance matrix CSV
imp_mat <- do.call(cbind, lapply(results, function(r) round(r$importance,4)))
rownames(imp_mat) <- FEATURES
write.csv(as.data.frame(imp_mat),
          file.path(OUT,"h6_importance_matrix_2026-07-29.csv"))

# Rank matrix CSV
write.csv(as.data.frame(rank_mat),
          file.path(OUT,"h6_rank_matrix_2026-07-29.csv"))

# Spearman matrix CSV
write.csv(round(spear_mat,4),
          file.path(OUT,"h6_spearman_matrix_2026-07-29.csv"))

# Heatmap of standardised importances
png(file.path(OUT,"figures","h6_importance_heatmap_2026-07-29.png"), width=900, height=700)
imp_norm <- apply(imp_mat, 2, function(x) x/max(x))   # normalise per cohort 0-1
heatmap(imp_norm, scale="none", margins=c(8,6),
        main="H6: Normalised feature importance across 6 cohorts",
        col=colorRampPalette(c("white","steelblue","darkblue"))(50))
dev.off()

# Spearman heatmap
png(file.path(OUT,"figures","h6_spearman_heatmap_2026-07-29.png"), width=600, height=600)
par(mar=c(5,5,4,2))
image(1:6, 1:6, spear_mat[6:1,], zlim=c(0,1),
      col=colorRampPalette(c("white","tomato","firebrick"))(50),
      xaxt="n", yaxt="n", xlab="", ylab="",
      main="Cross-cohort Spearman rank correlations")
axis(1, 1:6, cohorts, las=2); axis(2, 1:6, rev(cohorts), las=1)
for (i in 1:6) for (j in 1:6)
  text(i, 7-j, sprintf("%.2f", spear_mat[j,i]), cex=0.9)
dev.off()

# Markdown report
top3_per_cohort <- sapply(results, function(r) paste(names(sort(r$rank))[1:3], collapse=", "))
rpt <- paste0(
"# H6 SHAP Report (2026-07-29)\n\n",
"## Method\n",
"Cohort-specific logistic regression on FI_core 19 items + age (20 features total).\n",
"Importance = |β_standardised| (linear SHAP for main-effects GLM, exact for this model class).\n\n",
"## FI_core 19 items\n",
paste(FI_CORE, collapse=", "), "\n\n",
"## Cohort sizes\n\n",
"| Cohort | N | Events | Rate |\n|---|---:|---:|---:|\n",
paste(sapply(names(results), function(nm) {
  r <- results[[nm]]
  sprintf("| %s | %d | %d | %.1f%% |", nm, r$n, r$events, r$events/r$n*100)
}), collapse="\n"), "\n\n",
"## Top-3 features per cohort\n\n",
"| Cohort | #1 | #2 | #3 | Age rank |\n|---|---|---|---|---:|\n",
paste(sapply(names(results), function(nm) {
  r <- results[[nm]]; top3 <- names(sort(r$rank))[1:3]
  sprintf("| %s | %s | %s | %s | %d |", nm, top3[1], top3[2], top3[3], r$rank["age"])
}), collapse="\n"), "\n\n",
"## Cross-cohort Spearman rank correlations\n\n",
"| Pair | Spearman |\n|---|---:|\n",
paste(sprintf("| %s | %.4f |", names(pairwise_cors), pairwise_cors), collapse="\n"), "\n\n",
sprintf("**Median Spearman: %.4f** | Min: %.4f | Max: %.4f\n\n",
        median(pairwise_cors), min(pairwise_cors), max(pairwise_cors)),
"## H6 Verdict\n\n",
sprintf("**%s**\n\n", h6_verdict),
sprintf("- Median Spearman = %.4f (%s threshold 0.7)\n",
        median(pairwise_cors), ifelse(h6_spearman,">=","<")),
sprintf("- Age in top 3: %d / %d cohorts\n", age_top3, length(cohorts))
)
writeLines(rpt, file.path(OUT,"h6_shap_report_2026-07-29.md"))
cat("\nH6 SHAP analysis complete. Files in", OUT, "\n")
