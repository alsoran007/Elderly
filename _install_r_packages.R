options(repos = c(CRAN = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/"))
pkgs <- c("ranger", "xgboost", "timeROC", "dcurves", "pec", "riskRegression")

cat("=== R Package Installation Log ===\n")
cat("Start:", format(Sys.time()), "\n\n")

for (pkg in pkgs) {
  if (require(pkg, character.only=TRUE, quietly=TRUE)) {
    cat(sprintf("[SKIP] %s already installed\n", pkg))
    next
  }
  cat(sprintf("\n>>> Installing %s ...\n", pkg))
  tryCatch({
    install.packages(pkg, dependencies=TRUE, quiet=TRUE)
    cat(sprintf("[OK] %s installed\n", pkg))
  }, error = function(e) {
    cat(sprintf("[FAIL] %s: %s\n", pkg, e$message))
  })
}

cat("\n=== Final Status ===\n")
inst <- rownames(installed.packages())
for (pkg in pkgs) {
  status <- if (pkg %in% inst) paste0("OK v", packageVersion(pkg)) else "MISSING"
  cat(sprintf("%-18s %s\n", pkg, status))
}
cat("\nEnd:", format(Sys.time()), "\n")
