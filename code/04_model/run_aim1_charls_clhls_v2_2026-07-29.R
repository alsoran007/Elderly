#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(pROC)
  library(ggplot2)
})

args <- commandArgs(FALSE)
farg <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(farg)) dirname(normalizePath(sub("^--file=", "", farg[1]))) else getwd()
root <- normalizePath(file.path(script_dir, "..", ".."), mustWork = TRUE)
data_dir <- file.path(root, "data", "analysis")
out_dir <- file.path(root, "results", "aim1")
fig_dir <- file.path(out_dir, "figures")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
stamp <- "2026-07-29"
log_file <- file.path(out_dir, paste0("aim1_run_log_", stamp, ".txt"))
sink(log_file, split = TRUE)
on.exit(sink(), add = TRUE)

cat("Aim 1 CHARLS development -> CLHLS external validation\n")
cat("Run time:", format(Sys.time()), "\nProject root:", root, "\n")
pkgs <- c("arrow", "mice", "pROC", "dcurves", "ggplot2")
pkg_ok <- vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
print(data.frame(package = pkgs, available = pkg_ok), row.names = FALSE)
if (!pkg_ok[["arrow"]] || !pkg_ok[["pROC"]]) stop("arrow and pROC are required")

read_a <- function(x) {
  p <- file.path(data_dir, x)
  if (!file.exists(p)) stop("Missing input: ", p)
  as.data.frame(read_parquet(p))
}
pp <- read_a("charls_person_period_2026-07-27.parquet")
fi_ch <- read_a("charls_fi_2011_2026-07-27.parquet")
fi_cl <- read_a("clhls_fi_2011_2026-07-29.parquet")
out_cl <- read_a("clhls_outcome_2026-07-28.parquet")

need <- function(x, cols, label) {
  miss <- setdiff(cols, names(x))
  if (length(miss)) stop(label, " missing: ", paste(miss, collapse = ", "))
}
need(pp, c("pid", "period", "event", "age", "female", "age_60_plus"), "CHARLS person-period")
need(fi_ch, c("id", "age", "fi_full", "fi_excluded"), "CHARLS FI")
need(fi_cl, c("id", "age", "fi_full", "fi_excluded"), "CLHLS FI")
need(out_cl, c("id", "female", "event_4y", "prebaseline_death"), "CLHLS outcome")

clean_id <- function(x) {
  y <- trimws(as.character(x))
  y[is.na(x)] <- NA_character_
  y
}
pp$pid_key <- clean_id(pp$pid)
fi_ch$id_key <- clean_id(fi_ch$id)
fi_cl$id_key <- clean_id(fi_cl$id)
out_cl$id_key <- clean_id(out_cl$id)

## Existing CHARLS outcome code defines the 12-character ID as household ID
## (first 9 characters) + "0" + the final two characters of the raw 11-char ID.
fi_ch$id_key <- ifelse(
  nchar(fi_ch$id_key) == 11,
  paste0(substr(fi_ch$id_key, 1, 9), "0", substr(fi_ch$id_key, 10, 11)),
  fi_ch$id_key
)

cat("Input dimensions:\n")
print(data.frame(
  dataset = c("charls_person_period", "charls_fi", "clhls_fi", "clhls_outcome"),
  rows = c(nrow(pp), nrow(fi_ch), nrow(fi_cl), nrow(out_cl)),
  columns = c(ncol(pp), ncol(fi_ch), ncol(fi_cl), ncol(out_cl))
), row.names = FALSE)
cat("CHARLS FI -> person-period ID overlap:", sum(fi_ch$id_key %in% pp$pid_key), "of", nrow(fi_ch), "\n")
cat("CLHLS FI -> outcome ID overlap:", sum(fi_cl$id_key %in% out_cl$id_key), "of", nrow(fi_cl), "\n")
cat("Period distribution:\n"); print(table(pp$period, useNA = "ifany"))
cat("Person-period event distribution:\n"); print(table(pp$event, useNA = "ifany"))
cat("CLHLS outcome distribution:\n"); print(table(out_cl$event_4y, useNA = "ifany"))
cat("CLHLS prebaseline distribution:\n"); print(table(out_cl$prebaseline_death, useNA = "ifany"))

edu_adjusted <- FALSE
edu_note <- "Education is absent from the harmonised parquet inputs; this is the preliminary age + female version."
cat(edu_note, "\n")

## Development sample: age 60+, FI eligible, period 1/2 (2011 -> 2015).
fi_ch_ok <- fi_ch %>%
  filter(!is.na(age), age >= 60, !is.na(fi_excluded), !fi_excluded) %>%
  transmute(pid_key = id_key, fi_full)
ch <- pp %>%
  filter(!is.na(age_60_plus), age_60_plus, period %in% c(1, 2)) %>%
  inner_join(fi_ch_ok, by = "pid_key")
vars <- c("event", "fi_full", "age", "female", "period")
ch_missing <- data.frame(
  variable = vars,
  n = vapply(ch[vars], length, integer(1)),
  missing = vapply(ch[vars], function(x) sum(is.na(x)), integer(1)),
  missing_pct = vapply(ch[vars], function(x) mean(is.na(x)) * 100, numeric(1))
)
ch_cc <- ch %>% filter(if_all(all_of(vars), ~ !is.na(.x))) %>% mutate(female = as.numeric(female))
if (!nrow(ch_cc)) stop("No complete CHARLS rows")
if (!all(ch_cc$event %in% c(0, 1))) stop("CHARLS event is not binary")
cat("CHARLS rows before/after complete cases:", nrow(ch), "/", nrow(ch_cc), "\n")
cat("CHARLS persons/events:", n_distinct(ch_cc$pid_key), "/", sum(ch_cc$event == 1), "\n")
cat("CHARLS FI median:", median(ch_cc$fi_full), "\n")
print(ch_missing, row.names = FALSE)

fit_a <- glm(event ~ age + female + factor(period), data = ch_cc, family = binomial())
fit_b <- glm(event ~ fi_full + age + female + factor(period), data = ch_cc, family = binomial())
save_coef <- function(fit, label, path) {
  z <- as.data.frame(summary(fit)$coefficients, stringsAsFactors = FALSE)
  names(z)[1:4] <- c("estimate", "std_error", "statistic", "p_value")
  z$term <- rownames(z); rownames(z) <- NULL; z$model <- label
  write.csv(z[, c("model", "term", "estimate", "std_error", "statistic", "p_value")], path, row.names = FALSE)
}
save_coef(fit_a, "Model_A", file.path(out_dir, paste0("model_a_charls_coefficients_", stamp, ".csv")))
save_coef(fit_b, "Model_B", file.path(out_dir, paste0("model_b_charls_coefficients_", stamp, ".csv")))

auc_safe <- function(y, p) {
  keep <- !is.na(y) & is.finite(p)
  if (length(unique(y[keep])) < 2) return(NA_real_)
  as.numeric(auc(roc(y[keep], p[keep], quiet = TRUE, direction = "auto")))
}
pa <- predict(fit_a, type = "response")
pb <- predict(fit_b, type = "response")
c_a <- auc_safe(ch_cc$event, pa)
c_b <- auc_safe(ch_cc$event, pb)
delta_c <- c_b - c_a

## External validation sample: age 60+, FI eligible, non-prebaseline death,
## observed four-year outcome, and complete predictors.
fi_cl_ok <- fi_cl %>%
  filter(!is.na(age), age >= 60, !is.na(fi_excluded), !fi_excluded) %>%
  transmute(id_key, age, fi_full)
cl <- fi_cl_ok %>%
  inner_join(
    out_cl %>% filter(!is.na(event_4y), prebaseline_death == 0) %>% transmute(id_key, female, event_4y),
    by = "id_key"
  ) %>%
  filter(if_all(c("age", "fi_full", "female", "event_4y"), ~ !is.na(.x))) %>%
  mutate(female = as.numeric(female), event_4y = as.numeric(event_4y))
if (!nrow(cl)) stop("No complete CLHLS rows")
if (!all(cl$event_4y %in% c(0, 1))) stop("CLHLS event_4y is not binary")
cl_missing <- data.frame(
  variable = c("event_4y", "fi_full", "age", "female"),
  missing = c(sum(is.na(out_cl$event_4y)), sum(is.na(fi_cl$fi_full)), sum(is.na(fi_cl$age)), sum(is.na(out_cl$female))),
  source_n = c(nrow(out_cl), nrow(fi_cl), nrow(fi_cl), nrow(out_cl))
)
cl_missing$missing_pct <- 100 * cl_missing$missing / cl_missing$source_n

nd1 <- data.frame(fi_full = cl$fi_full, age = cl$age, female = cl$female, period = 1)
nd2 <- nd1; nd2$period <- 2
h1 <- predict(fit_b, newdata = nd1, type = "response")
h2 <- predict(fit_b, newdata = nd2, type = "response")
cl$pred_4y <- pmin(pmax(1 - (1 - h1) * (1 - h2), 1e-8), 1 - 1e-8)
nd1a <- nd1[c("age", "female", "period")]; nd2a <- nd1a; nd2a$period <- 2
ha1 <- predict(fit_a, newdata = nd1a, type = "response")
ha2 <- predict(fit_a, newdata = nd2a, type = "response")
cl$pred_4y_a <- pmin(pmax(1 - (1 - ha1) * (1 - ha2), 1e-8), 1 - 1e-8)

boot_auc <- function(y, p, B = 500, seed = 2026) {
  set.seed(seed); n <- length(y)
  x <- replicate(B, { i <- sample.int(n, n, replace = TRUE); auc_safe(y[i], p[i]) })
  x <- x[is.finite(x)]
  c(estimate = auc_safe(y, p), lo = unname(quantile(x, .025)), hi = unname(quantile(x, .975)))
}
c_cl <- boot_auc(cl$event_4y, cl$pred_4y)
c_cl_a <- auc_safe(cl$event_4y, cl$pred_4y_a)
lp <- qlogis(cl$pred_4y)
cal_intercept <- unname(coef(glm(event_4y ~ offset(lp), data = cl, family = binomial()))[1])
cal_slope <- unname(coef(glm(event_4y ~ lp, data = cl, family = binomial()))[2])
oe <- mean(cl$event_4y) / mean(cl$pred_4y)
brier <- mean((cl$event_4y - cl$pred_4y)^2)
null_brier <- mean((cl$event_4y - mean(cl$event_4y))^2)
ipa <- 1 - brier / null_brier

cl$decile <- ntile(cl$pred_4y, 10)
cal <- cl %>% group_by(decile) %>% summarise(predicted = mean(pred_4y), observed = mean(event_4y), n = n(), .groups = "drop")
write.csv(cal, file.path(out_dir, paste0("aim1_calibration_deciles_clhls_", stamp, ".csv")), row.names = FALSE)
g <- ggplot(cal, aes(predicted, observed)) + geom_abline(slope = 1, intercept = 0, linetype = 2, colour = "grey50") + geom_line(colour = "#2C7FB8") + geom_point(colour = "#2C7FB8", size = 2.5) + coord_cartesian(xlim = c(0, 1), ylim = c(0, 1)) + labs(x = "Predicted 4-year mortality", y = "Observed 4-year mortality", title = "CLHLS external validation: calibration") + theme_minimal(base_size = 12)
ggsave(file.path(fig_dir, paste0("calibration_plot_clhls_", stamp, ".png")), g, width = 8, height = 7, dpi = 120)

dca_status <- "skipped"; dca_error <- ""
if (requireNamespace("dcurves", quietly = TRUE)) {
  dca <- tryCatch(dcurves::dca(event_4y ~ pred_4y, data = cl, thresholds = seq(.05, .40, .01)), error = function(e) e)
  if (inherits(dca, "error")) dca_error <- conditionMessage(dca) else {
    dca_status <- "completed"
    dca_plot <- tryCatch(plot(dca), error = function(e) NULL)
    if (!is.null(dca_plot)) ggsave(file.path(fig_dir, paste0("dca_clhls_", stamp, ".png")), dca_plot, width = 9, height = 7, dpi = 120) else dca_status <- "computed_plot_failed"
    dca_df <- tryCatch(as.data.frame(dca), error = function(e) NULL)
    if (!is.null(dca_df)) write.csv(dca_df, file.path(out_dir, paste0("aim1_dca_clhls_", stamp, ".csv")), row.names = FALSE)
  }
} else dca_error <- "dcurves package unavailable"

perf <- data.frame(
  metric = c("n_persons", "n_events", "event_rate", "C_index", "C_index_95CI_lo", "C_index_95CI_hi", "OE_ratio", "calibration_intercept", "calibration_slope", "brier_score", "IPA", "delta_C_FI_vs_base", "edu_adjusted"),
  CHARLS_internal = c(n_distinct(ch_cc$pid_key), sum(ch_cc$event == 1), mean(ch_cc$event), c_b, NA, NA, NA, NA, NA, mean((ch_cc$event - pb)^2), NA, delta_c, edu_adjusted),
  CLHLS_external = c(n_distinct(cl$id_key), sum(cl$event_4y == 1), mean(cl$event_4y), c_cl["estimate"], c_cl["lo"], c_cl["hi"], oe, cal_intercept, cal_slope, brier, ipa, NA, edu_adjusted),
  stringsAsFactors = FALSE
)
write.csv(perf, file.path(out_dir, paste0("aim1_performance_table_", stamp, ".csv")), row.names = FALSE)
write.csv(ch_missing, file.path(out_dir, paste0("aim1_missingness_charls_", stamp, ".csv")), row.names = FALSE)
write.csv(cl_missing, file.path(out_dir, paste0("aim1_missingness_clhls_", stamp, ".csv")), row.names = FALSE)

report <- c(
  paste0("# Aim 1 report (", stamp, ")"), "",
  "## Scope", "CHARLS 2011 age-60+ FI-eligible person-period data were used to develop pooled logistic Model A (age + female + period) and Model B (FI + age + female + period). Model B coefficients were frozen and applied to CLHLS for four-year mortality validation.", "",
  "## Data and missingness",
  paste0("- CHARLS development: ", n_distinct(ch_cc$pid_key), " persons, ", nrow(ch_cc), " person-period rows, ", sum(ch_cc$event == 1), " events."),
  paste0("- CLHLS external validation: ", n_distinct(cl$id_key), " persons, ", sum(cl$event_4y == 1), " events (event rate ", sprintf("%.1f", 100 * mean(cl$event_4y)), "%)."),
  paste0("- CHARLS complete-case retention: ", nrow(ch_cc), " / ", nrow(ch), " rows."),
  paste0("- CLHLS source missingness: event_4y ", sprintf("%.1f", cl_missing$missing_pct[1]), "%; FI ", sprintf("%.1f", cl_missing$missing_pct[2]), "%; age ", sprintf("%.1f", cl_missing$missing_pct[3]), "%; female ", sprintf("%.1f", cl_missing$missing_pct[4]), "%."),
  paste0("- Education adjustment: not included. ", edu_note), "",
  "## Model coefficients", "Coefficient CSV files in this directory contain the Model A and Model B estimates.", "",
  "## Internal discrimination",
  paste0("- Model A C-index: ", sprintf("%.4f", c_a), "; Model B C-index: ", sprintf("%.4f", c_b), "; delta C: ", sprintf("%.4f", delta_c), "."),
  paste0("- H1 threshold delta C >= 0.02: ", ifelse(delta_c >= .02, "met", "not met"), "."), "",
  "## CLHLS external validation",
  paste0("- Model B C-index: ", sprintf("%.4f", c_cl["estimate"]), " (bootstrap 95% CI ", sprintf("%.4f", c_cl["lo"]), "-", sprintf("%.4f", c_cl["hi"]), ")."),
  paste0("- O:E ratio: ", sprintf("%.4f", oe), "; calibration intercept: ", sprintf("%.4f", cal_intercept), "; calibration slope: ", sprintf("%.4f", cal_slope), "."),
  paste0("- Brier score: ", sprintf("%.5f", brier), "; IPA: ", sprintf("%.4f", ipa), "."),
  paste0("- DCA status: ", dca_status, if (nzchar(dca_error)) paste0(" (", dca_error, ")") else "", "."), "",
  "## Warnings", "This is the preliminary no-education-adjustment version. Internal C-index is apparent pooled person-period discrimination; external C-index is person-level.", "",
  paste0("## Reproducibility\n`D:/LeStoreDownload/R/R-4.4.1/bin/x64/Rscript.exe --vanilla --no-restore --no-save code/04_model/run_aim1_charls_clhls_v2_2026-07-29.R`.")
)
writeLines(report, file.path(out_dir, paste0("aim1_report_", stamp, ".md")), useBytes = TRUE)
cat("\n=== Final results ===\n"); print(perf, row.names = FALSE)
cat("CLHLS predicted risk:\n"); print(summary(cl$pred_4y))
cat("DCA:", dca_status, if (nzchar(dca_error)) paste0("; ", dca_error) else "", "\n")
