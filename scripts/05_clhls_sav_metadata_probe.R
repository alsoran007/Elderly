# Project3 Phase 1: CLHLS SPSS metadata probe.
# Metadata-only read; no raw data modification or recoding.

options(stringsAsFactors = FALSE, warn = 1)

project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
raw_root <- normalizePath(file.path(project_root, "..", "sql"), winslash = "/", mustWork = TRUE)
clhls_root <- file.path(raw_root, "CLHLS")
out_root <- file.path(project_root, "results", "data_audit")
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

if (!requireNamespace("haven", quietly = TRUE)) stop("Package 'haven' is required.")

sav_paths <- list.files(clhls_root, pattern = "\\.sav$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
schema_rows <- list()
summary_rows <- list()
schema_i <- 0L

candidate_pattern <- paste(
  "id|pid|hhid|person|respond|identifier|death|dead|dth|mort|surviv|",
  "date|year|month|day|age|birth|interview|wave|follow|exit|status",
  sep = ""
)

for (path in sav_paths) {
  rel <- sub("^/", "", substring(normalizePath(path, winslash = "/"), nchar(raw_root) + 2L))
  meta <- tryCatch(haven::read_sav(path, n_max = 0, .name_repair = "minimal"), error = function(e) e)
  if (inherits(meta, "error")) {
    summary_rows[[length(summary_rows) + 1L]] <- data.frame(
      source_file = rel, read_status = "error", rows = NA_integer_, columns = NA_integer_,
      candidate_fields = NA_integer_, read_error = conditionMessage(meta), stringsAsFactors = FALSE
    )
    next
  }
  vars <- names(meta)
  labels <- vapply(meta, function(x) {
    lab <- attr(x, "label")
    if (is.null(lab) || length(lab) == 0) "" else as.character(lab[1])
  }, character(1))
  hit <- grepl(candidate_pattern, paste(vars, labels), ignore.case = TRUE)
  hit_idx <- which(hit)
  for (j in hit_idx) {
    schema_i <- schema_i + 1L
    schema_rows[[schema_i]] <- data.frame(
      source_file = rel,
      variable = vars[j],
      variable_label = labels[j],
      storage_class = class(meta[[j]])[1],
      stringsAsFactors = FALSE
    )
  }
  summary_rows[[length(summary_rows) + 1L]] <- data.frame(
    source_file = rel, read_status = "metadata_ok", rows = NA_integer_, columns = ncol(meta),
    candidate_fields = length(hit_idx), read_error = "", stringsAsFactors = FALSE
  )
}

schema <- if (length(schema_rows)) do.call(rbind, schema_rows) else data.frame()
summary <- if (length(summary_rows)) do.call(rbind, summary_rows) else data.frame()
write.csv(schema, file.path(out_root, "clhls_sav_schema_candidates.csv"), row.names = FALSE, na = "")
write.csv(summary, file.path(out_root, "clhls_sav_metadata_summary.csv"), row.names = FALSE, na = "")

lines <- c(
  "# CLHLS SPSS Metadata Probe",
  "",
  "The probe used haven metadata-only reads. It did not alter the SPSS files or construct outcomes.",
  "",
  paste0("- SPSS files found: ", length(sav_paths)),
  paste0("- Metadata reads successful: ", sum(summary$read_status == "metadata_ok")),
  paste0("- Metadata reads with errors: ", sum(summary$read_status == "error")),
  paste0("- Candidate fields exported: ", nrow(schema)),
  "",
  "The candidate list requires codebook confirmation before any recoding. Death date/status, interview date, and birth date are deliberately not conflated."
)
writeLines(lines, file.path(out_root, "clhls_sav_metadata_probe_summary.md"), useBytes = TRUE)
message("CLHLS SPSS metadata probe completed. Outputs: ", normalizePath(out_root, winslash = "/"))
