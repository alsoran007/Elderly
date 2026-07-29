# Project3 Phase 1: probe mortality/exit files without modifying raw data.
# Run from D:/AI_project/project3 with Rscript scripts/02_outcome_file_probe.R.

options(stringsAsFactors = FALSE, warn = 1)

project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
raw_root <- normalizePath(file.path(project_root, "..", "sql"), winslash = "/", mustWork = TRUE)
out_root <- file.path(project_root, "results", "data_audit")
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

if (!requireNamespace("haven", quietly = TRUE)) stop("Package 'haven' is required.")

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || is.na(x[1]) || !nzchar(as.character(x[1]))) y else as.character(x[1])
}

read_data <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext == "dta") return(haven::read_dta(path, .name_repair = "minimal"))
  if (ext == "sav") return(haven::read_sav(path, .name_repair = "minimal"))
  stop("Unsupported file type: ", ext)
}

probe_target <- function(cohort, role, rel_path, format_note = "") {
  path <- file.path(raw_root, rel_path)
  if (!file.exists(path)) {
    return(list(summary = data.frame(cohort = cohort, role = role, rel_path = rel_path,
                                     exists = FALSE, read_status = "missing", rows = NA_integer_,
                                     columns = NA_integer_, candidate_id = NA_character_,
                                     duplicate_id = NA_integer_, stringsAsFactors = FALSE), fields = data.frame()))
  }

  dat <- tryCatch(read_data(path), error = function(e) e)
  if (inherits(dat, "error")) {
    return(list(summary = data.frame(cohort = cohort, role = role, rel_path = rel_path,
                                     exists = TRUE, read_status = "error", rows = NA_integer_,
                                     columns = NA_integer_, candidate_id = NA_character_,
                                     duplicate_id = NA_integer_, read_error = conditionMessage(dat),
                                     stringsAsFactors = FALSE), fields = data.frame()))
  }

  vars <- names(dat)
  labels <- vapply(dat, function(x) as.character(attr(x, "label") %||% ""), character(1))
  search_text <- paste(vars, labels)
  id_hit <- grepl(
    "(^|_|[[:space:]])(id|pid|hhid|mergeid|idauniq|rahhidnp|codent01)([[:space:]]|_|$)|unique individual serial|person identification|personal id|individual id|person identifier",
    search_text, ignore.case = TRUE
  )
  date_hit <- grepl(
    "death|dead|mort|dth|radyear|radmonth|raxyear|raxmonth|date.*death|death.*date|year.*death|death.*year|month.*death|death.*month|day.*death|death.*day|exit",
    search_text, ignore.case = TRUE
  )
  id_vars <- vars[id_hit]
  date_vars <- vars[date_hit]
  preferred_ids <- c("ID", "pid", "mergeid", "idauniq", "rahhidnp", "codent01", "hhid")
  preferred_hit <- preferred_ids[preferred_ids %in% id_vars]
  candidate_id <- if (length(preferred_hit)) preferred_hit[1] else if (length(id_vars)) id_vars[1] else NA_character_
  duplicate_id <- if (!is.na(candidate_id)) sum(duplicated(dat[[candidate_id]]) & !is.na(dat[[candidate_id]])) else NA_integer_

  field_rows <- lapply(c(id_vars, date_vars), function(v) {
    x <- dat[[v]]
    data.frame(
      cohort = cohort,
      role = role,
      rel_path = rel_path,
      variable = v,
      variable_label = labels[match(v, vars)],
      type = class(x)[1],
      nonmissing_n = sum(!is.na(x)),
      nonmissing_pct = round(mean(!is.na(x)) * 100, 2),
      unique_n = length(unique(x[!is.na(x)])),
      stringsAsFactors = FALSE
    )
  })

  summary <- data.frame(
    cohort = cohort,
    role = role,
    rel_path = rel_path,
    exists = TRUE,
    read_status = "ok",
    rows = nrow(dat),
    columns = ncol(dat),
    candidate_id = candidate_id,
    duplicate_id = duplicate_id,
    format_note = format_note,
    stringsAsFactors = FALSE
  )
  list(summary = summary, fields = if (length(field_rows)) do.call(rbind, field_rows) else data.frame())
}

targets <- rbind(
  data.frame(cohort = "CHARLS", role = "exit", rel_path = "Charls/2013/Exit_Interview.dta", stringsAsFactors = FALSE),
  data.frame(cohort = "CHARLS", role = "exit", rel_path = "Charls/2020/Exit_Module.dta", stringsAsFactors = FALSE),
  data.frame(cohort = "KLoSA", role = "exit", rel_path = "KLOSA/w03_exit_e.dta", stringsAsFactors = FALSE),
  data.frame(cohort = "KLoSA", role = "exit", rel_path = "KLOSA/w04_exit_e.dta", stringsAsFactors = FALSE),
  data.frame(cohort = "KLoSA", role = "exit", rel_path = "KLOSA/w05_exit_e.dta", stringsAsFactors = FALSE),
  data.frame(cohort = "KLoSA", role = "exit", rel_path = "KLOSA/w06_Exit_e.dta", stringsAsFactors = FALSE),
  data.frame(cohort = "KLoSA", role = "exit", rel_path = "KLOSA/2018 KLoSA 7 wave EXIT/w07_exit_e.dta", stringsAsFactors = FALSE),
  data.frame(cohort = "KLoSA", role = "exit", rel_path = "KLOSA/KLoSA 8th wave_EXIT/w08_exit_e.dta", stringsAsFactors = FALSE),
  data.frame(cohort = "KLoSA", role = "exit", rel_path = "KLOSA/KLoSA 9 wave Exit/Exit09_e.dta", stringsAsFactors = FALSE),
  data.frame(cohort = "SHARE", role = "end_of_life", rel_path = "share harmonised/GH_SHARE_EOL_g.dta", stringsAsFactors = FALSE),
  data.frame(cohort = "ELSA", role = "end_of_life", rel_path = "ELSA/stata/stata13_se/h_elsa_eol_a2.dta", stringsAsFactors = FALSE),
  data.frame(cohort = "MHAS", role = "end_of_life", rel_path = "MHAS/H_MHAS_EOL_b.dta", stringsAsFactors = FALSE)
)

results <- lapply(seq_len(nrow(targets)), function(i) {
  probe_target(targets$cohort[i], targets$role[i], targets$rel_path[i])
})
summary <- do.call(rbind, lapply(results, `[[`, "summary"))
fields <- do.call(rbind, lapply(results, `[[`, "fields"))

write.csv(summary, file.path(out_root, "outcome_file_probe.csv"), row.names = FALSE, na = "")
write.csv(fields, file.path(out_root, "outcome_candidate_fields.csv"), row.names = FALSE, na = "")

summary_lines <- c(
  "# Outcome File Probe",
  "",
  "This probe read selected exit/EOL files only. It did not modify raw data, merge cohorts, or define the final 5-year outcome.",
  "",
  paste0("- Files targeted: ", nrow(targets)),
  paste0("- Files read successfully: ", sum(summary$read_status == "ok")),
  paste0("- Files with read errors: ", sum(summary$read_status == "error")),
  paste0("- Files missing: ", sum(summary$read_status == "missing")),
  "",
  "The output field table records candidate IDs and death/exit/date variables with non-missing percentages. These candidates still require codebook confirmation before outcome construction.",
  "The final outcome requires a cohort-specific linkage table, baseline interview date, last-known-alive date, death date, administrative censoring date, and explicit handling of interval-censored deaths."
)
writeLines(summary_lines, file.path(out_root, "outcome_file_probe_summary.md"), useBytes = TRUE)

message("Outcome file probe completed. Outputs: ", normalizePath(out_root, winslash = "/"))
