#!/usr/bin/env Rscript
# Read-only KLoSA wave-4 FI mapping audit. No FI or outcome is constructed.

suppressPackageStartupMessages(library(haven))

project_root <- "D:/AI_project/project3"
raw_root <- "D:/AI_project/sql/KLOSA"
stamp <- "2026-07-28"
result_dir <- file.path(project_root, "results/fi_klosa")
log_dir <- file.path(project_root, "logs")
dir.create(result_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
log_path <- file.path(log_dir, paste0("audit_klosa_fi_wave4_", stamp, ".log"))
log_con <- file(log_path, open = "wt", encoding = "UTF-8")
sink(log_con, type = "output")
sink(log_con, type = "message")
on.exit({sink(type = "message"); sink(type = "output"); close(log_con)}, add = TRUE)

files <- list.files(raw_root, recursive = TRUE, pattern = "^w04_e\\.dta$", full.names = TRUE)
stopifnot(length(files) == 1L)
raw_path <- files[[1L]]

fi_stems <- c(
  "hibpe", "diabe", "cancre", "lunge", "hearte", "stroke", "psyche", "arthre",
  "dyslipe", "livere", "kidneye", "digeste", "asthmae", "dressa", "batha",
  "eata", "beda", "toilta", "urina", "housewka", "mealsa", "shopa", "moneya",
  "medsa", "walk100a", "walk1kma", "joga", "climsa", "chaira", "stoopa", "armsa",
  "lifta", "dimea", "dsight", "nsight", "hearing", "shlt", "painfr", "fall",
  "slfmem", "mbmi"
)

mapping <- data.frame(
  stem = fi_stems,
  domain = NA_character_,
  source_vars = NA_character_,
  status = NA_character_,
  coding_note = NA_character_,
  review_note = NA_character_,
  stringsAsFactors = FALSE
)
set_map <- function(stem, domain, source_vars, status, coding_note, review_note = "") {
  i <- match(stem, mapping$stem)
  mapping[i, c("domain", "source_vars", "status", "coding_note", "review_note")] <<- list(
    domain, source_vars, status, coding_note, review_note
  )
}

set_map("hibpe", "comorbidity", "w04C006", "verified_candidate", "1=yes; 5=no; -8/-9 missing")
set_map("diabe", "comorbidity", "w04C011", "verified_candidate", "1=yes; 5=no; -8/-9 missing")
set_map("cancre", "comorbidity", "w04C016", "verified_candidate", "1=yes; 5=no; -8/-9 missing")
set_map("lunge", "comorbidity", "w04C023", "verified_candidate", "1=yes; 5=no; -8/-9 missing")
set_map("livere", "comorbidity", "w04C028", "verified_candidate", "1=yes; 5=no; -8/-9 missing")
set_map("hearte", "comorbidity", "w04C033", "verified_candidate", "1=yes; 5=no; -8/-9 missing")
set_map("stroke", "comorbidity", "w04C038", "semantic_review", "1=yes; 5=no; -8 missing", "Code 3 is suspected stroke/TIA and must be decided before FI construction")
set_map("psyche", "comorbidity", "w04C043", "verified_candidate", "1=yes; 5=no; -8/-9 missing")
set_map("arthre", "comorbidity", "w04C048", "verified_candidate", "1=yes; 5=no; -8/-9 missing")
set_map("dyslipe", "comorbidity", "", "not_found", "No direct dyslipidemia/lipid diagnosis label found")
set_map("kidneye", "comorbidity", "", "not_found", "w04C004m06 is kidney dysfunction disability, not a general kidney disease diagnosis")
set_map("digeste", "comorbidity", "", "not_found", "No direct digestive/stomach diagnosis label found")
set_map("asthmae", "comorbidity", "", "not_found", "No direct asthma diagnosis label found; chronic lung disease is mapped separately")

set_map("dressa", "adl", "w04C201", "verified_candidate", "1=no help; 3=some help; 5=full help")
set_map("batha", "adl", "w04C203", "verified_candidate", "1=no help; 3=some help; 5=full help")
set_map("eata", "adl", "w04C204", "verified_candidate", "1=no help; 3=some help; 5=full help")
set_map("beda", "adl", "w04C205", "verified_candidate", "1=no help; 3=some help; 5=full help")
set_map("toilta", "adl", "w04C206", "verified_candidate", "1=no help; 3=some help; 5=full help")
set_map("urina", "adl", "w04C068", "verified_candidate", "1=yes; 5=no; past-year urinary incontinence")
set_map("housewka", "iadl", "w04C209", "verified_candidate", "1=no help; 3=some help; 5=full help")
set_map("mealsa", "iadl", "w04C210", "verified_candidate", "1=no help; 3=some help; 5=full help")
set_map("shopa", "iadl", "w04C214", "verified_candidate", "1=no help; 3=some help; 5=full help")
set_map("moneya", "iadl", "w04C215", "verified_candidate", "1=no help; 3=some help; 5=full help")
set_map("medsa", "iadl", "w04C217", "verified_candidate", "1=no help; 3=some help; 5=full help")

for (stem in c("walk100a", "walk1kma", "joga", "climsa", "chaira", "stoopa", "armsa", "lifta", "dimea")) {
  set_map(stem, "mobility", "", "not_found", "No direct population-level mobility performance item found in wave-4 labels", "Job-demand fields are not valid substitutes")
}

set_map("dsight", "sensory", "w04C075", "verified_candidate", "1=very good to 5=very bad")
set_map("nsight", "sensory", "w04C076", "verified_candidate", "Far-vision rating; 1=very good to 5=very bad")
set_map("hearing", "sensory", "w04C083", "verified_candidate", "1=very good to 5=very bad")
set_map("shlt", "general", "w04C001", "verified_candidate", "1=excellent to 5=poor")
set_map("painfr", "general", "w04C102", "semantic_review", "1=daily activity difficulty from body pain; 5=no", "This is pain-related activity difficulty, not a direct chronic-pain frequency item")
set_map("fall", "general", "w04C056", "verified_candidate", "1=yes; 5=no; fall injury in latest 2 years")
set_map("slfmem", "cognition", "", "not_found", "No direct self-rated memory label found in wave-4 file")
set_map("mbmi", "general", "w04C105;w04C107", "derived_candidate", "Weight kg and height cm; BMI=weight/(height/100)^2", "Apply source missing-code and plausibility checks before BMI deficit")

all_source <- unique(unlist(strsplit(mapping$source_vars[mapping$source_vars != ""], ";", fixed = TRUE)))
all_source <- all_source[all_source %in% names(read_dta(raw_path, n_max = 0))]
d <- read_dta(raw_path, col_select = unique(c("w04A002_age", all_source)))
clean_num <- function(x) {
  z <- suppressWarnings(as.numeric(x))
  z[z %in% c(-8, -9)] <- NA_real_
  z
}

mapping$n_source_complete <- NA_integer_
mapping$n_age60_source_complete <- NA_integer_
for (i in seq_len(nrow(mapping))) {
  vars <- unlist(strsplit(mapping$source_vars[i], ";", fixed = TRUE))
  vars <- vars[nzchar(vars) & vars %in% names(d)]
  if (!length(vars)) next
  z <- lapply(vars, function(v) clean_num(d[[v]]))
  complete <- Reduce(`&`, lapply(z, function(x) !is.na(x)))
  mapping$n_source_complete[i] <- sum(complete)
  mapping$n_age60_source_complete[i] <- sum(complete & clean_num(d$w04A002_age) >= 60, na.rm = TRUE)
}

age <- clean_num(d$w04A002_age)
cat("raw file:", raw_path, "\n")
cat("rows:", nrow(d), "\n")
cat("age 60+:", sum(age >= 60, na.rm = TRUE), "\n")
cat("verified candidate stems:", sum(mapping$status %in% c("verified_candidate", "derived_candidate")), "\n")
cat("not found stems:", sum(mapping$status == "not_found"), "\n")
cat("semantic review stems:", sum(mapping$status == "semantic_review"), "\n")
print(mapping[, c("stem", "source_vars", "status", "n_source_complete")], row.names = FALSE)

mapping_path <- file.path(result_dir, paste0("klosa_w04_fi_mapping_", stamp, ".csv"))
write.csv(mapping, mapping_path, row.names = FALSE, na = "")

report_lines <- c(
  paste0("# KLoSA Wave-4 FI Mapping Audit (", stamp, ")"), "",
  "Raw KLoSA data were read only. No FI, outcome, or raw data file was modified.", "",
  paste0("- Input: `", raw_path, "`"),
  paste0("- Rows: ", nrow(d)),
  paste0("- Age 60+ (w04A002_age): ", sum(age >= 60, na.rm = TRUE)),
  paste0("- Candidate/derived stems: ", sum(mapping$status %in% c("verified_candidate", "derived_candidate"))),
  paste0("- Not found: ", sum(mapping$status == "not_found")),
  paste0("- Semantic review required: ", sum(mapping$status == "semantic_review")), "",
  "## Blocking Findings", "",
  "- Nine mobility stems have no direct population-level performance item in the wave-4 labels; job-demand variables must not be substituted.",
  "- `dyslipe`, `digeste`, `asthmae`, and `slfmem` have no direct wave-4 label match.",
  "- `kidneye` is not assigned to `w04C004m06` because that field is kidney dysfunction disability, not a general kidney disease diagnosis.",
  "- `stroke` code 3 means suspected stroke or transient ischemic attack and requires an explicit inclusion decision.",
  "- `painfr` is activity difficulty from body pain, not a direct chronic-pain frequency measure.",
  "", "## Output", "",
  paste0("- Mapping table: `", mapping_path, "`"),
  paste0("- Log: `", log_path, "`")
)
report_path <- file.path(result_dir, paste0("klosa_w04_fi_mapping_report_", stamp, ".md"))
writeLines(report_lines, report_path, useBytes = TRUE)
cat("mapping:", mapping_path, "\n")
cat("report:", report_path, "\n")
cat("PASS\n")
