# Project3 Phase 1: read-only audit of longitudinal aging-cohort inputs.
# Run from D:/AI_project/project3 with Rscript scripts/01_data_audit.R.

options(stringsAsFactors = FALSE, warn = 1)

project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
raw_root <- normalizePath(file.path(project_root, "..", "sql"), winslash = "/", mustWork = TRUE)
out_root <- file.path(project_root, "results", "data_audit")
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

required_packages <- c("haven")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  stop("Missing required R package(s): ", paste(missing_packages, collapse = ", "))
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || is.na(x[1]) || !nzchar(as.character(x[1]))) y else as.character(x[1])
}

target <- function(cohort, role, rel_path, format, key = FALSE, note = "") {
  data.frame(
    cohort = cohort,
    role = role,
    rel_path = rel_path,
    format = format,
    key_schema_file = key,
    note = note,
    stringsAsFactors = FALSE
  )
}

targets <- rbind(
  target("CHARLS", "harmonization_script", "Charls/bbxleyec.do", "do", TRUE, "Gateway Harmonized CHARLS generator"),
  target("CHARLS", "harmonization_document", "Charls/Harmonized_CHARLS_D.pdf", "pdf", FALSE, "Harmonization definitions"),
  target("KLoSA", "harmonization_script", "KLOSA/bukpmcwp.do", "do", TRUE, "Gateway Harmonized KLoSA generator"),
  target("KLoSA", "exit_wave9", "KLOSA/KLoSA 9 wave Exit/Exit09_e.dta", "dta", TRUE, "Wave 9 exit/mortality file"),
  target("CLHLS", "codebook_directory", "CLHLS/CLHLS_codebook 1998-2018", "directory", FALSE, "Longitudinal codebooks"),
  target("CHARLS", "raw_wave", file.path("Charls", list.files(file.path(raw_root, "Charls"), pattern = "\\.dta$", recursive = TRUE, full.names = FALSE)), "dta", TRUE),
  target("KLoSA", "raw_wave_or_exit", file.path("KLOSA", list.files(file.path(raw_root, "KLOSA"), pattern = "\\.(dta|sav)$", recursive = TRUE, full.names = FALSE)), "mixed", TRUE),
  target("CLHLS", "raw_longitudinal", file.path("CLHLS", list.files(file.path(raw_root, "CLHLS"), pattern = "\\.sav$", recursive = TRUE, full.names = FALSE)), "sav", TRUE),
  target("SHARE", "harmonized", "share harmonised/GH_SHARE_g.dta", "dta", TRUE),
  target("SHARE", "end_of_life", "share harmonised/GH_SHARE_EOL_g.dta", "dta", TRUE),
  target("HRS", "harmonized", "HRS Products/harmonised HRS/H_HRS_d.dta", "dta", TRUE),
  target("ELSA", "harmonized", "ELSA/stata/stata13_se/h_elsa_g3.dta", "dta", TRUE),
  target("ELSA", "end_of_life", "ELSA/stata/stata13_se/h_elsa_eol_a2.dta", "dta", TRUE),
  target("MHAS", "harmonized", "MHAS/H_MHAS_c2.dta", "dta", TRUE),
  target("MHAS", "end_of_life", "MHAS/H_MHAS_EOL_b.dta", "dta", TRUE)
)

# Expand vector-valued target paths into one row per file.
expanded <- do.call(rbind, lapply(seq_len(nrow(targets)), function(i) {
  paths <- targets$rel_path[[i]]
  do.call(rbind, lapply(paths, function(p) {
    x <- targets[i, , drop = FALSE]
    x$rel_path <- p
    if (identical(x$format, "mixed")) x$format <- tolower(tools::file_ext(p))
    x
  }))
}))
rownames(expanded) <- NULL

expanded$abs_path <- file.path(raw_root, expanded$rel_path)
expanded$exists <- file.exists(expanded$abs_path)
expanded$size_mb <- ifelse(expanded$exists, round(file.info(expanded$abs_path)$size / 1024^2, 3), NA_real_)
expanded$modified <- ifelse(expanded$exists, as.character(file.info(expanded$abs_path)$mtime), NA_character_)
expanded$read_status <- "not_attempted"
expanded$rows <- NA_integer_
expanded$columns <- NA_integer_
expanded$read_error <- NA_character_

read_metadata <- function(path, format) {
  if (format == "dta") return(haven::read_dta(path, n_max = 0, .name_repair = "minimal"))
  if (format == "sav") return(haven::read_sav(path, n_max = 0, .name_repair = "minimal"))
  stop("Unsupported data format: ", format)
}

schema_rows <- list()
schema_i <- 0L
schema_pattern <- paste(
  "id|pid|hhid|household|couple|respond|person|death|dead|mort|dth|exit|",
  "attrit|follow|surviv|status|date|year|month|weight|wt|psu|strat|",
  "proxy|age|gender|sex|educ|adla|iadl|health|cogn|frail|intrinsic|capacity",
  sep = ""
)

key_rows <- which(expanded$exists & expanded$key_schema_file & expanded$format %in% c("dta", "sav"))
for (i in key_rows) {
  path <- expanded$abs_path[i]
  fmt <- expanded$format[i]
  meta <- tryCatch(read_metadata(path, fmt), error = function(e) e)
  if (inherits(meta, "error")) {
    expanded$read_status[i] <- "error"
    expanded$read_error[i] <- conditionMessage(meta)
    next
  }

  expanded$read_status[i] <- "metadata_ok"
  expanded$rows[i] <- 0L
  expanded$columns[i] <- ncol(meta)
  vars <- names(meta)
  labels <- vapply(meta, function(x) attr(x, "label") %||% "", character(1))
  hit <- grepl(schema_pattern, paste(vars, labels), ignore.case = TRUE)
  if (any(hit)) {
    for (j in which(hit)) {
      schema_i <- schema_i + 1L
      schema_rows[[schema_i]] <- data.frame(
        cohort = expanded$cohort[i],
        role = expanded$role[i],
        rel_path = expanded$rel_path[i],
        variable = vars[j],
        variable_label = labels[j],
        storage_class = class(meta[[j]])[1],
        stringsAsFactors = FALSE
      )
    }
  }
}

schema <- if (length(schema_rows)) do.call(rbind, schema_rows) else data.frame()

script_rows <- do.call(rbind, lapply(c("Charls/bbxleyec.do", "KLOSA/bukpmcwp.do"), function(rel) {
  path <- file.path(raw_root, rel)
  bytes <- if (file.exists(path)) readBin(path, what = "raw", n = file.info(path)$size) else raw(0)
  txt <- if (length(bytes)) iconv(rawToChar(bytes), from = "latin1", to = "UTF-8", sub = "") else ""
  data.frame(
    script = rel,
    exists = file.exists(path),
    has_path_placeholders = grepl("\\|\\|[^|]+\\|\\|", txt),
    has_save_command = grepl("\\b(save|saveold|export)\\b", txt, perl = TRUE),
    lines = if (length(bytes)) sum(bytes == as.raw(10)) + 1L else NA_integer_,
    stringsAsFactors = FALSE
  )
}))

write.csv(expanded, file.path(out_root, "file_inventory.csv"), row.names = FALSE, na = "")
write.csv(schema, file.path(out_root, "schema_candidates.csv"), row.names = FALSE, na = "")
write.csv(script_rows, file.path(out_root, "harmonization_script_preflight.csv"), row.names = FALSE, na = "")

missing_rows <- expanded[!expanded$exists, c("cohort", "role", "rel_path", "note")]
write.csv(missing_rows, file.path(out_root, "missing_expected_inputs.csv"), row.names = FALSE, na = "")

summary_lines <- c(
  "# Project3 Phase 1 Data Audit",
  "",
  paste0("- Project root: `", project_root, "`"),
  paste0("- Raw root: `", raw_root, "`"),
  paste0("- Target records: ", nrow(expanded)),
  paste0("- Existing target records: ", sum(expanded$exists)),
  paste0("- Missing target records: ", sum(!expanded$exists)),
  paste0("- Metadata reads attempted: ", length(key_rows)),
  paste0("- Metadata reads successful: ", sum(expanded$read_status == "metadata_ok")),
  paste0("- Metadata read errors: ", sum(expanded$read_status == "error")),
  paste0("- Candidate schema fields exported: ", nrow(schema)),
  "",
  "## Interpretation",
  "",
  "This audit is read-only. It does not run the harmonization scripts or modify raw files.",
  "Rows reported as metadata_ok confirm that the file can be opened and its variable metadata can be inspected; they do not yet confirm valid ID linkage, death coding, event counts, or FI/IC availability.",
  "The next gate is to inspect the candidate fields and codebooks, then build cohort-specific outcome and harmonization crosswalks.",
  "",
  "## Output files",
  "",
  "- `file_inventory.csv`: expected inputs, existence, size, and metadata read status.",
  "- `schema_candidates.csv`: candidate ID, follow-up, mortality, weight, and phenotype fields.",
  "- `harmonization_script_preflight.csv`: script existence and unresolved path placeholders.",
  "- `missing_expected_inputs.csv`: expected files not found during this audit."
)
writeLines(summary_lines, file.path(out_root, "data_audit_summary.md"), useBytes = TRUE)

message("Data audit completed. Outputs: ", normalizePath(out_root, winslash = "/"))
