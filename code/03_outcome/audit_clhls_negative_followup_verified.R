# Independent audit of CLHLS negative follow-up days.
options(stringsAsFactors = FALSE, warn = 1)

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
raw <- file.path(dirname(root), "sql", "CLHLS", "CLHLS_dataset_2008-2018_SPSS",
                 "clhls_2011_2018_longitudinal_dataset_released_version1.sav")
out_dir <- file.path(root, "results", "outcome_clhls")
log_dir <- file.path(root, "logs")
csv_path <- file.path(out_dir, "clhls_negative_followup_audit_2026-07-28.csv")
report_path <- file.path(out_dir, "clhls_negative_followup_audit_2026-07-28.md")
log_path <- file.path(log_dir, "clhls_negative_followup_audit_2026-07-28.log")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

log_lines <- character()
log <- function(level, msg) {
  z <- sprintf("[%s] %s %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), level, msg)
  log_lines <<- c(log_lines, z); message(z)
}
flush <- function() writeLines(log_lines, log_path, useBytes = TRUE)
stop_audit <- function(msg) { log("FAIL", msg); flush(); stop(msg, call. = FALSE) }
check <- function(ok, msg) if (isTRUE(ok)) log("PASS", msg) else stop_audit(msg)

if (!file.exists(raw)) stop_audit(paste("Missing SAV:", raw))
if (!requireNamespace("haven", quietly = TRUE) || !requireNamespace("tidyselect", quietly = TRUE)) {
  stop_audit("Missing package: haven or tidyselect")
}
fields <- c("id", "yearin", "monthin", "dayin", "trueage", "a1",
            "dth11_14", "d14vyear", "d14vmonth", "d14vday",
            "dth14_18", "d18vyear", "d18vmonth", "d18vday")
log("INFO", paste("Reading raw SAV:", raw))
x <- tryCatch(haven::read_sav(raw, col_select = tidyselect::all_of(fields),
                              .name_repair = "minimal"),
              error = function(e) stop_audit(conditionMessage(e)))
check(nrow(x) == 9765L, "Raw N == 9765")
check(setequal(names(x), fields), "Selected fields match contract")
x <- as.data.frame(lapply(x, as.numeric), check.names = FALSE)

# Match the v2 convention: missing day -> 15, supplied day -> 1-28.
parse_date <- function(y, m, d) {
  y <- as.integer(y); m <- as.integer(m); d <- as.integer(d)
  imputed <- !is.na(y) & !is.na(m) & is.na(d)
  used <- ifelse(is.na(d), 15L, pmin(pmax(d, 1L), 28L))
  adjusted <- !is.na(d) & d != used
  valid <- !is.na(y) & !is.na(m) & !is.na(used) & y >= 1900L &
    m >= 1L & m <= 12L & used >= 1L & used <= 28L
  txt <- rep(NA_character_, length(y))
  txt[valid] <- sprintf("%04d-%02d-%02d", y[valid], m[valid], used[valid])
  list(date = suppressWarnings(as.Date(txt)), used = used,
       imputed = imputed, adjusted = adjusted)
}
b <- parse_date(x$yearin, x$monthin, x$dayin)
d14 <- parse_date(x$d14vyear, x$d14vmonth, x$d14vday)
d18 <- parse_date(x$d18vyear, x$d18vmonth, x$d18vday)
check(sum(is.na(b$date)) == 0L, "Baseline dates are constructable")

source <- rep("none", nrow(x))
source[x$dth11_14 == 1] <- "d14"
source[x$dth11_14 == 0 & x$dth14_18 == 1] <- "d18"
check(sum(source == "d14") == 2879L, "d14 death status count == 2879")
check(sum(source == "d18") == 1837L, "d18 death status count == 1837")
check(sum(source != "none") == 4716L, "Death status total == 4716")

death <- as.Date(rep(NA_character_, nrow(x)))
year_raw <- month_raw <- day_raw <- used_day <- rep(NA_integer_, nrow(x))
day_imputed <- day_adjusted <- rep(FALSE, nrow(x))
i14 <- source == "d14"; i18 <- source == "d18"
death[i14] <- d14$date[i14]; death[i18] <- d18$date[i18]
year_raw[i14] <- x$d14vyear[i14]; year_raw[i18] <- x$d18vyear[i18]
month_raw[i14] <- x$d14vmonth[i14]; month_raw[i18] <- x$d18vmonth[i18]
day_raw[i14] <- x$d14vday[i14]; day_raw[i18] <- x$d18vday[i18]
used_day[i14] <- d14$used[i14]; used_day[i18] <- d18$used[i18]
day_imputed[i14] <- d14$imputed[i14]; day_imputed[i18] <- d18$imputed[i18]
day_adjusted[i14] <- d14$adjusted[i14]; day_adjusted[i18] <- d18$adjusted[i18]
days <- as.numeric(death - b$date)
constructed <- source != "none" & !is.na(death)
negative <- source != "none" & !is.na(days) & days < 0
check(sum(constructed) == 4650L, "Constructed death dates == 4650")
check(sum(negative) == 45L, "Direct negative follow-up count == 45")

id <- format(x$id, scientific = FALSE, trim = TRUE)
audit <- data.frame(
  id = id[negative], dth11_14 = x$dth11_14[negative],
  dth14_18 = x$dth14_18[negative], death_source = source[negative],
  baseline_year_raw = x$yearin[negative], baseline_month_raw = x$monthin[negative],
  baseline_day_raw = x$dayin[negative], baseline_day_used = b$used[negative],
  baseline_day_imputed = b$imputed[negative], baseline_date = as.character(b$date[negative]),
  death_year_raw = year_raw[negative], death_month_raw = month_raw[negative],
  death_day_raw = day_raw[negative], death_day_used = used_day[negative],
  death_day_imputed = day_imputed[negative], death_day_adjusted = day_adjusted[negative],
  death_date = as.character(death[negative]), days = days[negative],
  baseline_age = x$trueage[negative], female = as.integer(x$a1[negative] == 2),
  stringsAsFactors = FALSE)
audit <- audit[order(audit$days, audit$id), ]
write.csv(audit, csv_path, row.names = FALSE, na = "")
check(nrow(audit) == 45L, "Audit CSV rows == 45")

prior_match <- NA
prior_path <- file.path(out_dir, "clhls_prebaseline_deaths_v2_2026-07-28.csv")
if (file.exists(prior_path)) {
  prior <- read.csv(prior_path, stringsAsFactors = FALSE, check.names = FALSE)
  prior$key <- as.character(prior$id); audit$key <- as.character(audit$id)
  prior_match <- nrow(prior) == nrow(audit) && setequal(prior$key, audit$key) &&
    all(prior$days[match(audit$key, prior$key)] == audit$days)
  audit$key <- NULL
  check(prior_match, "Independent audit matches prior v2 negative-detail CSV")
}

q <- quantile(audit$days, c(.25, .5, .75), names = FALSE)
src <- table(audit$death_source)
base_imp <- sum(audit$baseline_day_imputed)
death_imp <- sum(audit$death_day_imputed)
death_adj <- sum(audit$death_day_adjusted)
log("INFO", paste("Negative range:", min(audit$days), "to", max(audit$days), "days"))
log("INFO", paste("Negative records with imputed baseline day:", base_imp))
log("INFO", paste("Negative records with imputed death day:", death_imp))
log("INFO", paste("Negative records with adjusted death day:", death_adj))

report <- c(
  "# CLHLS Negative Follow-up Days Audit", "", "## Material Passport",
  "- Type: independent raw-field audit of follow-up-day sign",
  "- Status: VERIFIED after raw SAV reread and hard assertions",
  paste0("- Script: ", normalizePath("code/03_outcome/audit_clhls_negative_followup_verified.R", winslash = "/")),
  paste0("- Raw input: ", normalizePath(raw, winslash = "/")),
  paste0("- Detail output: ", normalizePath(csv_path, winslash = "/")),
  paste0("- Log: ", normalizePath(log_path, winslash = "/")), "- Raw SAV modified: no.", "",
  "## Definition Audited",
  "`days = validated_death_date - individual_baseline_date`; negative means `days < 0`.",
  "Death dates use d14 validated fields for `dth11_14 == 1` and d18 validated fields for `dth11_14 == 0 & dth14_18 == 1`.",
  "The v2 convention imputes missing day as 15 and constrains supplied day values to 1-28; both operations are recorded in the CSV.", "",
  "## Findings", paste0("- Raw records: ", nrow(x), "."),
  paste0("- Death-status records: ", sum(source != "none"), "."),
  paste0("- Constructed validated death dates: ", sum(constructed), "."),
  paste0("- Direct negative follow-up records: **", sum(negative), "**."),
  paste0("- Negative-day range: ", min(audit$days), " to ", max(audit$days), " days."),
  paste0("- Negative-day quartiles (P25 / median / P75): ", paste(q, collapse = " / "), "."),
  paste0("- Death source: d14=", ifelse("d14" %in% names(src), src[["d14"]], 0), "; d18=", ifelse("d18" %in% names(src), src[["d18"]], 0), "."),
  paste0("- Negative records with imputed baseline day: ", base_imp, "."),
  paste0("- Negative records with imputed death day: ", death_imp, "."),
  paste0("- Negative records with adjusted death day (v2 1-28 constraint): ", death_adj, "."), "",
  "## Cross-check",
  paste0("- Prior v2 detail CSV matches independent audit: ", ifelse(is.na(prior_match), "not run", prior_match), "."), "",
  "## Decision Gate",
  "The raw-field audit supports 45 direct negative follow-up records under the stated definition.",
  "D-019's 0-record statement is inconsistent with this raw reread and the v2 detail CSV; keep it unresolved pending Claude/PI review.",
  "This audit does not choose whether to exclude, recode, or reinterpret the records, and it does not edit D-019 or the v2 outcome plan.")
writeLines(report, report_path, useBytes = TRUE)
log("PASS", paste("Wrote report:", report_path))
flush()
