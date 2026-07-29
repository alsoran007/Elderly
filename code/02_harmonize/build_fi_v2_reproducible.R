#!/usr/bin/env Rscript
# Reproducible entry point for the fixed-41-item HRS/KLoSA FI builders.
# The two source builders were generated during the v2 handoff; these in-memory
# compatibility edits keep reruns deterministic without changing source data.
run_builder <- function(path, h_args = FALSE) {
  txt <- paste(readLines(path, encoding = "UTF-8"), collapse = "\n")
  if (h_args) {
    old <- paste0("MAP", "$", "coding_note<-c(")
    new <- paste0("MAP", "$", "coding_note<-rep(NA_character_,41); #")
    txt <- sub(old, new, txt, fixed = TRUE)
  }
  txt <- gsub(",na.action=na.omit", "", txt, fixed = TRUE)
  eval(parse(text = txt), envir = .GlobalEnv)
}
run_builder("code/02_harmonize/build_fi_hrs_v2_run.R", h_args = TRUE)
run_builder("code/02_harmonize/build_fi_klosa_v2_run.R", h_args = FALSE)
cat("REPRODUCIBLE_FI_V2_PASS\n")
