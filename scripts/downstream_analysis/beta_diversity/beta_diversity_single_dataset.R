#!/usr/bin/env Rscript 

suppressPackageStartupMessages({
  library(optparse)
  library(vegan)
  library(ggplot2)
  library(pheatmap)
})

# =========================================================
# Beta diversity analysis for one dataset
# =========================================================
# Inputs:
#   --dataset_id
#   --matrix_path
#   --metadata_path
#   --outdir
#
# This script:
# Computes Bray-Curtis dissimilarity
# Runs PCoA and saves plots
# Runs PERMANOVA:
#      - outcome only
#      - outcome + bmi
# Runs betadispersion
# Makes a clustered heatmap of top taxa
# =========================================================

# -----------------------------
# Command line arguments
# -----------------------------
option_list <- list(
  make_option("--dataset_id", type = "character"),
  make_option("--matrix_path", type = "character"),
  make_option("--metadata_path", type = "character"),
  make_option("--outdir", type = "character")
)

opt <- parse_args(OptionParser(option_list = option_list))

if (is.null(opt$dataset_id) ||
    is.null(opt$matrix_path) ||
    is.null(opt$metadata_path) ||
    is.null(opt$outdir)) {
  stop("Missing one or more required arguments: --dataset_id, --matrix_path, --metadata_path, --outdir")
}

dir.create(opt$outdir, recursive = TRUE, showWarnings = FALSE)

# -----------------------------
# Helper functions
# -----------------------------
clean_matrix_ids <- function(x) {
  sub("_1$", "", x)
}

fmt_p <- function(p) {
  if (is.na(p)) return(NA_character_)
  if (p < 0.001) return("<0.001")
  sprintf("%.3f", p)
}

fmt_r2 <- function(x) {
  if (is.na(x)) return(NA_character_)
  sprintf("%.3f", x)
}

make_perm_label <- function(perm_obj, label) {
  df <- as.data.frame(perm_obj)
  r2 <- df["Model", "R2"]
  p  <- df["Model", "Pr(>F)"]
  paste0(label, ": R² = ", fmt_r2(r2), ", p = ", fmt_p(p))
}

make_betadisper_label <- function(bd_obj, label) {
  p <- bd_obj$tab[1, "Pr(>F)"]
  paste0(label, ": p = ", fmt_p(p))
}

# Read matrix
read_count_matrix <- function(path) {
  x <- read.delim(path, sep = "\t", check.names = FALSE, stringsAsFactors = FALSE)

  first_col_name <- colnames(x)[1]

  if (first_col_name %in% c("", "X", "Unnamed: 0", "sample", "Sample", "id", "ID")) {
    rownames(x) <- x[[1]]
    x <- x[, -1, drop = FALSE]
  } else {
    suppressWarnings({
      frac_numeric <- mean(!is.na(as.numeric(x[[1]])))
    })
    if (is.na(frac_numeric) || frac_numeric < 0.5) {
      rownames(x) <- x[[1]]
      x <- x[, -1, drop = FALSE]
    }
  }

  x <- as.data.frame(x, check.names = FALSE)
  x[] <- lapply(x, function(col) suppressWarnings(as.numeric(col)))
  rownames(x) <- make.unique(rownames(x))
  x
}

guess_and_fix_orientation <- function(mat, metadata_reads_ids) {
  row_matches <- sum(clean_matrix_ids(rownames(mat)) %in% metadata_reads_ids)
  col_matches <- sum(clean_matrix_ids(colnames(mat)) %in% metadata_reads_ids)

  if (row_matches >= col_matches) {
    return(mat)
  } else {
    return(as.data.frame(t(as.matrix(mat)), check.names = FALSE))
  }
}

# -----------------------------
# Read inputs
# -----------------------------
meta <- read.delim(opt$metadata_path, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)
mat  <- read_count_matrix(opt$matrix_path)

meta$outcome <- factor(meta$outcome, levels = c("TERM", "sPTB"))
meta$sPTB34  <- factor(meta$sPTB34, levels = c("no", "yes"))
meta$bmi     <- suppressWarnings(as.numeric(meta$bmi))

mat <- guess_and_fix_orientation(mat, meta$reads_ID)

# Remove taxa with zero total counts
mat <- mat[, colSums(mat, na.rm = TRUE) > 0, drop = FALSE]

# -----------------------------
# Match matrix to metadata
# -----------------------------
matrix_ids_raw   <- rownames(mat)
matrix_ids_clean <- clean_matrix_ids(matrix_ids_raw)

unmatched <- setdiff(matrix_ids_clean, meta$reads_ID)
if (length(unmatched) > 0) {
  writeLines(unmatched, con = file.path(opt$outdir, "unmatched_matrix_samples.txt"))
  stop("Unmatched samples found. See unmatched_matrix_samples.txt")
}

meta <- meta[match(matrix_ids_clean, meta$reads_ID), , drop = FALSE]

if (!all(matrix_ids_clean == meta$reads_ID)) {
  stop("Metadata reordering failed: cleaned matrix IDs do not match metadata reads_ID.")
}

rownames(meta) <- matrix_ids_raw

matching_summary <- data.frame(
  dataset_id = opt$dataset_id,
  n_matrix_samples = nrow(mat),
  n_metadata_rows = nrow(meta),
  n_unmatched = length(unmatched),
  matching_key = "reads_ID",
  matrix_ids_cleaned_by = "removed trailing _1",
  stringsAsFactors = FALSE
)

write.table(
  matching_summary,
  file = file.path(opt$outdir, "sample_id_matching_summary.tsv"),
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

# -----------------------------
# Remove zero-total samples
# -----------------------------
sample_totals <- rowSums(mat, na.rm = TRUE)
keep_samples <- sample_totals > 0

mat <- mat[keep_samples, , drop = FALSE]
meta <- meta[keep_samples, , drop = FALSE]
matrix_ids_clean <- matrix_ids_clean[keep_samples]

sample_total_tbl <- data.frame(
  matrix_sample_id = rownames(mat),
  reads_ID = matrix_ids_clean,
  sample_label = meta$sample_label,
  total_count = rowSums(mat, na.rm = TRUE),
  stringsAsFactors = FALSE
)

write.table(
  sample_total_tbl,
  file = file.path(opt$outdir, "sample_total_counts_used.tsv"),
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

# -----------------------------
# Relative abundance
# -----------------------------
rel_abund <- decostand(mat, method = "total")

rel_abund_export <- data.frame(
  matrix_sample_id = rownames(rel_abund),
  reads_ID = matrix_ids_clean,
  rel_abund,
  check.names = FALSE,
  stringsAsFactors = FALSE
)

write.table(
  rel_abund_export,
  file = file.path(opt$outdir, "relative_abundance_matrix.tsv"),
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

# -----------------------------
# Bray-Curtis dissimilarity
# -----------------------------
bray <- vegdist(rel_abund, method = "bray")
bray_mat <- as.matrix(bray)

write.table(
  bray_mat,
  file = file.path(opt$outdir, "bray_curtis_distance_matrix.tsv"),
  sep = "\t",
  quote = FALSE,
  col.names = NA
)

# -----------------------------
# PERMANOVA
# -----------------------------
perm_outcome_only <- adonis2(
  bray ~ outcome,
  data = meta,
  permutations = 999
)

# BMI-adjusted sensitivity model
# adonis2 cannot handle missing BMI, so subset both metadata and distance matrix
bmi_complete <- !is.na(meta$bmi)

bray_bmi <- as.dist(as.matrix(bray)[bmi_complete, bmi_complete])
meta_bmi <- meta[bmi_complete, , drop = FALSE]

bmi_model_summary <- data.frame(
  dataset_id = opt$dataset_id,
  n_total_beta_samples = nrow(meta),
  n_bmi_complete = sum(bmi_complete),
  n_removed_missing_bmi = sum(!bmi_complete),
  stringsAsFactors = FALSE
)

write.table(
  bmi_model_summary,
  file = file.path(opt$outdir, "bmi_adjusted_model_sample_count.tsv"),
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

perm_bmi_adjusted <- adonis2(
  bray_bmi ~ outcome + bmi,
  data = meta_bmi,
  permutations = 999
)

perm_sptb34_only <- adonis2(
  bray ~ sPTB34,
  data = meta,
  permutations = 999
)

perm_to_df <- function(x, model_label) {
  out <- as.data.frame(x)
  out$term <- rownames(out)
  rownames(out) <- NULL
  out$model <- model_label
  out <- out[, c("model", "term", setdiff(names(out), c("model", "term")))]
  out
}

permanova_results <- rbind(
  perm_to_df(perm_outcome_only, "outcome_only"),
  perm_to_df(perm_bmi_adjusted, "outcome_plus_bmi"),
  perm_to_df(perm_sptb34_only, "sPTB34_only")
)

write.table(
  permanova_results,
  file = file.path(opt$outdir, "permanova_results.tsv"),
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

outcome_label <- make_perm_label(perm_outcome_only, "PERMANOVA outcome")
bmi_label     <- make_perm_label(perm_bmi_adjusted, "PERMANOVA outcome + BMI")
sptb34_label  <- make_perm_label(perm_sptb34_only, "PERMANOVA sPTB34")

# -----------------------------
# PCoA
# -----------------------------
pcoa <- cmdscale(bray, eig = TRUE, k = 2)

positive_eigs <- pcoa$eig[pcoa$eig > 0]
axis1_pct <- round(100 * positive_eigs[1] / sum(positive_eigs), 2)
axis2_pct <- round(100 * positive_eigs[2] / sum(positive_eigs), 2)

pcoa_df <- data.frame(
  matrix_sample_id = rownames(rel_abund),
  reads_ID = matrix_ids_clean,
  Axis1 = pcoa$points[, 1],
  Axis2 = pcoa$points[, 2],
  sample_label = meta$sample_label,
  outcome = meta$outcome,
  sPTB34 = meta$sPTB34,
  bmi = meta$bmi,
  Risk = if ("Risk" %in% names(meta)) meta$Risk else NA,
  stringsAsFactors = FALSE
)

write.table(
  pcoa_df,
  file = file.path(opt$outdir, "pcoa_coordinates.tsv"),
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

pcoa_x <- min(pcoa_df$Axis1, na.rm = TRUE)
pcoa_y <- max(pcoa_df$Axis2, na.rm = TRUE)

# Plot 1: coloured by outcome
p_outcome <- ggplot(pcoa_df, aes(x = Axis1, y = Axis2, colour = outcome)) +
  geom_point(size = 3, alpha = 0.85) +
  annotate(
    "text",
    x = pcoa_x,
    y = pcoa_y,
    label = paste(outcome_label, sptb34_label, sep = "\n"),
    hjust = 0,
    vjust = 1,
    size = 3.4,
    colour = "black"
  ) +
  scale_colour_manual(values = c("TERM" = "#0072B2", "sPTB" = "#E69F00")) +
  labs(
    title = paste0(opt$dataset_id, " PCoA (Bray-Curtis)"),
    x = paste0("PCoA1 (", axis1_pct, "%)"),
    y = paste0("PCoA2 (", axis2_pct, "%)"),
    colour = "Outcome"
  ) +
  theme_classic(base_size = 13) +
  theme(
    plot.title = element_text(size = 16, hjust = 0.5),
    axis.line = element_line(linewidth = 0.3, colour = "black"),
    axis.ticks = element_line(linewidth = 0.3, colour = "black")
  )

ggsave(
  filename = file.path(opt$outdir, "pcoa_outcome.png"),
  plot = p_outcome,
  width = 7.4,
  height = 5.4,
  dpi = 300,
  bg = "white"
)

# Plot 2: outcome with BMI point size for context
p_bmi <- ggplot(pcoa_df, aes(x = Axis1, y = Axis2, colour = outcome, size = bmi)) +
  geom_point(alpha = 0.8) +
  annotate(
    "text",
    x = pcoa_x,
    y = pcoa_y,
    label = bmi_label,
    hjust = 0,
    vjust = 1,
    size = 3.4,
    colour = "black"
  ) +
  scale_colour_manual(values = c("TERM" = "#0072B2", "sPTB" = "#E69F00")) +
  labs(
    title = paste0(opt$dataset_id, " PCoA (Bray-Curtis) with BMI"),
    x = paste0("PCoA1 (", axis1_pct, "%)"),
    y = paste0("PCoA2 (", axis2_pct, "%)"),
    colour = "Outcome",
    size = "BMI"
  ) +
  theme_classic(base_size = 13) +
  theme(
    plot.title = element_text(size = 16, hjust = 0.5),
    axis.line = element_line(linewidth = 0.3, colour = "black"),
    axis.ticks = element_line(linewidth = 0.3, colour = "black")
  )

ggsave(
  filename = file.path(opt$outdir, "pcoa_outcome_bmi.png"),
  plot = p_bmi,
  width = 7.4,
  height = 5.4,
  dpi = 300,
  bg = "white"
)

# -----------------------------
# betadisper
# -----------------------------
bd_outcome <- betadisper(bray, meta$outcome)
bd_outcome_perm <- permutest(bd_outcome, permutations = 999)

bd_sptb34 <- betadisper(bray, meta$sPTB34)
bd_sptb34_perm <- permutest(bd_sptb34, permutations = 999)

betadisper_results <- data.frame(
  comparison = c("outcome", "sPTB34"),
  F_value = c(
    bd_outcome_perm$tab[1, "F"],
    bd_sptb34_perm$tab[1, "F"]
  ),
  p_value = c(
    bd_outcome_perm$tab[1, "Pr(>F)"],
    bd_sptb34_perm$tab[1, "Pr(>F)"]
  ),
  stringsAsFactors = FALSE
)

write.table(
  betadisper_results,
  file = file.path(opt$outdir, "betadisper_results.tsv"),
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

disp_label <- make_betadisper_label(bd_outcome_perm, "betadisper outcome")

centroid_outcome <- data.frame(
  matrix_sample_id = names(bd_outcome$distances),
  distance_to_centroid = bd_outcome$distances,
  reads_ID = clean_matrix_ids(names(bd_outcome$distances)),
  sample_label = meta$sample_label,
  outcome = meta$outcome,
  bmi = meta$bmi,
  stringsAsFactors = FALSE
)

write.table(
  centroid_outcome,
  file = file.path(opt$outdir, "betadisper_distances_outcome.tsv"),
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

disp_y <- max(centroid_outcome$distance_to_centroid, na.rm = TRUE) * 1.05

p_disp <- ggplot(centroid_outcome, aes(x = outcome, y = distance_to_centroid, colour = outcome)) +
  geom_boxplot(outlier.shape = NA, fill = NA, linewidth = 0.4) +
  geom_jitter(width = 0.12, height = 0, size = 2, alpha = 0.8) +
  annotate(
    "text",
    x = 1.5,
    y = disp_y,
    label = disp_label,
    size = 3.6,
    colour = "black"
  ) +
  scale_colour_manual(values = c("TERM" = "#0072B2", "sPTB" = "#E69F00")) +
  labs(
    title = paste0(opt$dataset_id, " dispersion by outcome"),
    x = "Outcome",
    y = "Distance to centroid"
  ) +
  expand_limits(y = disp_y * 1.05) +
  theme_classic(base_size = 13) +
  theme(
    plot.title = element_text(size = 16, hjust = 0.5),
    legend.position = "none",
    axis.line = element_line(linewidth = 0.3, colour = "black"),
    axis.ticks = element_line(linewidth = 0.3, colour = "black")
  )

ggsave(
  filename = file.path(opt$outdir, "betadisper_outcome_boxplot.png"),
  plot = p_disp,
  width = 6.8,
  height = 5.0,
  dpi = 300,
  bg = "white"
)

# -----------------------------
# Hierarchical clustering heatmap
# -----------------------------
taxa_means <- colMeans(rel_abund, na.rm = TRUE)
top_taxa <- names(sort(taxa_means, decreasing = TRUE))[1:min(30, length(taxa_means))]

heat_mat <- rel_abund[, top_taxa, drop = FALSE]
heat_mat_log <- log10(heat_mat + 1e-6)

annotation_df <- data.frame(
  outcome = meta$outcome,
  row.names = rownames(meta),
  check.names = FALSE,
  stringsAsFactors = FALSE
)

pheatmap(
  mat = heat_mat_log,
  annotation_row = annotation_df,
  clustering_distance_rows = bray,
  clustering_distance_cols = "euclidean",
  clustering_method = "average",
  show_rownames = FALSE,
  fontsize_col = 8,
  filename = file.path(opt$outdir, "heatmap_top30_taxa.png"),
  width = 10,
  height = 8
)

# -----------------------------
# Export metadata actually used
# -----------------------------
meta_used <- data.frame(
  matrix_sample_id = rownames(meta),
  meta,
  check.names = FALSE,
  stringsAsFactors = FALSE
)

write.table(
  meta_used,
  file = file.path(opt$outdir, "metadata_used_in_beta.tsv"),
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

message("Completed beta-diversity analysis for: ", opt$dataset_id)
