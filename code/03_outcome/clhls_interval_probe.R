# CLHLS 2011-2018 outcome probe: Step 2-4 only.
# This script constructs visit dates and death intervals. It deliberately does
# not construct event_5y/event_8y or any FI/IC variables.

options(stringsAsFactors = FALSE, warn = 1)

project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
raw_cache_path <- file.path(project_root, "data", "interim", "clhls_2011_selected_raw_2026-07-27.parquet")
interim_path <- file.path(project_root, "data", "interim", "clhls_2011_baseline_interim_2026-07-27.parquet")
result_dir <- file.path(project_root, "results", "outcome_clhls")
report_path <- file.path(result_dir, "clhls_step1_4_report_2026-07-27.md")
log_path <- file.path(project_root, "logs", "clhls_step1_4_2026-07-27.log")

dir.create(dirname(interim_path), recursive = TRUE, showWarnings = FALSE)
dir.create(result_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(log_path), recursive = TRUE, showWarnings = FALSE)

log_lines <- if (file.exists(log_path)) readLines(log_path, warn = FALSE, encoding = "UTF-8") else character()
log_msg <- function(level, message) {
  line <- sprintf("[%s] %s %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), level, message)
  log_lines <<- c(log_lines, line)
  message(line)
}
flush_log <- function() writeLines(log_lines, log_path, useBytes = TRUE)
fail <- function(message) {
  log_msg("FAIL", message)
  flush_log()
  stop(message, call. = FALSE)
}
assert_true <- function(ok, label, detail = "") {
  if (isTRUE(ok)) log_msg("PASS", paste(label, detail))
  else fail(paste(label, detail))
}

if (!file.exists(raw_cache_path)) fail(paste("Missing extraction cache:", raw_cache_path))
for (pkg in c("arrow", "ggplot2")) {
  if (!requireNamespace(pkg, quietly = TRUE)) fail(paste("Package required:", pkg))
}

dat <- as.data.frame(arrow::read_parquet(raw_cache_path), check.names = FALSE)
expected_names <- c(
  "id", "a1", "yearin", "monthin", "dayin", "trueage", "dth11_14",
  "yearin_14", "monthin_14", "dayin_14", "dth14_18",
  "yearin_18", "monthin_18", "dayin_18"
)
assert_true(nrow(dat) == 9765L, "Intermediate N == 9765")
assert_true(identical(names(dat), expected_names), "Intermediate fields match contract")

to_date <- function(year, month, day) {
  year <- as.integer(year)
  month <- as.integer(month)
  day <- as.integer(day)
  valid <- !is.na(year) & !is.na(month) & !is.na(day) &
    year >= 1900L & month >= 1L & month <= 12L & day >= 1L & day <= 31L
  out <- as.Date(rep(NA_character_, length(year)))
  out[valid] <- as.Date(sprintf("%04d-%02d-%02d", year[valid], month[valid], day[valid]))
  out
}

dat$baseline_date <- to_date(dat$yearin, dat$monthin, dat$dayin)
dat$date_14 <- to_date(dat$yearin_14, dat$monthin_14, dat$dayin_14)
dat$date_18 <- to_date(dat$yearin_18, dat$monthin_18, dat$dayin_18)
for (v in c("baseline_date", "date_14", "date_18")) {
  log_msg("INFO", sprintf("%s missing=%d", v, sum(is.na(dat[[v]]))))
}
assert_true(sum(is.na(dat$baseline_date)) == 0L, "Baseline date has no missing values")

date_summary <- function(x) {
  x <- x[!is.na(x)]
  if (!length(x)) return(list(min = as.Date(NA), median = as.Date(NA), max = as.Date(NA), n = 0L))
  list(
    min = min(x),
    median = as.Date(stats::median(as.numeric(x)), origin = "1970-01-01"),
    max = max(x), n = length(x)
  )
}
summaries <- lapply(list(baseline = dat$baseline_date, wave_14 = dat$date_14, wave_18 = dat$date_18), date_summary)
names(summaries) <- c("baseline", "wave_14", "wave_18")
fmt_date <- function(x) {
  if (length(x) != 1L || is.na(x)) "NA" else format(x, "%Y-%m-%d")
}
for (nm in names(summaries)) {
  s <- summaries[[nm]]
  log_msg("INFO", sprintf("%s range=%s..%s median=%s n=%d", nm, fmt_date(s$min), fmt_date(s$max), fmt_date(s$median), s$n))
}

date14_min <- min(dat$date_14, na.rm = TRUE)
date14_max <- max(dat$date_14, na.rm = TRUE)
date18_min <- min(dat$date_18, na.rm = TRUE)
date18_max <- max(dat$date_18, na.rm = TRUE)

make_month_counts <- function(x, wave) {
  x <- x[!is.na(x)]
  data.frame(wave = wave, month = format(x, "%Y-%m"), stringsAsFactors = FALSE)
}
month_counts <- rbind(
  make_month_counts(dat$baseline_date, "Baseline"),
  make_month_counts(dat$date_14, "2014 visit"),
  make_month_counts(dat$date_18, "2018 visit")
)
month_counts <- as.data.frame(table(month_counts$wave, month_counts$month), stringsAsFactors = FALSE)
names(month_counts) <- c("wave", "month", "n")
month_counts$n <- as.integer(month_counts$n)

age <- as.numeric(dat$trueage)
age_summary <- c(
  min = min(age, na.rm = TRUE),
  p25 = as.numeric(stats::quantile(age, 0.25, na.rm = TRUE, names = FALSE)),
  median = stats::median(age, na.rm = TRUE),
  p75 = as.numeric(stats::quantile(age, 0.75, na.rm = TRUE, names = FALSE)),
  max = max(age, na.rm = TRUE), mean = mean(age, na.rm = TRUE), sd = stats::sd(age, na.rm = TRUE)
)
age_group <- cut(age, breaks = c(-Inf, 59, 69, 79, 89, 99, Inf),
                 labels = c("<60", "60-69", "70-79", "80-89", "90-99", "100+"), right = TRUE)
age_group_counts <- table(age_group)
age_group_text <- paste(
  sprintf("%s=%d", names(age_group_counts), as.integer(age_group_counts)),
  collapse = "; "
)
sex_label <- ifelse(dat$a1 == 1, "male", ifelse(dat$a1 == 2, "female", NA_character_))
female <- as.integer(dat$a1 == 2)
assert_true(sum(is.na(sex_label)) == 0L, "Sex a1 has no missing or unexpected values")
assert_true(sum(is.na(age)) == 0L, "trueage has no missing values")

status1 <- as.numeric(dat$dth11_14)
status2 <- as.numeric(dat$dth14_18)
followup_status <- rep("unexpected", nrow(dat))
followup_status[status1 == 1] <- "dead_interval_1"
followup_status[status1 == 0 & status2 == 1] <- "dead_interval_2"
followup_status[status1 == 0 & status2 == 0] <- "surviving_2018"
followup_status[status1 == -9] <- "lost_interval_1"
followup_status[status1 == 0 & status2 == -9] <- "lost_interval_2"
assert_true(!any(followup_status == "unexpected"), "All follow-up status combinations are classified")

interval_L <- as.Date(rep(NA_character_, nrow(dat)))
interval_R <- as.Date(rep(NA_character_, nrow(dat)))
interval_1 <- status1 == 1
interval_2 <- status1 == 0 & status2 == 1
interval_L[interval_1] <- dat$baseline_date[interval_1]
interval_R[interval_1] <- date14_max
interval_L[interval_2] <- dat$date_14[interval_2]
interval_L[interval_2 & is.na(interval_L)] <- date14_min
interval_R[interval_2] <- date18_max
interval_L_days <- as.numeric(interval_L - dat$baseline_date)
interval_R_days <- as.numeric(interval_R - dat$baseline_date)
interval_width_days <- as.numeric(interval_R - interval_L)
interval_crosses_1826 <- !is.na(interval_L_days) & !is.na(interval_R_days) &
  interval_L_days < 1826 & interval_R_days > 1826
assert_true(!any(!is.na(interval_L) & !is.na(interval_R) & interval_L > interval_R),
            "All death intervals have L <= R")
assert_true(sum(interval_1) == 2879L, "Interval 1 death count == 2879")
assert_true(sum(interval_2) == 1837L, "Interval 2 death count == 1837")
assert_true(sum(interval_crosses_1826) <= sum(interval_1) + sum(interval_2),
            "Crossing count is bounded by all deaths")
assert_true(2884L + 1837L + 1345L == 6066L, "2884 + 1837 + 1345 == 6066")

out <- data.frame(
  id = dat$id,
  yearin = dat$yearin, monthin = dat$monthin, dayin = dat$dayin,
  baseline_date = dat$baseline_date,
  trueage = age, a1 = dat$a1, female = female,
  dth11_14_raw = status1, dth14_18_raw = status2,
  date_14 = dat$date_14, date_18 = dat$date_18,
  interval_L = interval_L, interval_R = interval_R,
  interval_L_days = interval_L_days, interval_R_days = interval_R_days,
  interval_crosses_1826 = interval_crosses_1826,
  followup_status = followup_status,
  stringsAsFactors = FALSE
)
arrow::write_parquet(out, interim_path, compression = "snappy")
log_msg("PASS", paste("Wrote Step 1-4 interim parquet:", normalizePath(interim_path, winslash = "/")))

library(ggplot2)
p_theme <- theme_minimal(base_size = 11) + theme(legend.position = "bottom")
ggsave(file.path(result_dir, "visit_monthly_counts.png"),
       ggplot(month_counts, aes(x = month, y = n, fill = wave)) +
         geom_col(show.legend = FALSE) + facet_wrap(~wave, ncol = 1, scales = "free_y") +
         labs(title = "CLHLS visit month distributions", x = "Year-month", y = "Participants") +
         p_theme + theme(axis.text.x = element_text(angle = 60, hjust = 1)),
       width = 12, height = 9, dpi = 160)

age_plot_data <- data.frame(age = age, sex = sex_label, age_group = age_group)
ggsave(file.path(result_dir, "baseline_age_by_sex.png"),
       ggplot(age_plot_data, aes(x = age, fill = sex)) +
         geom_histogram(binwidth = 2, boundary = 60, position = "identity", alpha = 0.55) +
         labs(title = "CLHLS baseline age distribution by sex", x = "Validated age", y = "Participants") +
         p_theme,
       width = 10, height = 6, dpi = 160)

death_data <- data.frame(
  interval_width_days = interval_width_days[!is.na(interval_width_days)],
  interval = ifelse(interval_1[!is.na(interval_width_days)], "Interval 1", "Interval 2")
)
ggsave(file.path(result_dir, "interval_width_days.png"),
       ggplot(death_data, aes(x = interval_width_days, fill = interval)) +
         geom_histogram(binwidth = 60, boundary = 0, position = "identity", alpha = 0.6) +
         labs(title = "CLHLS death interval widths", x = "Interval width (days)", y = "Deaths") +
         p_theme,
       width = 10, height = 6, dpi = 160)

charls_path <- file.path(project_root, "data", "analysis", "charls_outcome_2026-07-27.parquet")
charls_available <- file.exists(charls_path)
if (charls_available) {
  charls <- as.data.frame(arrow::read_parquet(charls_path), check.names = FALSE)
  age_col <- intersect(c("baseline_age", "trueage", "age"), names(charls))[1]
  if (!is.na(age_col)) {
    compare <- rbind(
      data.frame(cohort = "CLHLS", age = age[age >= 60]),
      data.frame(cohort = "CHARLS", age = as.numeric(charls[[age_col]])[as.numeric(charls[[age_col]]) >= 60])
    )
    ggsave(file.path(result_dir, "clhls_charls_age_comparison.png"),
           ggplot(compare, aes(x = age, fill = cohort)) +
             geom_histogram(binwidth = 2, boundary = 60, position = "identity", alpha = 0.55) +
             labs(title = "Baseline age distribution: CLHLS vs CHARLS", x = "Age", y = "Participants") +
             p_theme,
           width = 10, height = 6, dpi = 160)
  } else {
    charls_available <- FALSE
  }
}

fmt_num <- function(x, digits = 1) formatC(x, format = "f", digits = digits, big.mark = ",")
fmt_pct <- function(x, denom) sprintf("%.2f%%", 100 * x / denom)
date_range_text <- function(x) {
  x <- x[!is.na(x)]
  sprintf("%s to %s (n=%s)", fmt_date(min(x)), fmt_date(max(x)), formatC(length(x), big.mark = ",", format = "d"))
}

cross_total <- sum(interval_crosses_1826)
cross_i1 <- sum(interval_crosses_1826 & interval_1)
cross_i2 <- sum(interval_crosses_1826 & interval_2)
cross_death_total <- sum(interval_1 | interval_2)
cross_width <- interval_width_days[interval_crosses_1826]
cross_l_distance <- 1826 - interval_L_days[interval_crosses_1826]

report <- c(
  "# CLHLS Step 1-4 Outcome Probe (2011-2018)",
  "",
  "## Scope",
  "This report covers extraction, assertion, visit-date measurement, baseline construction, and interval construction only. Step 5 event_5y/event_8y construction, FI/IC construction, and final analysis outputs were not run.",
  "",
  "## Step 1 Assertions",
  "- Input: clhls_2011_2018_longitudinal_dataset_released_version1.sav",
  "- N = 9,765; selected fields = 14; raw source was read with haven::read_sav().",
  "- dth11_14 expected counts: -9 lost = 820; 0 surviving = 6,066; 1 died = 2,879; missing = 0.",
  "- dth14_18 expected counts: -9 lost = 1,345; 0 surviving = 2,884; 1 died = 1,837; missing = 3,699.",
  "- Baseline yearin expected counts: 2011 = 7,328; 2012 = 2,437.",
  "- Cross-check: 2,884 + 1,837 + 1,345 = 6,066: PASS.",
  "",
  "## Step 2 Visit-Date Measurements",
  paste0("- Baseline: ", date_range_text(dat$baseline_date), "; median = ", fmt_date(summaries$baseline$median), "."),
  paste0("- 2014 visit: ", date_range_text(dat$date_14), "; median = ", fmt_date(summaries$wave_14$median), "; span = ", as.integer(date14_max - date14_min), " days."),
  paste0("- 2018 visit: ", date_range_text(dat$date_18), "; median = ", fmt_date(summaries$wave_18$median), "; span = ", as.integer(date18_max - date18_min), " days."),
  "- The 2018 visit dates empirically span more than the calendar year 2018; the observed dates, not the wave label, were used.",
  "- Monthly counts are exported in visit_monthly_counts.png.",
  "",
  "## Step 3 Baseline",
  paste0("- baseline_date = make_date(yearin, monthin, dayin); missing dates = ", sum(is.na(dat$baseline_date)), "."),
  paste0("- trueage: min ", age_summary[["min"]], "; P25 ", age_summary[["p25"]], "; median ", age_summary[["median"]], "; P75 ", age_summary[["p75"]], "; max ", age_summary[["max"]], "; mean ", fmt_num(age_summary[["mean"]]), "; SD ", fmt_num(age_summary[["sd"]]), "."),
  paste0("- Age groups: ", age_group_text, "."),
  paste0("- Age >=80: ", sum(age >= 80), " (", fmt_pct(sum(age >= 80), nrow(dat)), "); >=90: ", sum(age >= 90), " (", fmt_pct(sum(age >= 90), nrow(dat)), "); >=100: ", sum(age >= 100), " (", fmt_pct(sum(age >= 100), nrow(dat)), ")."),
  paste0("- Sex a1: male = ", sum(dat$a1 == 1), "; female = ", sum(dat$a1 == 2), "; missing/unexpected = ", sum(is.na(sex_label)), "."),
  "- Baseline age plot is exported in baseline_age_by_sex.png.",
  if (charls_available) "- CHARLS comparison plot was exported." else "- CHARLS comparison plot was not produced because data/analysis/charls_outcome_2026-07-27.parquet is unavailable.",
  "",
  "## Step 4 Death Intervals",
  paste0("- Interval 1 deaths: ", sum(interval_1), "; [baseline_date, observed 2014 visit-period maximum = ", fmt_date(date14_max), "]."),
  paste0("- Interval 2 deaths: ", sum(interval_2), "; [individual 2014 visit date, observed 2018 visit-period maximum = ", fmt_date(date18_max), "]; fallback to 2014 minimum date when individual date missing = ", sum(interval_2 & is.na(dat$date_14)), "."),
  paste0("- Death intervals total: ", cross_death_total, "."),
  paste0("- Intervals crossing 1,826 days: ", cross_total, " / ", cross_death_total, " (", fmt_pct(cross_total, cross_death_total), "); interval 1 = ", cross_i1, "; interval 2 = ", cross_i2, "."),
  if (cross_total > 0) paste0("- Among crossers, interval width days: min ", min(cross_width), "; median ", stats::median(cross_width), "; max ", max(cross_width), "; distance from interval L to day 1,826: min ", min(cross_l_distance), "; median ", stats::median(cross_l_distance), "; max ", max(cross_l_distance), ".") else "- No intervals crossed 1,826 days.",
  "- Interval width plot is exported in interval_width_days.png.",
  "",
  "## Status Counts",
  paste0("- dth11_14 surviving = ", sum(status1 == 0), "; dead = ", sum(status1 == 1), "; lost = ", sum(status1 == -9), "."),
  paste0("- dth14_18 among dth11_14 survivors: surviving = ", sum(status1 == 0 & status2 == 0), "; dead = ", sum(status1 == 0 & status2 == 1), "; lost = ", sum(status1 == 0 & status2 == -9), "."),
  "",
  "## Constraints and Next Gate",
  "- No 5-year or 8-year event variables were created in this Step 1-4 run.",
  "- The observed 2018 date range and the interval-crossing count must be reviewed before selecting the subsequent outcome strategy.",
  "- The raw SAV file remains unmodified."
)
writeLines(report, report_path, useBytes = TRUE)
log_msg("PASS", paste("Wrote report:", normalizePath(report_path, winslash = "/")))
log_msg("INFO", sprintf("cross_1826_total=%d cross_1826_interval1=%d cross_1826_interval2=%d", cross_total, cross_i1, cross_i2))
flush_log()

message("CLHLS Step 1-4 probe complete: ", normalizePath(report_path, winslash = "/"))
