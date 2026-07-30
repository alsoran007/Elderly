#!/usr/bin/env Rscript
# =============================================================================
# SA-3: Education-adjusted sensitivity analysis — Aim 1 (CHARLS → CLHLS)
# Paper 1 · SAP amendment A-001 · 2026-07-30
#
# ⚠  POST HOC: recorded after outcome unblinding (2026-07-29). SA-3 does NOT
#    change any H1–H6 verdict. It provides robustness evidence for the claim
#    that the main model (no education adjustment) conclusions are valid.
#
# Main model (unchanged): event ~ fi_full + age + female + factor(period)
# SA-3  model            : main + edu_isced  (ISCED 3-level, ordered integer)
#
# Education mapping (frozen in SAP_amendments A-001):
#   CHARLS bd001 (11-level): 1-5 → 1; 6-7 → 2; 8-11 → 3
#   CLHLS  f1   (years)    : 0-9 → 1; 10-12 → 2; ≥13 → 3; 88/99 = NA
#
# Run from project root:
#   Rscript --vanilla code/04_model/run_sa3_education_2026-07-30.R
# =============================================================================

suppressPackageStartupMessages({
  library(arrow); library(haven); library(dplyr); library(pROC); library(ggplot2)
})

# ── 0. Paths ──────────────────────────────────────────────────────────────────
args <- commandArgs(FALSE); farg <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(farg)) dirname(normalizePath(sub("^--file=", "", farg[1]))) else getwd()
root   <- normalizePath(file.path(script_dir, "..", ".."), mustWork = TRUE)
d_dir  <- file.path(root, "data", "analysis")
sql    <- "D:/AI_project/sql"
out_dir<- file.path(root, "results", "sa3")
fig_dir<- file.path(out_dir, "figures")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
stamp  <- "2026-07-30"

cat("SA-3 Education-adjusted sensitivity analysis\n")
cat("SAP amendment: A-001 | POST HOC (after outcome unblinding 2026-07-29)\n")
cat("Run time:", format(Sys.time()), "\n\n")

# ── 1. Helpers ─────────────────────────────────────────────────────────────────
read_a <- function(fn) as.data.frame(read_parquet(file.path(d_dir, fn)))
zap <- function(x) if (inherits(x, c("haven_labelled","labelled"))) unclass(x) else x
clean_id <- function(x) { y <- trimws(as.character(zap(x))); y[is.na(x)] <- NA_character_; y }
auc_safe <- function(y, p) {
  k <- !is.na(y) & is.finite(p)
  if (length(unique(y[k])) < 2) return(NA_real_)
  as.numeric(pROC::auc(pROC::roc(y[k], p[k], quiet = TRUE, direction = "auto")))
}

# ── 2. CHARLS education (bd001 → ISCED 3-level) ───────────────────────────────
cat("Loading CHARLS education from demographic_background.dta...\n")
demo <- read_dta(file.path(sql, "CHARLS/2011/demographic_background.dta"),
                 col_select = all_of(c("ID", "householdID", "bd001")))
demo$id_key <- clean_id(demo$ID)
# Apply 11→12 char bridge (same rule as main model, D-009)
demo$id_key <- ifelse(
  nchar(demo$id_key) == 11L,
  paste0(substr(demo$id_key, 1, 9), "0", substr(demo$id_key, 10, 11)),
  demo$id_key
)
demo$edu_raw <- as.integer(zap(demo$bd001))
demo$edu_isced <- dplyr::case_when(
  demo$edu_raw %in% 1:5  ~ 1L,
  demo$edu_raw %in% 6:7  ~ 2L,
  demo$edu_raw %in% 8:11 ~ 3L,
  TRUE ~ NA_integer_
)
edu_ch <- demo |> select(id_key, edu_isced) |> distinct(id_key, .keep_all = TRUE)
cat(sprintf("  CHARLS edu_isced distribution: %s\n",
    paste(names(table(edu_ch$edu_isced, useNA = "ifany")),
          table(edu_ch$edu_isced, useNA = "ifany"), sep = "=", collapse = ", ")))

# ── 3. CLHLS education (f1 years → ISCED 3-level) ────────────────────────────
cat("Loading CLHLS education from longitudinal SAV...\n")
cl_sav <- file.path(sql, "CLHLS/CLHLS_dataset_2008-2018_SPSS",
                    "clhls_2011_2018_longitudinal_dataset_released_version1.sav")
cl_edu_raw <- read_sav(cl_sav, col_select = all_of(c("id", "f1")))
cl_edu_raw$id_key  <- clean_id(cl_edu_raw$id)
cl_edu_raw$f1_num  <- as.numeric(zap(cl_edu_raw$f1))
cl_edu_raw$f1_num[cl_edu_raw$f1_num %in% c(88, 99)] <- NA  # CLHLS missing codes
cl_edu_raw$edu_isced <- dplyr::case_when(
  cl_edu_raw$f1_num <= 9             ~ 1L,
  cl_edu_raw$f1_num <= 12            ~ 2L,
  !is.na(cl_edu_raw$f1_num)         ~ 3L,
  TRUE ~ NA_integer_
)
edu_cl <- cl_edu_raw |> select(id_key, edu_isced) |> distinct(id_key, .keep_all = TRUE)
cat(sprintf("  CLHLS edu_isced distribution: %s\n",
    paste(names(table(edu_cl$edu_isced, useNA = "ifany")),
          table(edu_cl$edu_isced, useNA = "ifany"), sep = "=", collapse = ", ")))

# ── 4. Build CHARLS development set (same as main model + education) ──────────
cat("\nBuilding CHARLS development set...\n")
pp    <- read_a("charls_person_period_2026-07-27.parquet")
fi_ch <- read_a("charls_fi_2011_2026-07-27.parquet")

pp$pid_key   <- clean_id(pp$pid)
fi_ch$id_key <- clean_id(fi_ch$id)
fi_ch$id_key <- ifelse(nchar(fi_ch$id_key) == 11L,
  paste0(substr(fi_ch$id_key,1,9),"0",substr(fi_ch$id_key,10,11)), fi_ch$id_key)

fi_ok <- fi_ch |> filter(!is.na(age), age >= 60, !is.na(fi_excluded), !fi_excluded) |>
  transmute(pid_key = id_key, fi_full)

ch_base <- pp |>
  filter(!is.na(age_60_plus), age_60_plus, period %in% c(1L, 2L)) |>
  inner_join(fi_ok, by = "pid_key") |>
  left_join(edu_ch |> rename(pid_key = id_key), by = "pid_key") |>
  filter(if_all(c("event","fi_full","age","female","period"), ~ !is.na(.x))) |>
  mutate(female = as.numeric(female))

# Main model: complete cases without education requirement
ch_main <- ch_base
# SA-3: additionally requires edu_isced
ch_sa3  <- ch_base |> filter(!is.na(edu_isced))

n_excl_edu <- n_distinct(ch_main$pid_key) - n_distinct(ch_sa3$pid_key)
cat(sprintf("  Main model: %d persons | %d pp rows | %d events\n",
    n_distinct(ch_main$pid_key), nrow(ch_main), sum(ch_main$event == 1)))
cat(sprintf("  SA-3 (complete edu): %d persons | %d pp rows | %d events\n",
    n_distinct(ch_sa3$pid_key), nrow(ch_sa3), sum(ch_sa3$event == 1)))
cat(sprintf("  Excluded (missing edu): %d persons\n", n_excl_edu))

# ── 5. Fit models on CHARLS ───────────────────────────────────────────────────
cat("\nFitting models on CHARLS...\n")
# Main model B (on SA-3 sample, for fair internal comparison)
fit_main <- glm(event ~ fi_full + age + female + factor(period),
                data = ch_sa3, family = binomial())
# SA-3 model
fit_sa3 <- glm(event ~ fi_full + age + female + factor(period) + edu_isced,
               data = ch_sa3, family = binomial())

p_main_ch <- predict(fit_main, type = "response")
p_sa3_ch  <- predict(fit_sa3,  type = "response")
c_main_ch <- auc_safe(ch_sa3$event, p_main_ch)
c_sa3_ch  <- auc_safe(ch_sa3$event, p_sa3_ch)
cat(sprintf("  CHARLS internal C — main: %.4f | SA-3: %.4f | delta: %+.4f\n",
    c_main_ch, c_sa3_ch, c_sa3_ch - c_main_ch))
cat("  SA-3 edu_isced coefficient:",
    sprintf("%.4f (p=%.4f)", coef(fit_sa3)["edu_isced"],
            summary(fit_sa3)$coefficients["edu_isced", "Pr(>|z|)"]), "\n")

# ── 6. Build CLHLS validation set ─────────────────────────────────────────────
cat("\nBuilding CLHLS validation set...\n")
fi_cl  <- read_a("clhls_fi_2011_2026-07-29.parquet")
out_cl <- read_a("clhls_outcome_2026-07-28.parquet")
fi_cl$id_key  <- clean_id(fi_cl$id)
out_cl$id_key <- clean_id(out_cl$id)

cl_base <- fi_cl |>
  filter(!is.na(age), age >= 60, !is.na(fi_excluded), !fi_excluded) |>
  transmute(id_key, age, fi_full) |>
  inner_join(
    out_cl |> filter(!is.na(event_4y), prebaseline_death == 0) |>
      transmute(id_key, female = as.numeric(female), event_4y = as.numeric(event_4y)),
    by = "id_key"
  ) |>
  left_join(edu_cl, by = "id_key") |>
  filter(if_all(c("age","fi_full","female","event_4y"), ~ !is.na(.x)))

cl_main <- cl_base
cl_sa3  <- cl_base |> filter(!is.na(edu_isced))
cat(sprintf("  CLHLS main validation: %d persons | %d events (%.1f%%)\n",
    nrow(cl_main), sum(cl_main$event_4y), 100*mean(cl_main$event_4y)))
cat(sprintf("  CLHLS SA-3 validation: %d persons | %d events (%.1f%%)\n",
    nrow(cl_sa3), sum(cl_sa3$event_4y), 100*mean(cl_sa3$event_4y)))
cat(sprintf("  CLHLS excluded (missing edu): %d persons\n", nrow(cl_main)-nrow(cl_sa3)))

# ── 7. Apply frozen coefficients to CLHLS ─────────────────────────────────────
predict_4y <- function(fit, df) {
  nd1 <- df |> mutate(period = 1)
  nd2 <- df |> mutate(period = 2)
  h1 <- predict(fit, newdata = nd1, type = "response")
  h2 <- predict(fit, newdata = nd2, type = "response")
  pmin(pmax(1 - (1 - h1)*(1 - h2), 1e-8), 1-1e-8)
}

cl_main$pred_main <- predict_4y(fit_main, cl_main)
cl_sa3$pred_main  <- predict_4y(fit_main, cl_sa3)
cl_sa3$pred_sa3   <- predict_4y(fit_sa3,  cl_sa3)

boot_c <- function(y, p, B = 200, seed = 2026) {
  set.seed(seed); n <- length(y)
  x <- replicate(B, { i <- sample.int(n,n,TRUE); auc_safe(y[i],p[i]) })
  x <- x[is.finite(x)]
  c(est = auc_safe(y,p), lo = unname(quantile(x,.025)), hi = unname(quantile(x,.975)))
}
metrics <- function(y, p, label) {
  lp  <- qlogis(p)
  oe  <- mean(y)/mean(p)
  ci  <- unname(coef(glm(y ~ offset(lp), family=binomial()))[1])
  sl  <- unname(coef(glm(y ~ lp,         family=binomial()))[2])
  bs  <- mean((y-p)^2)
  ipa <- 1 - bs/mean((y-mean(y))^2)
  c_b <- boot_c(y, p)
  cat(sprintf("  %s: C=%.4f [%.4f-%.4f] O:E=%.4f slope=%.4f IPA=%.4f\n",
      label, c_b["est"], c_b["lo"], c_b["hi"], oe, sl, ipa))
  data.frame(model=label, n=length(y), events=sum(y), event_rate=mean(y),
             c_index=c_b["est"], c_lo=c_b["lo"], c_hi=c_b["hi"],
             oe=oe, cal_intercept=ci, cal_slope=sl, brier=bs, ipa=ipa,
             row.names=NULL)
}

cat("\nCLHLS external validation — on main-model complete sample (same as Aim 1):\n")
m1  <- metrics(cl_main$event_4y, cl_main$pred_main,  "Main (full CC)")
cat("\nCLHLS external validation — SA-3 complete sample (edu non-missing):\n")
m2  <- metrics(cl_sa3$event_4y,  cl_sa3$pred_main,   "Main (edu CC)")
m3  <- metrics(cl_sa3$event_4y,  cl_sa3$pred_sa3,    "SA-3 (+edu)")

# ── 8. Calibration plot ────────────────────────────────────────────────────────
cal_df <- bind_rows(
  cl_sa3 |> mutate(model="Main (edu CC)", pred=pred_main) |> select(event_4y, pred, model),
  cl_sa3 |> mutate(model="SA-3 (+edu)",   pred=pred_sa3)  |> select(event_4y, pred, model)
) |>
  group_by(model) |>
  mutate(decile = ntile(pred, 10)) |>
  group_by(model, decile) |>
  summarise(predicted = mean(pred), observed = mean(event_4y), n = n(), .groups="drop")

p_cal <- ggplot(cal_df, aes(predicted, observed, colour = model)) +
  geom_abline(slope=1, intercept=0, linetype="dashed", colour="grey70", linewidth=0.4) +
  geom_line(linewidth=0.65, alpha=0.9) +
  geom_point(size=2.4) +
  scale_colour_manual(values=c("Main (edu CC)"="#2166AC","SA-3 (+edu)"="#D94801"), name=NULL) +
  scale_x_continuous(limits=c(0,1), breaks=seq(0,1,.2)) +
  scale_y_continuous(limits=c(0,1), breaks=seq(0,1,.2)) +
  labs(x="Predicted 4-year mortality", y="Observed 4-year mortality",
       subtitle="SA-3: Main vs Education-adjusted model — CLHLS calibration (deciles)",
       caption=paste0("Complete-case sample with non-missing edu_isced (ISCED 3-level). ",
         "SA-3 is post hoc; does not change H1-H6 verdicts.")) +
  theme_bw(base_size=10) +
  theme(legend.position=c(.78,.18), panel.grid.minor=element_blank(),
        legend.background=element_rect(fill="white",colour="grey80"))

ggsave(file.path(fig_dir, paste0("sa3_calibration_clhls_", stamp, ".tiff")),
       p_cal, width=120, height=110, units="mm", dpi=600, compression="lzw")
ggsave(file.path(fig_dir, paste0("sa3_calibration_clhls_", stamp, ".pdf")),
       p_cal, width=120, height=110, units="mm")

# ── 9. Save results ────────────────────────────────────────────────────────────
perf <- bind_rows(m1, m2, m3)
write.csv(perf, file.path(out_dir, paste0("sa3_education_performance_", stamp, ".csv")),
          row.names=FALSE)

# Delta vs main (edu CC sample)
dc_int <- m3$c_index - m2$c_index
doe    <- m3$oe - m2$oe
dslope <- m3$cal_slope - m2$cal_slope
dipa   <- m3$ipa - m2$ipa
robust <- abs(dc_int) < 0.02 & abs(doe) < 0.05 & abs(dslope) < 0.05

# ── 10. Write report ───────────────────────────────────────────────────────────
report <- c(
  paste0("# SA-3 Education-Adjusted Sensitivity Analysis Report (", stamp, ")"),
  "",
  "## Status",
  "**POST HOC sensitivity analysis** (SAP amendment A-001, 2026-07-30).",
  "Conducted after outcome unblinding (2026-07-29). Does NOT change H1–H6 verdicts.",
  "",
  "## Models",
  "- **Main model (B)**: `event ~ fi_full + age + female + factor(period)` (SAP-registered)",
  "- **SA-3 model**: `event ~ fi_full + age + female + factor(period) + edu_isced`",
  "",
  "## Education encoding (frozen in A-001)",
  "ISCED 3-level covariate; complete-case only.",
  "- CHARLS `bd001`: 1–5 → 1; 6–7 → 2; 8–11 → 3",
  "- CLHLS `f1` (years): 0–9 → 1; 10–12 → 2; ≥13 → 3; 88/99 = NA",
  "",
  "## Sample sizes",
  sprintf("- CHARLS main model pp rows: %d (%d persons, %d events)",
          nrow(ch_main), n_distinct(ch_main$pid_key), sum(ch_main$event==1)),
  sprintf("- CHARLS SA-3 pp rows: %d (%d persons, %d events) — %d persons excluded (missing edu)",
          nrow(ch_sa3), n_distinct(ch_sa3$pid_key), sum(ch_sa3$event==1), n_excl_edu),
  sprintf("- CLHLS main validation: %d persons, %d events (%.1f%%)",
          nrow(cl_main), sum(cl_main$event_4y), 100*mean(cl_main$event_4y)),
  sprintf("- CLHLS SA-3 validation: %d persons, %d events — %d persons excluded (missing edu)",
          nrow(cl_sa3), sum(cl_sa3$event_4y), nrow(cl_main)-nrow(cl_sa3)),
  "",
  "## Internal discrimination (CHARLS)",
  sprintf("- Main model C-index (edu-complete sample): %.4f", c_main_ch),
  sprintf("- SA-3  model C-index (edu-complete sample): %.4f", c_sa3_ch),
  sprintf("- ΔC (SA-3 − main): %+.4f", c_sa3_ch - c_main_ch),
  sprintf("- edu_isced coefficient: %.4f (p=%.4f)",
          coef(fit_sa3)["edu_isced"],
          summary(fit_sa3)$coefficients["edu_isced","Pr(>|z|)"]),
  "",
  "## CLHLS external validation",
  "",
  "| Model | N | Events | C-index [95% CI] | O:E | Cal slope | IPA |",
  "|---|---:|---:|---|---:|---:|---:|",
  sprintf("| Main (full CC, Aim 1) | %d | %d | %.4f [%.4f–%.4f] | %.4f | %.4f | %.4f |",
          m1$n, m1$events, m1$c_index, m1$c_lo, m1$c_hi, m1$oe, m1$cal_slope, m1$ipa),
  sprintf("| Main (edu-complete)    | %d | %d | %.4f [%.4f–%.4f] | %.4f | %.4f | %.4f |",
          m2$n, m2$events, m2$c_index, m2$c_lo, m2$c_hi, m2$oe, m2$cal_slope, m2$ipa),
  sprintf("| SA-3 (+edu_isced)     | %d | %d | %.4f [%.4f–%.4f] | %.4f | %.4f | %.4f |",
          m3$n, m3$events, m3$c_index, m3$c_lo, m3$c_hi, m3$oe, m3$cal_slope, m3$ipa),
  "",
  "## SA-3 vs Main model delta (on edu-complete sample)",
  sprintf("- ΔC-index : %+.4f", dc_int),
  sprintf("- Δ O:E    : %+.4f", doe),
  sprintf("- Δ slope  : %+.4f", dslope),
  sprintf("- Δ IPA    : %+.4f", dipa),
  "",
  "## Robustness verdict",
  sprintf("**Pre-specified criterion** (A-001): |ΔC| < 0.02 AND |ΔO:E| < 0.05 AND |Δslope| < 0.05"),
  sprintf("**Observed**: |ΔC| = %.4f | |ΔO:E| = %.4f | |Δslope| = %.4f",
          abs(dc_int), abs(doe), abs(dslope)),
  sprintf("**Verdict: %s**", if (robust) "ROBUST — main model conclusions hold without education adjustment" else "NOT ROBUST — education adjustment materially changes results"),
  "",
  "## Files",
  sprintf("- Performance CSV: `results/sa3/sa3_education_performance_%s.csv`", stamp),
  sprintf("- Calibration plot: `results/sa3/figures/sa3_calibration_clhls_%s.{tiff,pdf}`", stamp),
  "",
  "## For manuscript",
  "Report SA-3 in Methods §8.5 (sensitivity analyses) and cite the verdict in",
  "Results (one paragraph) and Limitations (replace the refuted 'education unavailable' claim).",
  "",
  paste0("*Generated: ", format(Sys.time()), "*")
)
writeLines(report, file.path(out_dir, paste0("sa3_education_report_", stamp, ".md")))

cat("\n=== SA-3 SUMMARY ===\n")
cat(sprintf("CHARLS internal C:  main=%.4f  SA-3=%.4f  ΔC=%+.4f\n",
    c_main_ch, c_sa3_ch, c_sa3_ch - c_main_ch))
cat(sprintf("CLHLS external C:   main=%.4f  SA-3=%.4f  ΔC=%+.4f\n",
    m2$c_index, m3$c_index, dc_int))
cat(sprintf("Robustness verdict: %s\n",
    if (robust) "ROBUST" else "NOT ROBUST"))
cat("Files written to results/sa3/\n")
