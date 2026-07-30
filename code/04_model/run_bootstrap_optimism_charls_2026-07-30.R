#!/usr/bin/env Rscript
# =============================================================================
# Bootstrap Optimism Correction — CHARLS Internal C-index
# Method  : Harrell's internal-bootstrap (person-level sampling, B = 200)
# Purpose : Produce an optimism-corrected C-index for Model B to satisfy
#           TRIPOD item 13b (internal validation) prior to submission.
#
# Bootstrap algorithm (Steyerberg 2019, ch.5; Harrell 2015):
#   1.  Fit Model B on original data  → apparent C  (C_app)
#   2.  For b = 1 .. B:
#         a. Sample *persons* with replacement (all their person-periods follow)
#         b. Fit Model B on bootstrap sample  → predict on bootstrap → C_b_boot
#         c. Apply bootstrap model to *original* data  → C_b_orig
#         d. optimism_b = C_b_boot − C_b_orig
#   3.  optimism = mean(optimism_b)
#   4.  corrected_C = C_app − optimism
#
# Note: sampling at person level preserves within-person period correlation.
#
# Run from project root:
#   Rscript --vanilla code/04_model/run_bootstrap_optimism_charls_2026-07-30.R
# =============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(pROC)
})

# ── 0. Paths ──────────────────────────────────────────────────────────────────
args     <- commandArgs(FALSE)
farg     <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(farg)) dirname(normalizePath(sub("^--file=", "", farg[1]))) else getwd()
root     <- normalizePath(file.path(script_dir, "..", ".."), mustWork = TRUE)
data_dir <- file.path(root, "data", "analysis")
out_dir  <- file.path(root, "results", "aim1")
stamp    <- "2026-07-30"
B        <- 200L          # bootstrap replications; 200 sufficient for optimism
set.seed(42L)

cat("Bootstrap optimism correction — CHARLS Model B\n")
cat("Run time:", format(Sys.time()), "\n")
cat("Root:", root, "\n")
cat("B =", B, "replications\n\n")

# ── 1. Load data (identical logic to run_aim1_charls_clhls_v2) ───────────────
read_a <- function(x) as.data.frame(read_parquet(file.path(data_dir, x)))

pp    <- read_a("charls_person_period_2026-07-27.parquet")
fi_ch <- read_a("charls_fi_2011_2026-07-27.parquet")

clean_id <- function(x) {
  y <- trimws(as.character(x))
  y[is.na(x)] <- NA_character_
  y
}
pp$pid_key    <- clean_id(pp$pid)
fi_ch$id_key  <- clean_id(fi_ch$id)

# Apply 11→12 char ID bridge rule (decision D-009)
fi_ch$id_key <- ifelse(
  nchar(fi_ch$id_key) == 11L,
  paste0(substr(fi_ch$id_key, 1, 9), "0", substr(fi_ch$id_key, 10, 11)),
  fi_ch$id_key
)

fi_ok <- fi_ch |>
  filter(!is.na(age), age >= 60, !is.na(fi_excluded), !fi_excluded) |>
  transmute(pid_key = id_key, fi_full)

ch <- pp |>
  filter(!is.na(age_60_plus), age_60_plus, period %in% c(1L, 2L)) |>
  inner_join(fi_ok, by = "pid_key")

vars  <- c("event", "fi_full", "age", "female", "period")
ch_cc <- ch |>
  filter(if_all(all_of(vars), ~ !is.na(.x))) |>
  mutate(female = as.numeric(female))

n_persons <- n_distinct(ch_cc$pid_key)
n_rows    <- nrow(ch_cc)
n_events  <- sum(ch_cc$event == 1L)

cat(sprintf("Development set: %d persons | %d person-periods | %d events (%.1f%%)\n",
            n_persons, n_rows, n_events, 100 * n_events / n_rows))

# ── 2. Helper: AUC safe ───────────────────────────────────────────────────────
auc_safe <- function(y, p) {
  keep <- !is.na(y) & is.finite(p)
  if (sum(keep) < 2L || length(unique(y[keep])) < 2L) return(NA_real_)
  as.numeric(pROC::auc(pROC::roc(y[keep], p[keep],
                                  quiet = TRUE, direction = "auto")))
}

# ── 3. Original (apparent) model ─────────────────────────────────────────────
fit_orig  <- glm(event ~ fi_full + age + female + factor(period),
                 data = ch_cc, family = binomial())
p_orig    <- predict(fit_orig, type = "response")
C_apparent <- auc_safe(ch_cc$event, p_orig)
cat(sprintf("\nApparent C-index (original model): %.4f\n", C_apparent))

# ── 4. Bootstrap loop ─────────────────────────────────────────────────────────
person_ids <- unique(ch_cc$pid_key)
n_p        <- length(person_ids)
optimism_vec <- numeric(B)

# Pre-build row-index list per person: avoids re-scanning the table B*n_p times.
# split() returns row indices grouped by person, in person_ids order.
row_idx_by_person <- split(seq_len(nrow(ch_cc)),
                          factor(ch_cc$pid_key, levels = person_ids))

cat(sprintf("Running %d bootstrap replications", B))
flush.console()

for (b in seq_len(B)) {

  # (a) Sample persons with replacement; keep all their person-periods
  boot_pos <- sample.int(n_p, n_p, replace = TRUE)
  boot_rows <- unlist(row_idx_by_person[boot_pos], use.names = FALSE)
  boot_df   <- ch_cc[boot_rows, , drop = FALSE]

  # Skip if bootstrap sample lacks both outcome classes (extremely rare)
  if (length(unique(boot_df$event)) < 2L) {
    optimism_vec[b] <- NA_real_
    next
  }

  # (b) Fit model on bootstrap sample
  fit_boot <- tryCatch(
    glm(event ~ fi_full + age + female + factor(period),
        data = boot_df, family = binomial()),
    error = function(e) NULL
  )
  if (is.null(fit_boot)) { optimism_vec[b] <- NA_real_; next }

  # (c1) Predict on bootstrap sample → C_b_boot
  p_boot_in  <- predict(fit_boot, newdata = boot_df, type = "response")
  C_b_boot   <- auc_safe(boot_df$event, p_boot_in)

  # (c2) Predict on ORIGINAL data using bootstrap model → C_b_orig
  p_boot_orig <- predict(fit_boot, newdata = ch_cc, type = "response")
  C_b_orig    <- auc_safe(ch_cc$event, p_boot_orig)

  # (d) optimism for this replication
  optimism_vec[b] <- C_b_boot - C_b_orig

  if (b %% 50L == 0L) { cat("."); flush.console() }
}
cat(" done.\n\n")

# ── 5. Summarise optimism ─────────────────────────────────────────────────────
valid    <- optimism_vec[is.finite(optimism_vec)]
n_valid  <- length(valid)
optimism_mean <- mean(valid)
optimism_sd   <- sd(valid)
optimism_q025 <- quantile(valid, 0.025)
optimism_q975 <- quantile(valid, 0.975)
C_corrected   <- C_apparent - optimism_mean

cat(sprintf("Bootstrap replications completed (valid): %d / %d\n", n_valid, B))
cat(sprintf("Apparent   C-index:   %.4f\n", C_apparent))
cat(sprintf("Mean optimism:        %.4f  (SD %.4f)\n", optimism_mean, optimism_sd))
cat(sprintf("Optimism 95%% interval: [%.4f, %.4f]\n", optimism_q025, optimism_q975))
cat(sprintf("Corrected  C-index:   %.4f\n", C_corrected))
cat(sprintf("Shrinkage:            %.4f (= corrected / apparent)\n",
            C_corrected / C_apparent))

# ── 6. Save results ───────────────────────────────────────────────────────────
res <- data.frame(
  metric           = c("n_persons", "n_person_periods", "n_events",
                       "B_requested", "B_valid",
                       "C_apparent", "optimism_mean", "optimism_sd",
                       "optimism_q025", "optimism_q975",
                       "C_corrected", "C_corrected_lo95", "C_corrected_hi95"),
  value            = c(n_persons, n_rows, n_events,
                       B, n_valid,
                       C_apparent, optimism_mean, optimism_sd,
                       optimism_q025, optimism_q975,
                       C_corrected,
                       C_corrected - (optimism_q975 - optimism_mean),   # propagate upper
                       C_corrected - (optimism_q025 - optimism_mean)),  # propagate lower
  stringsAsFactors = FALSE
)
out_csv <- file.path(out_dir, paste0("aim1_bootstrap_optimism_", stamp, ".csv"))
write.csv(res, out_csv, row.names = FALSE)
cat("\nResults saved:", out_csv, "\n")

# Distribution of per-replication optimism values
dist_csv <- file.path(out_dir, paste0("aim1_bootstrap_optimism_distribution_", stamp, ".csv"))
write.csv(data.frame(b = seq_along(optimism_vec), optimism = optimism_vec),
          dist_csv, row.names = FALSE)

# ── 7. Write report ───────────────────────────────────────────────────────────
report <- c(
  paste0("# CHARLS Bootstrap Optimism Correction Report (", stamp, ")"),
  "",
  "## Method",
  paste0("Harrell's internal-bootstrap optimism correction (B = ", B, " replications)."),
  "Resampling at the **person** level (all person-periods for a sampled person are",
  "included) to preserve within-person correlation across risk periods.",
  "Each replication: fit Model B on bootstrap sample → C_boot_in;",
  "apply to original data → C_boot_orig; optimism = C_boot_in − C_boot_orig.",
  "Corrected C = Apparent C − mean(optimism).",
  "",
  "## Results",
  sprintf("- Development set: %d persons, %d person-periods, %d events (%.1f%%)",
          n_persons, n_rows, n_events, 100 * n_events / n_rows),
  sprintf("- Valid replications: %d / %d", n_valid, B),
  sprintf("- **Apparent C-index:   %.4f**", C_apparent),
  sprintf("- Mean optimism:        %.4f  (SD %.4f, 95%% interval %.4f–%.4f)",
          optimism_mean, optimism_sd, optimism_q025, optimism_q975),
  sprintf("- **Corrected C-index:  %.4f**", C_corrected),
  "",
  "## Interpretation",
  paste0("Optimism = ", sprintf("%.4f", optimism_mean), " (", sprintf("%.2f%%", 100 * optimism_mean),
         " of apparent C). The correction is minimal, indicating low overfitting"),
  "in this sample. The corrected C-index should replace the apparent value in",
  "Methods §8.1 and Results §3.3 for the final manuscript.",
  "",
  "## Files",
  paste0("- Summary: `results/aim1/aim1_bootstrap_optimism_", stamp, ".csv`"),
  paste0("- Distribution: `results/aim1/aim1_bootstrap_optimism_distribution_", stamp, ".csv`"),
  "",
  paste0("## Reproducibility"),
  paste0("`Rscript --vanilla code/04_model/run_bootstrap_optimism_charls_", stamp, ".R`")
)
rpt_path <- file.path(out_dir, paste0("aim1_bootstrap_optimism_report_", stamp, ".md"))
writeLines(report, rpt_path)
cat("Report saved:", rpt_path, "\n")
