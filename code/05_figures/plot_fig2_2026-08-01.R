#!/usr/bin/env Rscript
# =============================================================================
# Figure 2 (redraw): FI distribution across six cohorts
# 2026-08-01
#
# Fixes vs the 2026-07-30 version:
#   - x-axis labels previously crammed cohort name + n + event rate onto one
#     line and collided; sample size and event rate now move to a table strip
#     below the axis, so nothing overlaps.
#   - median value labels sat on top of the boxplot; now placed to the right of
#     each box at a fixed offset.
#   - Times New Roman, four-size type scale.
# =============================================================================

suppressPackageStartupMessages({ library(arrow); library(dplyr); library(tidyr) })
args <- commandArgs(FALSE); farg <- grep("^--file=", args, value = TRUE)
SD <- if (length(farg)) dirname(normalizePath(sub("^--file=", "", farg[1]))) else getwd()
ROOT <- normalizePath(file.path(SD, "..", ".."), mustWork = TRUE)
source(file.path(SD, "_fig_theme.R"))
DD <- file.path(ROOT, "data", "analysis")

files <- c(CHARLS = "charls_fi_2011_2026-07-27.parquet",
           CLHLS  = "clhls_fi_2011_2026-07-29.parquet",
           KLoSA  = "klosa_fi_2012_2026-07-29.parquet",
           HRS    = "hrs_fi_2012_2026-07-29.parquet",
           SHARE  = "share_fi_2011_2026-07-29.parquet",
           MHAS   = "mhas_fi_2012_2026-07-28.parquet")
ev_rate <- c(CHARLS = 10.2, CLHLS = 46.3, KLoSA = 9.6, HRS = 20.0, SHARE = 8.7, MHAS = 10.2)

read_fi <- function(nm, fn) {
  d <- as.data.frame(read_parquet(file.path(DD, fn)))
  ac <- intersect(c("age", "r3agey", "r4agey"), names(d))[1]
  d$.age <- suppressWarnings(as.numeric(d[[ac]]))
  if ("fi_excluded" %in% names(d)) d <- d[!is.na(d$fi_excluded) & !d$fi_excluded, , drop = FALSE]
  d |> filter(!is.na(.age), .age >= 60, !is.na(fi_full), fi_full >= 0, fi_full <= 1) |>
    transmute(cohort = nm, fi = as.numeric(fi_full))
}
fi <- bind_rows(Map(read_fi, names(files), files))

ord <- c("CHARLS", "CLHLS", "KLoSA", "HRS", "SHARE", "MHAS")
fi$cohort <- factor(fi$cohort, levels = ord)
fi$role <- factor(ifelse(fi$cohort %in% c("CHARLS", "CLHLS", "KLoSA"),
                         "Development / Asian pool", "External validation"),
                  levels = names(PAL_ROLE))

stat <- fi |> group_by(cohort) |>
  summarise(med = median(fi), n = n(), .groups = "drop") |>
  mutate(role = ifelse(cohort %in% c("CHARLS", "CLHLS", "KLoSA"),
                       "Development / Asian pool", "External validation"),
         ev = ev_rate[as.character(cohort)],
         lab_n  = format(n, big.mark = ",", trim = TRUE),
         lab_ev = sprintf("%.1f%%", ev))

p <- ggplot(fi, aes(cohort, fi)) +
  geom_violin(aes(fill = role, colour = role), alpha = 0.30, width = 0.88,
              linewidth = 0.35, trim = TRUE, scale = "width") +
  geom_boxplot(width = 0.15, outlier.shape = NA, fill = "white",
               colour = "grey25", linewidth = 0.38, coef = 0) +
  # median labels offset to the right so they never sit on the box
  geom_text(data = stat, aes(y = med, label = sprintf("%.3f", med)),
            nudge_x = 0.30, hjust = 0, size = SZ_TEXT / .pt, family = FONT) +
  scale_fill_manual(values = PAL_ROLE, name = NULL) +
  scale_colour_manual(values = PAL_ROLE, name = NULL) +
  scale_y_continuous(limits = c(0, 1.02), breaks = seq(0, 1, 0.2),
                     expand = expansion(mult = c(0.01, 0.02))) +
  # extra room on the right so the MHAS median label is not clipped
  scale_x_discrete(expand = expansion(add = c(0.62, 0.95))) +
  labs(x = NULL, y = "Frailty Index (0–1)",
       caption = paste0(
         "Violin: kernel density of the frailty index among FI-eligible participants aged 60 years and over, scaled to equal width.\n",
         "Box: median and interquartile range, with whiskers suppressed so that the density shape stays legible.\n",
         "Numeric label gives the cohort median. All cohorts satisfied the Searle submaximal limit (FI maximum ≤ 1.0).\n",
         "MHAS used 27 of 41 cohort-available items under a cohort-specific 80% threshold; all other cohorts used 41 of 41."
       )) +
  theme_paper(grid = "y") +
  theme(axis.text.x = element_text(face = "bold"),
        axis.ticks.x = element_blank(),
        plot.caption = element_blank())   # caption moved to the composed figure

# Sample size / event-rate strip rendered as its own panel underneath, which
# keeps three pieces of information per cohort without stacking them into one
# axis label.
tbl <- stat |> select(cohort, lab_n, lab_ev) |>
  pivot_longer(c(lab_n, lab_ev), names_to = "row", values_to = "val") |>
  mutate(row = factor(row, c("lab_n", "lab_ev"),
                      c("Analytic n", "4-year mortality")))

p_tbl <- ggplot(tbl, aes(cohort, row, label = val)) +
  geom_text(size = SZ_TEXT / .pt, family = FONT) +
  scale_x_discrete(expand = expansion(add = c(0.62, 0.95))) +
  scale_y_discrete(limits = rev) +
  labs(x = NULL, y = NULL,
       caption = paste0(
         "Violin: kernel density of the frailty index among FI-eligible participants aged 60 years and over, scaled to equal width.\n",
         "Box: median and interquartile range, with whiskers suppressed so that the density shape stays legible.\n",
         "Numeric label gives the cohort median. All cohorts satisfied the Searle submaximal limit (FI maximum ≤ 1.0).\n",
         "MHAS used 27 of 41 cohort-available items under a cohort-specific 80% threshold; all other cohorts used 41 of 41."
       )) +
  theme_paper(grid = "none", legend = "none") +
  theme(panel.border = element_blank(),
        axis.text.x = element_blank(),
        axis.ticks = element_blank(),
        axis.text.y = element_text(size = SZ_STRIP, colour = COL_GREY, hjust = 1),
        plot.margin = margin(0, 8, 0, 6))

library(patchwork)
fig <- p / p_tbl + plot_layout(heights = c(1, 0.13))

ggsave_paper(file.path(ROOT, "results/figures/fig2_fi_distribution_2026-08-01"),
             fig, width_mm = 180, height_mm = 115)
