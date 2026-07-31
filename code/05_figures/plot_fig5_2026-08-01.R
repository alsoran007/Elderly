#!/usr/bin/env Rscript
# =============================================================================
# Figure 5 (redraw): L0-L3 recalibration ladder, HRS / SHARE / MHAS
# 2026-08-01 — Times New Roman, unified type scale, no overlapping labels
# =============================================================================

suppressPackageStartupMessages({ library(dplyr); library(tidyr) })
args <- commandArgs(FALSE); farg <- grep("^--file=", args, value = TRUE)
SD <- if (length(farg)) dirname(normalizePath(sub("^--file=", "", farg[1]))) else getwd()
ROOT <- normalizePath(file.path(SD, "..", ".."), mustWork = TRUE)
source(file.path(SD, "_fig_theme.R"))

d <- read.csv(file.path(ROOT, "results/aim3/aim3_performance_table_2026-07-29.csv"),
              stringsAsFactors = FALSE) |>
  separate(label, into = c("cohort", "level"), sep = "_") |>
  mutate(cohort = factor(cohort, levels = c("HRS", "SHARE", "MHAS")),
         level  = factor(level,  levels = c("L0", "L1", "L2", "L3")))

long <- d |>
  select(cohort, level, c_index, c_lo, c_hi, oe, cal_slope, ipa) |>
  pivot_longer(c(c_index, oe, cal_slope, ipa), names_to = "metric", values_to = "value") |>
  mutate(metric = factor(metric, c("c_index", "oe", "cal_slope", "ipa"),
                         c("C-index", "O:E ratio", "Calibration slope", "IPA")),
         lo = ifelse(metric == "C-index", c_lo, NA),
         hi = ifelse(metric == "C-index", c_hi, NA))

# Reference lines only where a target value exists
refs <- data.frame(
  metric = factor(c("O:E ratio", "Calibration slope", "IPA"),
                  levels = levels(long$metric)),
  yint   = c(1, 1, 0)
)

pal <- c(HRS = "#A63603", SHARE = "#D95F0E", MHAS = COL_ACC)

p <- ggplot(long, aes(level, value, colour = cohort, group = cohort, shape = cohort)) +
  geom_hline(data = refs, aes(yintercept = yint), inherit.aes = FALSE,
             colour = COL_IDEAL, linetype = "22", linewidth = 0.4) +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.14, linewidth = 0.4,
                na.rm = TRUE, show.legend = FALSE) +
  geom_line(linewidth = 0.6) +
  geom_point(size = 2.1, fill = "white", stroke = 0.5) +
  facet_wrap(~metric, nrow = 1, scales = "free_y") +
  scale_colour_manual(values = pal, name = NULL,
                      labels = c("HRS (United States)", "SHARE (Europe)", "MHAS (Mexico)")) +
  scale_shape_manual(values = c(21, 24, 22), name = NULL,
                     labels = c("HRS (United States)", "SHARE (Europe)", "MHAS (Mexico)")) +
  scale_x_discrete(expand = expansion(add = 0.45)) +
  scale_y_continuous(expand = expansion(mult = 0.10), n.breaks = 5) +
  labs(x = "Recalibration level", y = NULL,
       caption = paste0(
         "L0 = frozen Asian-pool model; L1 = intercept update (event-rate correction); ",
         "L2 = intercept and slope; L3 = full refit in the target cohort.\n",
         "Dashed red line marks the ideal value (O:E = 1, calibration slope = 1, IPA = 0). ",
         "Error bars on C-index are 95% bootstrap intervals.\n",
         "IPA = Index of Prediction Accuracy. n = 10,707 (HRS), 36,352 (SHARE), 9,081 (MHAS)."
       )) +
  theme_paper(grid = "y") +
  theme(panel.spacing.x = unit(4.5, "mm"))

ggsave_paper(file.path(ROOT, "results/aim3/figures/fig5_recalibration_ladder_2026-08-01"),
             p, width_mm = 180, height_mm = 82)
