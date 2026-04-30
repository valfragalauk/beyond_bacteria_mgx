#!/usr/bin/env Rscript

library(readr)
library(dplyr)
library(ggplot2)

options(scipen = 999)

# ============================================================
# Summarise how prevalence filtering affects:
# 1. Total reads retained
# 2. Number / percentage of genera retained
# across four datasets:
# - GenBank viral
# - GenBank fungal
# - RefSeq viral
# - RefSeq fungal
# ============================================================

# ----------------------------
# Base directory
# ----------------------------

base_dir <- "/scratch/prj/rosetree/Valentina/results/downstream/descriptive_statistics/taxonomic_abundance_filtering"

# ----------------------------
# Input files
# Unfiltered = original matrix
# 2%        = 2% prevalence filtered
# 5%        = 5% prevalence filtered
# 10%       = 10% prevalence filtered
# ----------------------------

files <- list(
  genbank_viral = list(
    unfiltered = file.path(base_dir, "genbank/tables/viral_genus_matrix.tsv"),
    p2         = file.path(base_dir, "genbank/filtered/genbank_viral_genus_2pct.totalcount_gt_1.prevalence_0p02.tsv"),
    p5         = file.path(base_dir, "genbank/filtered/genbank_viral_genus.totalcount_gt_1.prevalence_0p05.tsv"),
    p10        = file.path(base_dir, "genbank/filtered/genbank_viral_genus.totalcount_gt_1.prevalence_0p1.tsv")
  ),
  genbank_fungal = list(
    unfiltered = file.path(base_dir, "genbank/tables/fungal_genus_matrix.tsv"),
    p2         = file.path(base_dir, "genbank/filtered/genbank_fungal_genus_2pct.totalcount_gt_1.prevalence_0p02.tsv"),
    p5         = file.path(base_dir, "genbank/filtered/genbank_fungal_genus.totalcount_gt_1.prevalence_0p05.tsv"),
    p10        = file.path(base_dir, "genbank/filtered/genbank_fungal_genus.totalcount_gt_1.prevalence_0p1.tsv")
  ),
  refseq_viral = list(
    unfiltered = file.path(base_dir, "refseq/tables/refseq_viral_G_counts_samples_x_taxa.tsv"),
    p2         = file.path(base_dir, "refseq/filtered/refseq_viral_genus_2pct.totalcount_gt_1.prevalence_0p02.tsv"),
    p5         = file.path(base_dir, "refseq/filtered/refseq_viral_genus.totalcount_gt_1.prevalence_0p05.tsv"),
    p10        = file.path(base_dir, "refseq/filtered/refseq_viral_genus.totalcount_gt_1.prevalence_0p1.tsv")
  ),
  refseq_fungal = list(
    unfiltered = file.path(base_dir, "refseq/tables/refseq_fungi_G_counts_samples_x_taxa.tsv"),
    p2         = file.path(base_dir, "refseq/filtered/refseq_fungal_genus_2pct.totalcount_gt_1.prevalence_0p02.tsv"),
    p5         = file.path(base_dir, "refseq/filtered/refseq_fungal_genus.totalcount_gt_1.prevalence_0p05.tsv"),
    p10        = file.path(base_dir, "refseq/filtered/refseq_fungal_genus.totalcount_gt_1.prevalence_0p1.tsv")
  )
)

# ----------------------------
# Helper function
# Reads a samples x taxa matrix and returns:
# - number of taxa
# - total reads
# ----------------------------

summarise_matrix <- function(path, dataset_name, threshold_label) {
  df <- read_tsv(path, show_col_types = FALSE)

  # First column is sample ID; remaining columns are taxa
  n_taxa <- ncol(df) - 1
  total_reads <- sum(as.matrix(df[, -1]), na.rm = TRUE)

  tibble(
    dataset = dataset_name,
    threshold = threshold_label,
    n_taxa = n_taxa,
    total_reads = total_reads
  )
}

# ----------------------------
# Build summary table
# ----------------------------

summary_df <- bind_rows(
  summarise_matrix(files$genbank_viral$unfiltered, "GenBank viral",  "Unfiltered"),
  summarise_matrix(files$genbank_viral$p2,         "GenBank viral",  "2%"),
  summarise_matrix(files$genbank_viral$p5,         "GenBank viral",  "5%"),
  summarise_matrix(files$genbank_viral$p10,        "GenBank viral",  "10%"),

  summarise_matrix(files$genbank_fungal$unfiltered, "GenBank fungal", "Unfiltered"),
  summarise_matrix(files$genbank_fungal$p2,         "GenBank fungal", "2%"),
  summarise_matrix(files$genbank_fungal$p5,         "GenBank fungal", "5%"),
  summarise_matrix(files$genbank_fungal$p10,        "GenBank fungal", "10%"),

  summarise_matrix(files$refseq_viral$unfiltered, "RefSeq viral",  "Unfiltered"),
  summarise_matrix(files$refseq_viral$p2,         "RefSeq viral",  "2%"),
  summarise_matrix(files$refseq_viral$p5,         "RefSeq viral",  "5%"),
  summarise_matrix(files$refseq_viral$p10,        "RefSeq viral",  "10%"),

  summarise_matrix(files$refseq_fungal$unfiltered, "RefSeq fungal", "Unfiltered"),
  summarise_matrix(files$refseq_fungal$p2,         "RefSeq fungal", "2%"),
  summarise_matrix(files$refseq_fungal$p5,         "RefSeq fungal", "5%"),
  summarise_matrix(files$refseq_fungal$p10,        "RefSeq fungal", "10%")
) %>%
  mutate(
    threshold = factor(threshold, levels = c("Unfiltered", "2%", "5%", "10%")),
    dataset = factor(dataset, levels = c(
      "GenBank viral",
      "GenBank fungal",
      "RefSeq viral",
      "RefSeq fungal"
    ))
  )

# ----------------------------
# Calculate percentage of taxa retained
# relative to the unfiltered matrix
# ----------------------------

summary_df <- summary_df %>%
  group_by(dataset) %>%
  mutate(
    n_taxa_unfiltered = n_taxa[threshold == "Unfiltered"][1],
    pct_taxa_retained = (n_taxa / n_taxa_unfiltered) * 100
  ) %>%
  ungroup()

# ----------------------------
# Save summary table
# ----------------------------

summary_out <- file.path(base_dir, "summary/filtering_effects_summary.tsv")
dir.create(dirname(summary_out), recursive = TRUE, showWarnings = FALSE)
write_tsv(summary_df, summary_out)

# ----------------------------
# Colours
# GenBank viral  = green
# GenBank fungal = sky blue
# RefSeq viral   = pink/purple
# RefSeq fungal  = vermillion
# ----------------------------

dataset_cols <- c(
  "GenBank viral"  = "#009E73",
  "GenBank fungal" = "#56B4E9",
  "RefSeq viral"   = "#CC79A7",
  "RefSeq fungal"  = "#D55E00"
)

# ----------------------------
# Figure A
# Total reads retained after filtering
# ----------------------------

p_a <- ggplot(summary_df, aes(x = threshold, y = total_reads, colour = dataset, group = dataset)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5) +
  scale_colour_manual(values = dataset_cols) +
  labs(
    title = "Reads retained after prevalence filtering",
    x = "Prevalence threshold",
    y = "Total read count",
    colour = NULL
  ) +
  theme_classic(base_size = 14, base_family = "Nimbus Sans") +
  theme(
    plot.title = element_text(size = 14),
    axis.title = element_text(size = 9),
    axis.text = element_text(size = 9, colour = "#333333"),
    axis.line = element_line(linewidth = 0.4),
    axis.ticks = element_line(linewidth = 0.4),
    legend.position = "top",
    legend.text = element_text(size = 9)
  )

# ----------------------------
# Figure B
# Percentage of genera retained after filtering
# Labels show absolute genus count at each threshold
# ----------------------------

p_b <- ggplot(summary_df, aes(x = threshold, y = pct_taxa_retained, colour = dataset, group = dataset)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5) +
  scale_colour_manual(values = dataset_cols) +
  labs(
    title = "Genera retained after prevalence filtering",
    x = "Prevalence threshold",
    y = "Genera retained (%)",
    colour = NULL
  ) +
  theme_classic(base_size = 14, base_family = "Nimbus Sans") +
  theme(
    plot.title = element_text(size = 14),
    axis.title = element_text(size = 9),
    axis.text = element_text(size = 9, colour = "#333333"),
    axis.line = element_line(linewidth = 0.4),
    axis.ticks = element_line(linewidth = 0.4),
    legend.position = "top",
    legend.text = element_text(size = 9)
  )

# ----------------------------
# Save figures
# ----------------------------

ggsave(
  file.path(base_dir, "summary/filtering_reads_retained_all_datasets.png"),
  p_a,
  width = 5.5,
  height = 4.5,
  dpi = 300
)

ggsave(
  file.path(base_dir, "summary/filtering_taxa_retained_all_datasets.png"),
  p_b,
  width = 5.5,
  height = 4.5,
  dpi = 300
)

cat("Saved summary table to:", summary_out, "\n")
cat("Saved Figure A: filtering_reads_retained_all_datasets.png\n")
cat("Saved Figure B: filtering_taxa_retained_all_datasets.png\n")
