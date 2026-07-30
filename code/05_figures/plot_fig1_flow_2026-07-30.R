#!/usr/bin/env Rscript
# =============================================================================
# Figure 1: Study design and participant flow (CONSORT-style)
# Paper 1 · 2026-07-30
#
# DOT source: code/05_figures/fig1_flow_2026-07-30.dot  (version-controlled)
# Rendering:  DiagrammeR (bundled viz.js) -> SVG -> PDF/TIFF/PNG via rsvg
# No system Graphviz required.
#
# Run from project root:
#   Rscript --vanilla code/05_figures/plot_fig1_flow_2026-07-30.R
# =============================================================================

suppressPackageStartupMessages({
  library(DiagrammeR)
  library(DiagrammeRsvg)
  library(rsvg)
})

args       <- commandArgs(FALSE)
farg       <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(farg)) dirname(normalizePath(sub("^--file=", "", farg[1]))) else getwd()

root    <- normalizePath(file.path(script_dir, "..", ".."), mustWork = TRUE)
dot_src <- file.path(script_dir, "fig1_flow_2026-07-30.dot")
OUTDIR  <- file.path(root, "results", "figures")
stamp   <- "2026-07-30"

if (!file.exists(dot_src)) {
  stop("DOT source not found: ", dot_src,
       "\n  Run from project root or check script_dir resolution.")
}

cat("Reading DOT source:", dot_src, "\n")
dot <- paste(readLines(dot_src, warn = FALSE), collapse = "\n")

# ── 1. Render ─────────────────────────────────────────────────────────────────
cat("Rendering with DiagrammeR...\n")
g       <- DiagrammeR::grViz(dot)
svg_txt <- DiagrammeRsvg::export_svg(g)

# ── 2. Export ─────────────────────────────────────────────────────────────────
svg_path  <- file.path(OUTDIR, paste0("fig1_flow_", stamp, ".svg"))
pdf_path  <- file.path(OUTDIR, paste0("fig1_flow_", stamp, ".pdf"))
png_path  <- file.path(OUTDIR, paste0("fig1_flow_", stamp, ".png"))
tiff_path <- file.path(OUTDIR, paste0("fig1_flow_", stamp, ".tiff"))

writeLines(svg_txt, svg_path)

svg_raw <- charToRaw(svg_txt)

# PDF (vector — preferred for journal submission)
rsvg::rsvg_pdf(svg_raw, pdf_path)

# PNG preview at 150 dpi  (180 mm wide → 1063 px)
rsvg::rsvg_png(svg_raw, png_path, width = round(180 / 25.4 * 150))

# TIFF at 600 dpi for journal (180 mm wide → 4252 px)
px_w <- round(180 / 25.4 * 600)
bmp  <- rsvg::rsvg(svg_raw, width = px_w)
dims <- dim(bmp)   # rsvg returns [row, col, channel]
img_h <- dims[1]
img_w <- dims[2]

tiff(tiff_path,
     width  = img_w,
     height = img_h,
     units  = "px",
     compression = "lzw",
     res    = 600)
par(mar = c(0, 0, 0, 0), xpd = NA)
plot.new()
plot.window(xlim = c(0, 1), ylim = c(0, 1))
rasterImage(bmp, 0, 0, 1, 1, interpolate = FALSE)
invisible(dev.off())

cat("OK  Figure 1 outputs:\n")
cat("   SVG : ", svg_path, "\n")
cat("   PDF : ", pdf_path, "(vector — use for submission)\n")
cat("   PNG : ", png_path, "(preview)\n")
cat("   TIFF: ", tiff_path,
    sprintf("(%d x %d px at 600 dpi)\n", img_w, img_h))
