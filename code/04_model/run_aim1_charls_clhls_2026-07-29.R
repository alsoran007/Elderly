#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(tidyr)
  library(pROC)
  library(ggplot2)
})

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[1]) else ""
script_dir <- if (nzchar(script_path)) dirname(normalizePath(script_path)) else getwd()
project_root <- normalizePath(file.path(script_dir, "..", ".."), mustWork = TRUE)

data_dir <- file.path(project_root, "data", "analysis")
result_dir <- file.path(project_root, "results", "aim1")
figure_dir <- file.path(result_dir, "figures")
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

stamp <- "2026-07-29"
log_file <- file.path(result_dir, paste0("aim1_run_log_", stamp, ".txt"))
sink(log_file, split = TRUE)
on.exit(sink(), add = TRUE)

cat("Aim 1 CHARLS development -> CLHLS external validation\n")
cat("Run time:", format(Sys.time()), "\n")
cat("Project root:", project_root, "\n")

required_pkgs <- c("arrow", "mice", "pROC", "dcurves", "ggplot2")
pkg_status <- vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)
cat("Package status:\n")
print(data.frame(package = required_pkgs, available = pkg_status), row.names = FALSE)
if (!pkg_status[["arrow"]] || !pkg_status[["pROC"]]) {
  stop("Required packages arrow and pROC are unavailable.")
}

read_analysis <- function(name) {
  path <- file.path(data_dir, name)
  if (!file.exists(path)) stop("Missing input: ", path)
  as.data.frame(read_parquet(path))
}

charls_pp <- read_analysis("charls_person_period_2026-07-27.parquet")
charls_fi <- read_analysis("charls_fi_2011_2026-07-27.parquet")
clhls_fi <- read_analysis("clhls_fi_2011_2026-07-29.parquet")
clhls_out <- read_analysis("clhls_outcome_2026-07-28.parquet")

required_columns <- function(dat, cols, label) {
  missing <- setdiff(cols, names(dat))
  if (length(missing)) stop(label, " missing columns: ", paste(missing, collapse = ", "))
}
required_columns(charls_pp, c("pid", "period", "event", "age", "female", "age_60_plus"), "CHARLS person-period")
required_columns(charls_fi, c("id", "age", "fi_full", "fi_excluded"), "CHARLS FI")
required_columns(clhls_fi, c("id", "age", "fi_full", "fi_excluded"), "CLHLS FI")
required_columns(clhls_out, c("id", "female", "event_4y", "prebaseline_death"), "CLHLS outcome")

normalise_id <- function(x) {
  y <- trimws(as.character(x))
  y[is.na(x)] <- NA_character_
  y
}

charls_pp$pid_key <- normalise_id(charls_pp$pid)
charls_fi$id_key <- normalise_id(charls_fi$id)
clhls_fi$id_key <- normalise_id(clhls_fi$id)
clhls_out$id_key <- normalise_id(clhls_out$id)

cat("Input dimensions:\n")
print(data.frame(
  dataset = c("charls_person_period", "charls_fi", "clhls_fi", "clhls_outcome"),
  rows = c(nrow(charls_pp), nrow(charls_fi), nrow(clhls_fi), nrow(clhls_out)),
  columns = c(ncol(charls_pp), ncol(charls_fi), ncol(clhls_fi), ncol(clhls_out))
), row.names = FALSE)
cat("CHARLS FI IDs in person-period:", sum(charls_fi$id_key %in% charls_pp$pid_key), "of", nrow(charls_fi), "\n")
cat("CLHLS FI IDs in outcome:", sum(clhls_fi$id_key %in% clhls_out$id_key), "of", nrow(clhls_fi), "\n")

cat("\nRaw input distributions:\n")
print(table(charls_pp$period, useNA = "ifany"))
print(table(charls_pp$event, useNA = "ifany"))
print(table(charls_fi$fi_excluded, useNA = "ifany"))
print(table(clhls_fi$fi_excluded, useNA = "ifany"))
print(table(clhls_out$event_4y, useNA = "ifany"))
print(table(clhls_out$prebaseline_death, useNA = "ifany"))

## Education is not present in the harmonised parquet inputs. The model therefore
## remains the prespecified preliminary age + female version unless a validated
## person-level education join is supplied upstream.
edu_available <- FALSE
edu_note <- "Education was not present in the harmonised parquet inputs; preliminary age + female models were used."
cat("Education:", edu_note, "\n")

## CHARLS development data: age 60+, FI eligible, periods 1 and 2.
fi_ch_eligible <- charls_fi %>%
  filter(!is.na(age), age >= 60, !is.na(fi_excluded), !fi_excluded) %>%
  transmute(pid_key = id_key, fi_full)

pp_ch <- charls_pp %>%
  filter(!is.na(age_60_plus), age_60_plus, period %in% c(1, 2)) %>%
  inner_join(fi_ch_eligible, by = "pid_key")

model_vars <- c("event", "fi_full", "age", "female", "period")
ch_missing <- data.frame(
  variable = model_vars,
  n = vapply(pp_ch[model_vars], length, integer(1)),
  missing = vapply(pp_ch[model_vars], function(x) sum(is.na(x)), integer(1)),
  missing_pct = vapply(pp_ch[model_vars], function(x) mean(is.na(x)) * 100, numeric(1)),
  stringsAsFactors = FALSE
)

ch_complete <- pp_ch %>%
  filter(if_all(all_of(model_vars), ~ !is.na(.x))) %>%
  mutate(period = as.numeric(period), female = as.numeric(female))

if (nrow(ch_complete) == 0) stop("No complete CHARLS development rows.")
if (!all(ch_complete$event %in% c(0, 1))) stop("CHARLS event is not binary 0/1.")

cat("\nCHARLS development sample:\n")
cat("Rows before complete-case filtering:", nrow(pp_ch), "\n")
cat("Rows after complete-case filtering:", nrow(ch_complete), "\n")
cat("Unique persons:", n_distinct(ch_complete$pid_key), "\n")
cat("Events:", sum(ch_complete$event == 1), "\n")
cat("FI median:", median(ch_complete$fi_full), "\n")
print(ch_missing, row.names = FALSE)

fit_a <- glm(event ~ age + female + factor(period), data = ch_complete, family = binomial())
fit_b <- glm(event ~ fi_full + age + female + factor(period), data = ch_complete, family = binomial())

coef_table <- function(fit, model_name) {
  sm <- as.data.frame(summary(fit)$coefficients, stringsAsFactors = FALSE)
  sm$term <- rownames(sm)
  rownames(sm) <- NULL
  names(sm)[1:4] <- c("estimate", "std_error", "statistic", "p_value")
  sm$model <- model_name
  sm[, c("model", "term", "estimate", "std_error", "statistic", "p_value")]
}

coef_a <- coef_table(fit_a, "Model_A")
coef_b <- coef_table(fit_b, "Model_B")
write.csv(coef_a, file.path(result_dir, paste0("model_a_charls_coefficients_", stamp, ".csv")), row.names = FALSE)
write.csv(coef_b, file.path(result_dir, paste0("model_b_charls_coefficients_", stamp, ".csv")), row.names = FALSE)

auc_safe <- function(y, pred) {
  keep <- is.finite(pred) & !is.na(y)
  y <- y[keep]
  pred <- pred[keep]
  if (length(unique(y)) < 2) return(NA_real_)
  as.numeric(auc(roc(y, pred, quiet = TRUE, direction = "auto")))
}

pred_a_ch <- predict(fit_a, type = "response")
pred_b_ch <- predict(fit_b, type = "response")
c_a_ch <- auc_safe(ch_complete$event, pred_a_ch)
c_b_ch <- auc_safe(ch_complete$event, pred_b_ch)
delta_c <- c_b_ch - c_a_ch

## CLHLS external validation set. IDs are normalised before joining because the
## parquet sources store CLHLS FI IDs as character and outcome IDs as numeric.
fi_cl_eligible <- clhls_fi %>%
  filter(!is.na(age), age >= 60, !is.na(fi_excluded), !fi_excluded) %>%
  transmute(id_key, age, fi_full)

clhls_df <- fi_cl_eligible %>%
  inner_join(
    clhls_out %>%
      filter(!is.na(event_4y), prebaseline_death %in% c(0, 1), prebaseline_death == 0) %>%
      transmute(id_key, female, event_4y),
    by = "id_key"
  ) %>%
  filter(if_all(c("age", "fi_full", "female", "event_4y"), ~ !is.na(.x))) %>%
  mutate(
    age = as.numeric(age),
    female = as.numeric(female),
    event_4y = as.numeric(event_4y)
  )

if (nrow(clhls_df) == 0) stop("No complete CLHLS external validation rows.")
if (!all(clhls_df$event_4y %in% c(0, 1))) stop("CLHLS event_4y is not binary 0/1.")

cl_missing <- data.frame(
  variable = c("event_4y", "fi_full", "age", "female"),
  missing = c(
    sum(is.na(clhls_out$event_4y)),
    sum(is.na(clhls_fi$fi_full)),
    sum(is.na(clhls_fi$age)),
    sum(is.na(clhls_out$female))
  ),
  stringsAsFactors = FALSE
)
cl_missing$source_n <- c(nrow(clhls_out), nrow(clhls_fi), nrow(clhls_fi), nrow(clhls_out))
cl_missing$missing_pct <- 100 * cl_missing$missing / cl_missing$source_n

## Convert frozen discrete-time hazards into a four-year cumulative risk.
newdata_base <- data.frame(
  fi_full = clhls_df$fi_full,
  age = clhls_df$age,
  female = clhls_df$female,
  period = 1
)
newdata_second <- newdata_base
newdata_second$period <- 2
h1 <- predict(fit_b, newdata = newdata_base, type = "response")
h2 <- predict(fit_b, newdata = newdata_second, type = "response")
clhls_df$pred_4y <- 1 - (1 - h1) * (1 - h2)
clhls_df$pred_4y <- pmin(pmax(clhls_df$pred_4y, 1e-8), 1 - 1e-8)

## Model A four-year risk is included for the prespecified delta-C comparison.
newdata_base_a <- newdata_base[c("age", "female", "period")]
newdata_second_a <- newdata_base_a
newdata_second_a$period <- 2
ha1 <- predict(fit_a, newdata = newdata_base_a, type = "response")
ha2 <- predict(fit_a, newdata = newdata_second_a, type = "response")
clhls_df$pred_4y_a <- pmin(pmax(1 - (1 - ha1) * (1 - ha2), 1e-8), 1 - 1e-8)

bootstrap_auc <- function(y, pred, B = 500, seed = 2026) {
  set.seed(seed)
  n <- length(y)
  vals <- replicate(B, {
    idx <- sample.int(n, n, replace = TRUE)
    auc_safe(y[idx], pred[idx])
  })
  vals <- vals[is.finite(vals)]
  c(estimate = auc_safe(y, pred), lo = unname(quantile(vals, 0.025, names = FALSE)), hi = unname(quantile(vals, 0.975, names = FALSE)))
}

c_ext_b <- bootstrap_auc(clhls_df$event_4y, clhls_df$pred_4y, B = 500, seed = 2026)
c_ext_a <- auc_safe(clhls_df$event_4y, clhls_df$pred_4y_a)

lp_pred <- qlogis(clhls_df$pred_4y)
cal_intercept <- unname(coef(glm(event_4y ~ offset(lp_pred), data = clhls_df, family = binomial()))[1])
cal_slope <- unname(coef(glm(event_4y ~ lp_pred, data = clhls_df, family = binomial()))[2])
oe_ratio <- mean(clhls_df$event_4y) / mean(clhls_df$pred_4y)
brier <- mean((clhls_df$event_4y - clhls_df$pred_4y)^2)
null_rate <- mean(clhls_df$event_4y)
brier_null <- mean((clhls_df$event_4y - null_rate)^2)
ipa <- if (brier_null > 0) 1 - brier / brier_null else NA_real_

## Calibration plot using rank-based deciles, which remains valid when predicted
## risks have tied values.
clhls_df$decile <- dplyr::ntile(clhls_df$pred_4y, 10)
cal_data <- clhls_df %>%
  group_by(decile) %>%
  summarise(
    predicted = mean(pred_4y),
    observed = mean(event_4y),
    n = n(),
    .groups = "drop"
  )
write.csv(cal_data, file.path(result_dir, paste0("aim1_calibration_deciles_clhls_", stamp, ".csv")), row.names = FALSE)

cal_plot <- ggplot(cal_data, aes(x = predicted, y = observed)) +
  geom_abline(slope = 1, intercept = 0, linetype = 2, colour = "grey50") +
  geom_line(colour = "#2C7FB8") +
  geom_point(size = 2.5, colour = "#2C7FB8") +
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1)) +
  labs(x = "Predicted 4-year mortality", y = "Observed 4-year mortality", title = "CLHLS external validation: calibration") +
  theme_minimal(base_size = 12)
ggsave(file.path(figure_dir, paste0("calibration_plot_clhls_", stamp, ".png")), cal_plot, width = 8, height = 7, dpi = 120)

## Decision curve analysis is optional per task instructions.
dca_status <- "skipped"
dca_error <- ""
if (requireNamespace("dcurves", quietly = TRUE)) {
  dca_obj <- tryCatch(
    dcurves::dca(event_4y ~ pred_4y, data = clhls_df, thresholds = seq(0.05, 0.40, by = 0.01)),
    error = function(e) e
  )
  if (inherits(dca_obj, "error")) {
    dca_error <- conditionMessage(dca_obj)
  } else {
    dca_status <- "completed"
    dca_plot <- tryCatch(plot(dca_obj), error = function(e) NULL)
    if (!is.null(dca_plot)) {
      ggsave(file.path(figure_dir, paste0("dca_clhls_", stamp, ".png")), dca_plot, width = 9, height = 7, dpi = 120)
    } else {
      dca_status <- "computed_plot_failed"
    }
    dca_data <- tryCatch(as.data.frame(dca_obj), error = function(e) NULL)
    if (!is.null(dca_data)) write.csv(dca_data, file.path(result_dir, paste0("aim1_dca_clhls_", stamp, ".csv")), row.names = FALSE)
  }
} else {
  dca_error <- "dcurves package unavailable"
}

performance <- data.frame(
  metric = c("n_persons", "n_events", "event_rate", "C_index", "C_index_95CI_lo", "C_index_95CI_hi", "OE_ratio", "calibration_intercept", "calibration_slope", "brier_score", "IPA", "delta_C_FI_vs_base", "edu_adjusted"),
  CHARLS_internal = c(
    n_distinct(ch_complete$pid_key), sum(ch_complete$event == 1), mean(ch_complete$event), c_b_ch, NA, NA, NA, NA, NA, mean((ch_complete$event - pred_b_ch)^2), NA, delta_c, as.character(edu_available)
  ),
  CLHLS_external = c(
    n_distinct(clhls_df$id_key), sum(clhls_df$event_4y == 1), mean(clhls_df$event_4y), c_ext_b["estimate"], c_ext_b["lo"], c_ext_b["hi"], oe_ratio, cal_intercept, cal_slope, brier, ipa, NA, as.character(edu_available)
  ),
  stringsAsFactors = FALSE
)
write.csv(performance, file.path(result_dir, paste0("aim1_performance_table_", stamp, ".csv")), row.names = FALSE)
write.csv(ch_missing, file.path(result_dir, paste0("aim1_missingness_charls_", stamp, ".csv")), row.names = FALSE)
write.csv(cl_missing, file.path(result_dir, paste0("aim1_missingness_clhls_", stamp, ".csv")), row.names = FALSE)

report_file <- file.path(result_dir, paste0("aim1_report_", stamp, ".md"))
report <- c(
  paste0("# Aim 1 report (", stamp, ")"),
  "", "## Scope", "CHARLS 2011 age-60+ FI-eligible person-period data were used to develop pooled logistic Model A (age + female + period) and Model B (FI + age + female + period). Model B coefficients were frozen and applied to CLHLS 2011/12 for four-year mortality validation.",
  "", "## Data and missingness",
  paste0("- CHARLS development: ", n_distinct(ch_complete$pid_key), " persons, ", nrow(ch_complete), " person-period rows, ", sum(ch_complete$event == 1), " events."),
  paste0("- CLHLS external validation: ", n_distinct(clhls_df$id_key), " persons, ", sum(clhls_df$event_4y == 1), " events (event rate ", sprintf("%.1f", 100 * mean(clhls_df$event_4y)), "%)."),
  paste0("- CHARLS complete-case row retention: ", nrow(ch_complete), " / ", nrow(pp_ch), " (", sprintf("%.1f", 100 * nrow(ch_complete) / nrow(pp_ch)), "%)."),
  paste0("- CLHLS source missingness: event_4y ", cl_missing$missing_pct[cl_missing$variable == "event_4y"], "%; FI ", sprintf("%.1f", cl_missing$missing_pct[cl_missing$variable == "fi_full"]), "%; female ", sprintf("%.1f", cl_missing$missing_pct[cl_missing$variable == "female"]), "%; age ", sprintf("%.1f", cl_missing$missing_pct[cl_missing$variable == "age"]), "%."),
  paste0("- Education adjustment: ", if (edu_available) "included" else "not included; ", edu_note),
  "", "## Model coefficients", "See `model_a_charls_coefficients_2026-07-29.csv` and `model_b_charls_coefficients_2026-07-29.csv`.",
  "", "## Internal discrimination", 
  paste0("- Model A apparent C-index: ", sprintf("%.4f", c_a_ch), "; Model B apparent C-index: ", sprintf("%.4f", c_b_ch), "; delta C: ", sprintf("%.4f", delta_c), "."),
  paste0("- Prespecified H1 threshold delta C >= 0.02: ", ifelse(delta_c >= 0.02, "met", "not met"), "."),
  "", "## CLHLS external validation", 
  paste0("- Model B C-index: ", sprintf("%.4f", c_ext_b["estimate"]), " (bootstrap 95% CI ", sprintf("%.4f", c_ext_b["lo"]), "-", sprintf("%.4f", c_ext_b["hi"]), ")."),
  paste0("- O:E ratio: ", sprintf("%.4f", oe_ratio), "; calibration intercept: ", sprintf("%.4f", cal_intercept), "; calibration slope: ", sprintf("%.4f", cal_slope), "."),
  paste0("- Brier score: ", sprintf("%.5f", brier), "; IPA: ", sprintf("%.4f", ipa), "."),
  paste0("- DCA status: ", dca_status, if (nzchar(dca_error)) paste0(" (", dca_error, ")") else "", "."),
  "", "## Warnings and interpretation", 
  "- This is the preliminary no-education-adjustment version requested by the task. Education should be added and the models rerun if a validated harmonised education join becomes available.",
  "- Internal C-index values are apparent row-level discrimination for pooled person-period observations; the external C-index is calculated at the CLHLS person level.",
  "- Calibration slope substantially below 1 or O:E materially above 1 would indicate underprediction and should be reviewed before manuscript use.",
  "", "## Reproducibility", paste0("Run with: `D:/LeStoreDownload/R/R-4.4.1/bin/x64/Rscript.exe --vanilla --no-restore --no-save code/04_model/run_aim1_charls_clhls_2026-07-29.R`.")
)
writeLines(report, report_file, useBytes = TRUE)

cat("\n=== Final Aim 1 results ===\n")
print(performance, row.names = FALSE)
cat("CLHLS predicted risk summary:\n")
print(summary(clhls_df$pred_4y))
cat("Calibration plot:", file.path(figure_dir, paste0("calibration_plot_clhls_", stamp, ".png")), "\n")
cat("DCA status:", dca_status, if (nzchar(dca_error)) paste0("; ", dca_error) else "", "\n")
cat("Report:", report_file, "\n")

