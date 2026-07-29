# CLHLS validated-date mortality outcome v2.
# Raw SAV data are read-only; v1 interval outputs are not used.

options(stringsAsFactors = FALSE, warn = 1)

project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
raw_path <- file.path(dirname(project_root), "sql", "CLHLS",
                      "CLHLS_dataset_2008-2018_SPSS",
                      "clhls_2011_2018_longitudinal_dataset_released_version1.sav")
analysis_dir <- file.path(project_root, "data", "analysis")
result_dir <- file.path(project_root, "results", "outcome_clhls")
log_dir <- file.path(project_root, "logs")
output_path <- file.path(analysis_dir, "clhls_outcome_2026-07-28.parquet")
report_path <- file.path(result_dir, "clhls_outcome_v2_report_2026-07-28.md")
negative_path <- file.path(result_dir, "clhls_prebaseline_deaths_v2_2026-07-28.csv")
log_path <- file.path(log_dir, "clhls_outcome_v2_2026-07-28.log")
dir.create(analysis_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(result_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

log_lines <- character()
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
assert_true <- function(ok, label) {
  if (isTRUE(ok)) log_msg("PASS", label) else fail(label)
}
if (!file.exists(raw_path)) fail(paste("Missing SAV:", raw_path))
for (pkg in c("haven", "arrow", "ggplot2")) {
  if (!requireNamespace(pkg, quietly = TRUE)) fail(paste("Missing package:", pkg))
}

selected_names <- c("id", "yearin", "monthin", "dayin", "trueage", "a1",
                    "dth11_14", "d14vyear", "d14vmonth", "d14vday",
                    "dth14_18", "d18vyear", "d18vmonth", "d18vday")
log_msg("INFO", paste("Reading SAV with haven:", raw_path))
dat <- tryCatch(
  haven::read_sav(raw_path, col_select = tidyselect::all_of(selected_names),
                  .name_repair = "minimal"),
  error = function(e) fail(conditionMessage(e))
)
assert_true(nrow(dat) == 9765L, "Input N == 9765")
assert_true(setequal(names(dat), selected_names), "Selected fields match contract")
dat <- as.data.frame(lapply(dat, as.numeric), check.names = FALSE)
count_code <- function(x, code) sum(!is.na(x) & x == code)
assert_true(count_code(dat$dth11_14, -9) == 820L &&
            count_code(dat$dth11_14, 0) == 6066L &&
            count_code(dat$dth11_14, 1) == 2879L &&
            sum(is.na(dat$dth11_14)) == 0L, "dth11_14 counts PASS")
assert_true(count_code(dat$dth14_18, -9) == 1345L &&
            count_code(dat$dth14_18, 0) == 2884L &&
            count_code(dat$dth14_18, 1) == 1837L &&
            sum(is.na(dat$dth14_18)) == 3699L, "dth14_18 counts PASS")
assert_true(all(dat$yearin %in% c(2011, 2012)), "Baseline yearin PASS")
assert_true(all(dat$a1 %in% c(1, 2)) && all(!is.na(dat$trueage)),
            "Sex and age fields PASS")

make_date <- function(year, month, day, impute_day = FALSE) {
  year <- as.integer(year)
  month <- as.integer(month)
  day <- as.integer(day)
  valid_ym <- !is.na(year) & !is.na(month) & year >= 1900L &
    month >= 1L & month <= 12L
  if (impute_day) day <- ifelse(is.na(day), 15L, pmin(pmax(day, 1L), 28L))
  valid <- valid_ym & !is.na(day) & day >= 1L & day <= 31L
  out <- as.Date(rep(NA_character_, length(year)))
  out[valid] <- as.Date(sprintf("%04d-%02d-%02d", year[valid],
                                month[valid], day[valid]))
  out
}
baseline_date <- make_date(dat$yearin, dat$monthin, dat$dayin, TRUE)
d14_date <- make_date(dat$d14vyear, dat$d14vmonth, dat$d14vday, TRUE)
d18_date <- make_date(dat$d18vyear, dat$d18vmonth, dat$d18vday, TRUE)
assert_true(sum(is.na(baseline_date)) == 0L, "Baseline dates have no missing values")

death_source <- rep("none", nrow(dat))
death_source[dat$dth11_14 == 1] <- "d14"
death_source[dat$dth11_14 == 0 & dat$dth14_18 == 1] <- "d18"
assert_true(sum(death_source == "d14") == 2879L, "d14 death count == 2879")
assert_true(sum(death_source == "d18") == 1837L, "d18 death count == 1837")
assert_true(sum(death_source != "none") == 4716L, "Total death count == 4716")

death_date <- as.Date(rep(NA_character_, nrow(dat)))
death_date[death_source == "d14"] <- d14_date[death_source == "d14"]
death_date[death_source == "d18"] <- d18_date[death_source == "d18"]
death_year <- as.integer(format(death_date, "%Y"))
death_month <- as.integer(format(death_date, "%m"))
death_day <- as.integer(format(death_date, "%d"))
days <- as.numeric(death_date - baseline_date)
died <- death_source != "none"
prebaseline_death <- as.integer(died & !is.na(days) & days < 0)

followup_status <- rep("unexpected", nrow(dat))
followup_status[died] <- "dead"
followup_status[dat$dth11_14 == 0 & dat$dth14_18 == 0] <- "alive_censored"
followup_status[dat$dth11_14 == -9 |
                (dat$dth11_14 == 0 & dat$dth14_18 == -9)] <- "lost"
assert_true(!any(followup_status == "unexpected"), "Follow-up combinations classified")

event_4y <- rep(NA_integer_, nrow(dat))
nonnegative <- !is.na(days) & days >= 0
event_4y[nonnegative] <- as.integer(days[nonnegative] <= 1461)
event_4y[followup_status == "alive_censored"] <- 0L
time_4y <- rep(NA_real_, nrow(dat))
time_4y[nonnegative] <- pmin(days[nonnegative], 1461)
time_4y[followup_status == "alive_censored"] <- 1461

assert_true(sum(!is.na(death_date)) == 4650L, "Constructed death dates == 4650")
assert_true(sum(prebaseline_death) == 45L, "Pre-baseline deaths == 45")
assert_true(sum(event_4y == 1L, na.rm = TRUE) == 3502L, "4-year events == 3502")
assert_true(sum(dat$trueage >= 60) == 9749L, "Age >=60 N == 9749")
assert_true(sum(event_4y == 1L & dat$trueage >= 60, na.rm = TRUE) == 3502L,
            "Age >=60 events == 3502")

out <- data.frame(
  id = dat$id, baseline_date = baseline_date, baseline_age = dat$trueage,
  female = as.integer(dat$a1 == 2), dth11_14 = dat$dth11_14,
  dth14_18 = dat$dth14_18, death_year = death_year,
  death_month = death_month, death_day = death_day, death_date = death_date,
  days = days, followup_status = followup_status,
  prebaseline_death = prebaseline_death, event_4y = event_4y,
  time_4y = time_4y, stringsAsFactors = FALSE
)
arrow::write_parquet(out, output_path, compression = "snappy")
negative <- out[out$prebaseline_death == 1L,
                c("id", "baseline_date", "death_date", "days",
                  "baseline_age", "female")]
write.csv(negative, negative_path, row.names = FALSE, na = "")
assert_true(nrow(negative) == 45L, "Negative detail rows == 45")

age_group <- cut(out$baseline_age, c(59, 79, 89, 99, Inf),
                 labels = c("60-79", "80-89", "90-99", "100+"))
sex_group <- factor(ifelse(out$female == 1L, "female", "male"),
                    levels = c("male", "female"))
group_summary <- function(group, name) {
  ans <- lapply(levels(group), function(g) {
    ix <- !is.na(group) & as.character(group) == g
    known <- ix & !is.na(out$event_4y)
    data.frame(group = g, baseline_n = sum(ix),
               outcome_known_n = sum(known),
               events_4y = sum(out$event_4y[known] == 1L),
               rate_known = sum(out$event_4y[known] == 1L) / sum(known))
  })
  ans <- do.call(rbind, ans)
  names(ans)[1] <- name
  ans
}
age_events <- group_summary(age_group, "age_group")
sex_events <- group_summary(sex_group, "sex")

loss_ix <- out$followup_status == "lost"
loss_age_group <- table(age_group[loss_ix], useNA = "ifany")
date_source_rows <- do.call(rbind, lapply(c("d14", "d18"), function(s) {
  ix <- death_source == s
  data.frame(
    source = s, deaths = sum(ix),
    valid_year = sum(!is.na(dat[[paste0(s, "vyear")]][ix])),
    valid_month = sum(!is.na(dat[[paste0(s, "vmonth")]][ix])),
    valid_day = sum(!is.na(dat[[paste0(s, "vday")]][ix])),
    constructed_date = sum(!is.na(death_date[ix])),
    missing_date = sum(is.na(death_date[ix]))
  )
}))

charls_path <- file.path(project_root, "data", "analysis",
                         "charls_outcome_2026-07-27.parquet")
charls_available <- FALSE
if (file.exists(charls_path)) {
  charls <- as.data.frame(arrow::read_parquet(charls_path), check.names = FALSE)
  charls_age_col <- intersect(c("baseline_age", "trueage", "age"), names(charls))[1]
  if (!is.na(charls_age_col)) {
    charls_age <- as.numeric(charls[[charls_age_col]])
    charls_age <- charls_age[!is.na(charls_age) & charls_age >= 60]
    if (length(charls_age)) {
      compare <- rbind(
        data.frame(cohort = "CLHLS", age = out$baseline_age[out$baseline_age >= 60]),
        data.frame(cohort = "CHARLS", age = charls_age)
      )
      ggplot2::ggsave(
        file.path(result_dir, "clhls_charls_age_comparison_v2.png"),
        ggplot2::ggplot(compare, ggplot2::aes(age, fill = cohort)) +
          ggplot2::geom_histogram(binwidth = 2, boundary = 60,
                                  position = "identity", alpha = 0.55) +
          ggplot2::labs(title = "Baseline age distribution: CLHLS vs CHARLS",
                        x = "Age", y = "Participants") +
          ggplot2::theme_minimal(base_size = 11),
        width = 10, height = 6, dpi = 160
      )
      charls_available <- TRUE
      log_msg("PASS", "CLHLS/CHARLS age comparison plot written")
    }
  }
}
if (!charls_available) log_msg("WARN", "CHARLS age comparison plot unavailable")

fmt_num <- function(x, d = 1) formatC(x, format = "f", digits = d, big.mark = ",")
fmt_pct <- function(x, n) sprintf("%.2f%%", 100 * x / n)
age60 <- out$baseline_age >= 60
age60_n <- sum(age60)
age60_events <- sum(out$event_4y[age60] == 1L, na.rm = TRUE)
known60_n <- sum(age60 & !is.na(out$event_4y))
loss_age_text <- paste(names(loss_age_group), as.integer(loss_age_group),
                       sep = "=", collapse = "; ")
negative_text <- capture.output(print(negative, row.names = FALSE))
report <- c(
  "# CLHLS 4-Year Mortality Outcome v2",
  "",
  "## Material Passport",
  "- Type: reproducible outcome construction and audit artifact",
  "- Status: VERIFIED after a successful R rerun and hard assertions",
  paste0("- Script: ", normalizePath("code/03_outcome/build_clhls_outcome_v2.R", winslash = "/")),
  paste0("- Output: ", normalizePath(output_path, winslash = "/")),
  paste0("- Log: ", normalizePath(log_path, winslash = "/")),
  "",
  "## v1 Deprecated, v2 Adopted",
  "- v1 assumed CLHLS had no death-date variables and used interval-censoring endpoints.",
  "- The validated fields d14vyear/month/day and d18vyear/month/day disprove that premise; v1 interval outputs are retained only as audit history.",
  "- v2 uses validated death dates and a 0-1,461 day window from each participant's baseline interview. Missing validated death days use day 15 per the v2 plan; interview dates are never substituted for death dates.",
  "",
  "## Sample Flow",
  paste0("- Raw N = ", fmt_num(nrow(out), 0), "."),
  paste0("- Death-status N = ", fmt_num(sum(died), 0), "; alive at 2018 = ",
         fmt_num(sum(out$followup_status == "alive_censored"), 0),
         "; lost = ", fmt_num(sum(loss_ix), 0), "."),
  paste0("- Constructed death dates = ", sum(!is.na(out$death_date)), " / ",
         sum(died), " (", fmt_pct(sum(!is.na(out$death_date)), sum(died)),
         "); post-baseline valid dates after 45 pre-baseline records = ",
         sum(!is.na(out$death_date) & !prebaseline_death), "."),
  paste0("- Pre-baseline deaths excluded from time analysis = ", sum(prebaseline_death), "."),
  paste0("- Baseline age >=60 N = ", age60_n,
         "; outcome-known age >=60 N = ", known60_n, "."),
  "",
  "## Outcome Counts",
  "- event_4y = 1 for a death at 0 through 1,461 days inclusive; death after day 1,461 is 0.",
  "- Confirmed alive at 2018 is 0 with time_4y = 1,461; lost or unconstructable death dates remain missing for the fixed-window outcome.",
  paste0("- All-sample events = ", sum(out$event_4y == 1L, na.rm = TRUE), "."),
  paste0("- Age >=60 events = ", age60_events, "; crude rate = ",
         age60_events, "/", age60_n, " = ", fmt_pct(age60_events, age60_n), "."),
  "",
  "Age strata:",
  capture.output(print(age_events, row.names = FALSE)),
  "",
  "Sex strata:",
  capture.output(print(sex_events, row.names = FALSE)),
  "",
  "## Death-Date Sources and Missingness",
  capture.output(print(date_source_rows, row.names = FALSE)),
  "- d14 is used for dth11_14 = 1; d18 is used for dth11_14 = 0 and dth14_18 = 1.",
  "- The released d14vday label says year, but the field is treated as the validated day based on its day-level values and codebook role.",
  "",
  "## Loss to Follow-Up",
  paste0("- Lost N = ", sum(loss_ix), " / ", nrow(out), " = ",
         fmt_pct(sum(loss_ix), nrow(out)), "."),
  paste0("- Lost baseline age mean = ", fmt_num(mean(out$baseline_age[loss_ix])),
         "; median = ", fmt_num(stats::median(out$baseline_age[loss_ix])), "."),
  paste0("- Lost female proportion = ",
         fmt_pct(sum(out$female[loss_ix] == 1L), sum(loss_ix)), "."),
  paste0("- Lost age strata = ", loss_age_text, "."),
  "- The 22.2% loss rate exceeds the project plan 20% planning value and needs a prespecified loss sensitivity analysis before modeling.",
  "",
  "## CLHLS and CHARLS Age Diagnostic",
  if (charls_available) "- Plot written: results/outcome_clhls/clhls_charls_age_comparison_v2.png." else "- CHARLS age comparison plot was unavailable because its age field was not found.",
  paste0("- CLHLS age >=60 median = ", fmt_num(stats::median(out$baseline_age[age60])),
         "; P25 = ", fmt_num(stats::quantile(out$baseline_age[age60], .25)),
         "; P75 = ", fmt_num(stats::quantile(out$baseline_age[age60], .75)), "."),
  "",
  "## Literature Benchmark Gate",
  paste0("- Observed CLHLS 60+ crude 4-year mortality = ", age60_events, "/",
         age60_n, " = ", fmt_pct(age60_events, age60_n), "."),
  "- The local literature-status and evidence files reviewed here do not contain a directly verified published CLHLS estimate using the same 60+ denominator, individual baseline dates, and 1,461-day window. A comparable literature benchmark remains unverified.",
  "",
  "## 45 Pre-Baseline Deaths",
  paste0("- Count = ", nrow(negative), "; these remain dead, but event_4y and time_4y are missing because death precedes baseline."),
  negative_text,
  "",
  "## Outputs and Constraints",
  paste0("- Parquet: ", normalizePath(output_path, winslash = "/")),
  paste0("- Negative-detail CSV: ", normalizePath(negative_path, winslash = "/")),
  paste0("- Log: ", normalizePath(log_path, winslash = "/")),
  "- Raw SAV was not modified.",
  "- Downstream FI modeling remains outside this task and requires review of outcome-known and loss handling.",
  "",
  "## Session",
  capture.output(sessionInfo())
)
writeLines(report, report_path, useBytes = TRUE)
log_msg("PASS", paste("Report written:", normalizePath(report_path, winslash = "/")))
flush_log()
message("CLHLS v2 outcome complete: ", normalizePath(output_path, winslash = "/"))

