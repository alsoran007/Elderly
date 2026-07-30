#!/usr/bin/env Rscript
# =============================================================================
# Figure 2: FI distribution across six cohorts (60+ subsets)
# Violin + boxplot overlay; development cohorts (blue) vs validation (orange)
# Paper 1 · 2026-07-30
#
# Run from project root:
#   Rscript --vanilla code/05_figures/plot_fig2_fi_distribution_2026-07-30.R
# =============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(ggplot2)
})

args <- commandArgs(FALSE)
farg <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(farg)) dirname(normalizePath(sub("^--file=", "", farg[1]))) else getwd()
root     <- normalizePath(file.path(script_dir, "..", ".."), mustWork = TRUE)
data_dir <- file.path(root, "data", "analysis")
OUTDIR   <- file.path(root, "results", "figures")
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)
stamp <- "2026-07-30"

# ── 1. Official FI files (per decision D-027) ─────────────────────────────────
# NOTE: MHAS uses the 2026-07-28 version (cohort-specific 80% threshold);
#       the 2026-07-29 version was abandoned (fixed threshold 33 excluded nearly all).
files <- c(
  CHARLS = "charls_fi_2011_2026-07-27.parquet",
  CLHLS  = "clhls_fi_2011_2026-07-29.parquet",
  KLoSA  = "klosa_fi_2012_2026-07-29.parquet",
  HRS    = "hrs_fi_2012_2026-07-29.parquet",
  SHARE  = "share_fi_2011_2026-07-29.parquet",
  MHAS   = "mhas_fi_2012_2026-07-28.parquet"
)

# Event rates (from Table 1; used in facet strip labels)
event_rate <- c(CHARLS = 10.2, CLHLS = 46.3, KLoSA = 9.6,
                HRS = 20.0, SHARE = 8.7, MHAS = 10.2)

# ── 2. Read + pool 60+ FI-eligible participants ───────────────────────────────
read_fi <- function(nm, fn) {
  p <- file.path(data_dir, fn)
  if (!file.exists(p)) stop("Missing FI file: ", p)
  d <- as.data.frame(read_parquet(p))
  if (!"fi_full" %in% names(d)) stop(nm, ": no fi_full column")

  # Age column varies slightly by cohort; take the first match
  age_col <- intersect(c("age", "r3agey", "r4agey"), names(d))[1]
  if (is.na(age_col)) stop(nm, ": no age column found")

  d$.age <- suppressWarnings(as.numeric(d[[age_col]]))

  # Eligibility flag: prefer explicit fi_excluded, else non-missing FI
  if ("fi_excluded" %in% names(d)) {
    d <- d[!is.na(d$fi_excluded) & !d$fi_excluded, , drop = FALSE]
  }

  out <- d |>
    filter(!is.na(.age), .age >= 60, !is.na(fi_full),
           fi_full >= 0, fi_full <= 1) |>
    transmute(cohort = nm, fi = as.numeric(fi_full))

  cat(sprintf("  %-7s n=%6d  median=%.3f  max=%.3f\n",
              nm, nrow(out), median(out$fi), max(out$fi)))
  out
}

cat("Reading FI files (60+ eligible):\n")
fi_all <- bind_rows(Map(read_fi, names(files), files))

# ── 3. Cohort ordering + labels ───────────────────────────────────────────────
cohort_order <- c("CHARLS", "CLHLS", "KLoSA", "HRS", "SHARE", "MHAS")

med_tbl <- fi_all |>
  group_by(cohort) |>
  summarise(med = median(fi), n = n(), .groups = "drop")

lab_map <- setNames(
  sprintf("%s\n(n=%s, %.1f%% events)",
          med_tbl$cohort[match(cohort_order, med_tbl$cohort)],
          format(med_tbl$n[match(cohort_order, med_tbl$cohort)],
                 big.mark = ",", trim = TRUE),
          event_rate[cohort_order]),
  cohort_order
)

fi_all$cohort <- factor(fi_all$cohort, levels = cohort_order,
                        labels = lab_map[cohort_order])
med_tbl$cohort_f <- factor(med_tbl$cohort, levels = cohort_order,
                           labels = lab_map[cohort_order])

# Role grouping for colour
role <- c(CHARLS = "Development / Asian pool", CLHLS = "Development / Asian pool",
          KLoSA = "Development / Asian pool", HRS = "External validation",
          SHARE = "External validation", MHAS = "External validation")
fi_all$role <- factor(role[sub("\n.*", "", as.character(fi_all$cohort))],
                      levels = c("Development / Asian pool", "External validation"))

pal <- c("Development / Asian pool" = "#2166AC",
         "External validation"      = "#D94801")

# ── 4. Plot ───────────────────────────────────────────────────────────────────
p <- ggplot(fi_all, aes(x = cohort, y = fi, fill = role, colour = role)) +
  geom_violin(alpha = 0.35, width = 0.85, linewidth = 0.4,
              trim = TRUE, scale = "width") +
  geom_boxplot(width = 0.13, outlier.shape = NA, alpha = 0.95,
               linewidth = 0.4, colour = "grey20", fill = "white") +
  geom_text(data = med_tbl,
            aes(x = cohort_f, y = med, label = sprintf("%.3f", med)),
            inherit.aes = FALSE, vjust = -0.9, hjust = -0.35,
            size = 2.7, colour = "grey15", fontface = "bold") +
  scale_fill_manual(values = pal, name = NULL) +
  scale_colour_manual(values = pal, name = NULL) +
  scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2),
                     expand = expansion(mult = c(0.01, 0.04))) +
  labs(
    x = NULL,
    y = "Frailty Index (0–1)",
    caption = paste0(
      "Violin: kernel density of FI among FI-eligible participants aged ≥60 years (width-scaled). ",
      "Box: median and interquartile range; whiskers omitted for clarity.\n",
      "Numeric labels give the cohort median. Event rate = four-year all-cause mortality in the complete-case analytic sample.\n",
      "All cohorts satisfied the Searle submaximal limit (FI max ≤ 1.0). ",
      "MHAS used 27/41 cohort-available stems under a cohort-specific 80% threshold; all other cohorts 41/41."
    )
  ) +
  theme_bw(base_size = 10, base_family = "sans") +
  theme(
    panel.grid.minor  = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(colour = "grey92", linewidth = 0.3),
    legend.position   = "top",
    legend.key.size   = unit(4, "mm"),
    legend.text       = element_text(size = 8.5),
    legend.margin     = margin(b = -4),
    axis.text.x       = element_text(size = 8, lineheight = 1.05),
    axis.text.y       = element_text(size = 8),
    axis.title.y      = element_text(size = 9),
    plot.caption      = element_text(size = 7, hjust = 0, colour = "grey45",
                                     margin = margin(t = 6))
  )

# ── 5. Save ───────────────────────────────────────────────────────────────────
tiff_path <- file.path(OUTDIR, paste0("fig2_fi_distribution_", stamp, ".tiff"))
pdf_path  <- file.path(OUTDIR, paste0("fig2_fi_distribution_", stamp, ".pdf"))

ggsave(tiff_path, p, width = 180, height = 105, units = "mm",
       dpi = 600, compression = "lzw")
ggsave(pdf_path,  p, width = 180, height = 105, units = "mm")

# Also write the summary table used in the figure
write.csv(med_tbl[, c("cohort", "n", "med")],
          file.path(OUTDIR, paste0("fig2_fi_summary_", stamp, ".csv")),
          row.names = FALSE)

cat("\n✔  Figure 2 saved:\n   ", tiff_path, "\n   ", pdf_path, "\n")
