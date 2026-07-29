#!/usr/bin/env Rscript

root <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."), mustWork = TRUE)
path <- file.path(root, "results", "aim1", "aim1_performance_table_2026-07-29.csv")
tab <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
tab$CHARLS_internal[tab$metric == "edu_adjusted"] <- "FALSE"
tab$CLHLS_external[tab$metric == "edu_adjusted"] <- "FALSE"
write.csv(tab, path, row.names = FALSE, na = "NA", quote = TRUE)
cat("Normalized edu_adjusted to FALSE in:", path, "\n")
