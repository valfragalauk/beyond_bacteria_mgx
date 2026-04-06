#!/usr/bin/env Rscript

# Create descriptive stacked barplots of microbial composition
#   1. Reads a filtered count matrix (samples x taxa)
#   2. Reads the metadata Excel file
#   3. Matches samples between matrix and metadata
#   4. Creates birth age groups from gestational age at delivery
#   5. Converts counts to relative abundance (each bar = 100%)
#   6. Keeps the globally most abundant 10 taxa and collapses the
#      remainder into "Other"
#   7. Produces stacked barplots faceted by birth age group

# TO RUN:
# Rscript composition_barplots.R \
#   <matrix_file> <metadata_xlsx> <dataset_name> <kingdom_label> <output_dir>

# ============================================================

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(tidyr)
  library(readxl)
  library(readr)
  library(ggplot2)
  library(stringr)
  library(forcats)
  library(tibble)
})

# -----------------------------
# Read command-line arguments
# -----------------------------
args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 5) {
  stop(
    paste0(
      "Expected 5 arguments:\n",
      "1) matrix_file\n",
      "2) metadata_xlsx\n",
      "3) dataset_name\n",
      "4) kingdom_label\n",
      "5) output_dir\n"
    )
  )
}

matrix_file   <- args[1]
metadata_file <- args[2]
dataset_name  <- args[3]
kingdom_label <- args[4]
output_dir    <- args[5]

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

write_tsv_safe <- function(df, file_path) {
  readr::write_tsv(df, file_path)
}

# -----------------------------
# Delivery group
#   <238      = 34 sPTB
#   238-258   = 37 sPTB
#   >=259     = Term
# -----------------------------
make_birth_age_group <- function(gest_days) {
  case_when(
    is.na(gest_days) ~ NA_character_,
    gest_days < 238 ~ "34 sPTB",
    gest_days >= 238 & gest_days <= 258 ~ "37 sPTB",
    gest_days >= 259 ~ "Term",
    TRUE ~ NA_character_
  )
}

birth_group_levels <- c("34 sPTB", "37 sPTB", "Term")

# -----------------------------
# Subtitle label from dataset
# -----------------------------
make_dataset_subtitle <- function(dataset_name, kingdom_label) {
  dataset_lower <- tolower(dataset_name)
  kingdom_clean <- case_when(
    tolower(kingdom_label) == "fungal" ~ "Fungal",
    tolower(kingdom_label) == "viral" ~ "Viral",
    TRUE ~ kingdom_label
  )

  db_label <- case_when(
    str_detect(dataset_lower, "genbank") ~ "GB",
    str_detect(dataset_lower, "refseq") ~ "RefSeq",
    TRUE ~ dataset_name
  )

  paste(kingdom_clean, db_label, "database")
}

plot_subtitle <- make_dataset_subtitle(dataset_name, kingdom_label)

# -----------------------------
# Fixed colour maps by taxa
# -----------------------------
get_fungal_color_map <- function() {
  c(
    "Epichloe"            = "#0072B2", # blue
    "Aspergillus"         = "#E69F00", # orange
    "Saccharomyces"       = "#56B4E9", # sky blue
    "Candida"             = "#009E73", # bluish green
    "Venturia"            = "#CC79A7", # reddish purple
    "Lodderomyces"        = "#F0E442", # yellow
    "Coccidioides"        = "#D55E00", # vermillion
    "Lachancea"           = "#332288", # blue-purple
    "Botrytis"            = "#88CCEE", # light blue
    "Sphaerulina"         = "#117733", # green
    "Schizosaccharomyces" = "#AA4499", # magenta
    "Kwoniella"           = "#DDCC77", # sand
    "Fusarium"            = "#44AA99", # teal
    "Trichoderma"         = "#CC6677", # rose
    "Nakaseomyces"        = "#882255"  # wine
  )
}

get_viral_color_map <- function() {
  c(
    "Oryzopoxvirus"         = "#0072B2", # blue
    "Alphapapillomavirus"  = "#E69F00", # orange
    "Cukevirus"            = "#56B4E9", # sky blue
    "Epseptimavirus"       = "#009E73", # bluish green
    "Shenzhenivirus"       = "#CC79A7", # reddish purple
    "Cytomegalovirus"      = "#F0E442", # yellow
    "Aurunvirus"           = "#D55E00", # vermillion
    "Moonvirus"            = "#332288", # blue-purple
    "Gelderlandvirus"      = "#88CCEE", # light blue
    "Rockvillevirus"       = "#117733", # green
    "Spinunavirus"         = "#AA4499", # magenta
    "Orthoflavivirus"      = "#DDCC77", # sand
    "Gettysburgvirus"      = "#44AA99", # teal
    "Schiekvirus"          = "#CC6677"  # rose
  )
}

get_plot_colors <- function(top_taxa, kingdom_label) {
  if (tolower(kingdom_label) == "fungal") {
    fixed_map <- get_fungal_color_map()
  } else if (tolower(kingdom_label) == "viral") {
    fixed_map <- get_viral_color_map()
  } else {
    stop("kingdom_label must be 'Fungal' or 'Viral'")
  }

  fallback_pool <- c(
    "#0072B2", "#E69F00", "#56B4E9", "#009E73", "#CC79A7",
    "#F0E442", "#D55E00", "#332288", "#88CCEE", "#117733",
    "#AA4499", "#DDCC77", "#44AA99", "#CC6677", "#882255"
  )

  used_cols <- unname(fixed_map)
  unused_fallback <- fallback_pool[!fallback_pool %in% used_cols]

  missing_taxa <- setdiff(top_taxa, names(fixed_map))

  if (length(missing_taxa) > 0) {
    if (length(missing_taxa) > length(unused_fallback)) {
      stop("Not enough unique fallback colours for unexpected taxa.")
    }

    extra_map <- unused_fallback[seq_along(missing_taxa)]
    names(extra_map) <- missing_taxa
    fixed_map <- c(fixed_map, extra_map)
  }

  plot_colors <- c(
    fixed_map[top_taxa],
    "Other" = "#BDBDBD"
  )

  return(plot_colors)
}

# -----------------------------
# Read matrix
# -----------------------------
cat("Reading matrix:", matrix_file, "\n")
mat <- fread(matrix_file, data.table = FALSE)

if (ncol(mat) < 2) {
  stop("Matrix appears to have fewer than 2 columns.")
}

sample_col_matrix <- colnames(mat)[1]
cat("Assuming first matrix column is sample ID:", sample_col_matrix, "\n")

mat_df <- mat %>%
  as.data.frame()

rownames(mat_df) <- trimws(as.character(mat_df[[sample_col_matrix]]))
mat_df[[sample_col_matrix]] <- NULL
mat_df[] <- lapply(mat_df, as.numeric)
mat_df[is.na(mat_df)] <- 0

mat_df <- mat_df[, colSums(mat_df) > 0, drop = FALSE]

if (ncol(mat_df) == 0) {
  stop("No non-zero taxa remain in the matrix.")
}

# -----------------------------
# Read metadata
# -----------------------------
cat("Reading metadata:", metadata_file, "\n")
meta <- readxl::read_excel(metadata_file)

# Rename the first unnamed column to sample_label
colnames(meta)[1] <- "sample_label"

required_cols <- c("sample_label", "reads_ID", "Ges_del_days")
missing_cols <- setdiff(required_cols, colnames(meta))
if (length(missing_cols) > 0) {
  stop("Metadata is missing required column(s): ", paste(missing_cols, collapse = ", "))
}

meta <- meta %>%
  mutate(
    sample_label = trimws(as.character(sample_label)),
    reads_ID = trimws(as.character(reads_ID)),
    Ges_del_days = suppressWarnings(as.numeric(Ges_del_days)),
    birth_age_group = make_birth_age_group(Ges_del_days)
  )

# -----------------------------
# Match samples between matrix and metadata
# -----------------------------
matrix_ids_raw <- rownames(mat_df)
matrix_ids_clean <- sub("_1$", "", matrix_ids_raw)

cat("Example matrix IDs (raw):\n")
print(head(matrix_ids_raw, 5))
cat("Example matrix IDs (cleaned):\n")
print(head(matrix_ids_clean, 5))
cat("Example metadata reads_ID values:\n")
print(head(meta$reads_ID, 5))

common_samples <- intersect(matrix_ids_clean, meta$reads_ID)

if (length(common_samples) == 0) {
  stop("No overlapping samples found between cleaned matrix IDs and metadata reads_ID.")
}

cat("Number of overlapping samples:", length(common_samples), "\n")

keep_mat <- matrix_ids_clean %in% common_samples
mat_df <- mat_df[keep_mat, , drop = FALSE]
matrix_ids_clean <- matrix_ids_clean[keep_mat]

meta <- meta %>% filter(reads_ID %in% common_samples)
meta <- meta[match(matrix_ids_clean, meta$reads_ID), , drop = FALSE]

stopifnot(all(matrix_ids_clean == meta$reads_ID))

rownames(mat_df) <- matrix_ids_clean

keep <- !is.na(meta$birth_age_group)
mat_df <- mat_df[keep, , drop = FALSE]
meta   <- meta[keep, , drop = FALSE]

if (nrow(mat_df) == 0) {
  stop("No samples remain after filtering to non-missing birth age group.")
}

stopifnot(all(rownames(mat_df) == meta$reads_ID))

# -----------------------------
# Sample QC
# -----------------------------
sample_totals <- rowSums(mat_df)

qc_df <- data.frame(
  sample_label = meta$sample_label,
  reads_ID = rownames(mat_df),
  total_counts = sample_totals,
  Ges_del_days = meta$Ges_del_days,
  birth_age_group = meta$birth_age_group,
  stringsAsFactors = FALSE
)

write_tsv_safe(qc_df, file.path(output_dir, paste0(dataset_name, "_sample_qc.tsv")))

group_counts <- meta %>%
  count(birth_age_group, name = "n_samples") %>%
  arrange(factor(birth_age_group, levels = birth_group_levels))

write_tsv_safe(group_counts, file.path(output_dir, paste0(dataset_name, "_birth_age_group_counts.tsv")))

# -----------------------------
# Convert to relative abundance
# -----------------------------
mat_rel <- sweep(mat_df, 1, rowSums(mat_df), FUN = "/") * 100
mat_rel[is.na(mat_rel)] <- 0

# -----------------------------
# Select top 10 globally abundant taxa
# -----------------------------
top_n <- 10

global_abundance <- colSums(mat_rel)
top_taxa <- names(sort(global_abundance, decreasing = TRUE))[seq_len(min(top_n, length(global_abundance)))]

top_taxa_df <- data.frame(
  dataset = dataset_name,
  kingdom = kingdom_label,
  rank_used = "matrix_column_name",
  top_rank = seq_along(top_taxa),
  taxon = top_taxa,
  global_relative_abundance_sum = as.numeric(sort(global_abundance, decreasing = TRUE)[seq_along(top_taxa)]),
  stringsAsFactors = FALSE
)

write_tsv_safe(top_taxa_df, file.path(output_dir, paste0(dataset_name, "_top10_taxa.tsv")))

# -----------------------------
# Long table for plotting
# -----------------------------
plot_df <- mat_rel %>%
  as.data.frame() %>%
  tibble::rownames_to_column("reads_ID") %>%
  pivot_longer(
    cols = -reads_ID,
    names_to = "taxon",
    values_to = "relative_abundance"
  ) %>%
  left_join(
    meta %>% select(sample_label, reads_ID, Ges_del_days, birth_age_group),
    by = "reads_ID"
  ) %>%
  mutate(
    taxon_top10 = if_else(taxon %in% top_taxa, taxon, "Other")
  ) %>%
  group_by(sample_label, reads_ID, Ges_del_days, birth_age_group, taxon_top10) %>%
  summarise(relative_abundance = sum(relative_abundance), .groups = "drop")

# -----------------------------
# Clean plotting data
# -----------------------------
plot_df <- plot_df %>%
  filter(
    !is.na(relative_abundance),
    !is.na(birth_age_group),
    !is.na(sample_label)
  ) %>%
  mutate(
    relative_abundance = pmin(relative_abundance, 100),
    relative_abundance = pmax(relative_abundance, 0)
  )

# -----------------------------
# Order taxa and birth groups
# -----------------------------
taxon_levels <- c(top_taxa, "Other")

plot_df <- plot_df %>%
  mutate(
    taxon_top10 = factor(taxon_top10, levels = taxon_levels),
    birth_age_group = factor(birth_age_group, levels = birth_group_levels)
  )

# -----------------------------
# Order samples within each facet
# -----------------------------
sample_order <- meta %>%
  arrange(
    factor(birth_age_group, levels = birth_group_levels),
    Ges_del_days,
    reads_ID
  ) %>%
  pull(sample_label)

plot_df$sample_label <- factor(plot_df$sample_label, levels = sample_order)

# -----------------------------
# Save plotting table
# -----------------------------
write_tsv_safe(plot_df, file.path(output_dir, paste0(dataset_name, "_top10_plus_other_plot_table.tsv")))

# -----------------------------
# Set colors
# Grey reserved for Other
# -----------------------------
plot_colors <- get_plot_colors(top_taxa, kingdom_label)

# -----------------------------
# Main stacked barplot
# -----------------------------
p <- ggplot(plot_df, aes(x = sample_label, y = relative_abundance, fill = taxon_top10)) +
  geom_bar(stat = "identity", width = 0.95, color = NA) +
  facet_grid(~ birth_age_group, scales = "free_x", space = "free_x") +
  scale_fill_manual(values = plot_colors, drop = FALSE) +
  scale_y_continuous(
    breaks = seq(0, 100, by = 20),
    expand = c(0, 0)
  ) +
  labs(
    title = paste0(kingdom_label, " composition"),
    subtitle = plot_subtitle,
    x = NULL,
    y = "Relative abundance (%)",
    fill = "Taxon"
  ) +
  theme_bw(base_size = 12) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1, size = 7),
    strip.background = element_rect(fill = "white", color = "black"),
    strip.text = element_text(face = "bold"),
    legend.position = "right",
    legend.title = element_text(face = "bold")
  )

ggsave(
  filename = file.path(output_dir, paste0(dataset_name, "_top10_plus_other_barplot.png")),
  plot = p,
  width = 16,
  height = 7,
  dpi = 300
)

ggsave(
  filename = file.path(output_dir, paste0(dataset_name, "_top10_plus_other_barplot.pdf")),
  plot = p,
  width = 16,
  height = 7
)

# -----------------------------
# Version without sample labels
# -----------------------------
p_nolabel <- p +
  theme(
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank()
  )

ggsave(
  filename = file.path(output_dir, paste0(dataset_name, "_top10_plus_other_barplot_no_xlabels.png")),
  plot = p_nolabel,
  width = 16,
  height = 7,
  dpi = 300
)

# -----------------------------
# Average composition by birth age group
# -----------------------------
avg_df <- plot_df %>%
  group_by(birth_age_group, taxon_top10) %>%
  summarise(mean_relative_abundance = mean(relative_abundance), .groups = "drop") %>%
  mutate(
    birth_age_group = factor(birth_age_group, levels = birth_group_levels),
    taxon_top10 = factor(taxon_top10, levels = taxon_levels)
  )

write_tsv_safe(avg_df, file.path(output_dir, paste0(dataset_name, "_group_mean_top10_plus_other.tsv")))

p_avg <- ggplot(avg_df, aes(x = birth_age_group, y = mean_relative_abundance, fill = taxon_top10)) +
  geom_bar(stat = "identity", width = 0.8) +
  scale_fill_manual(values = plot_colors, drop = FALSE) +
  scale_y_continuous(
    breaks = seq(0, 100, by = 20),
    expand = c(0, 0)
  ) +
  labs(
    title = paste0(kingdom_label, " composition"),
    subtitle = plot_subtitle,
    x = NULL,
    y = "Mean relative abundance (%)",
    fill = "Taxon"
  ) +
  theme_bw(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "right",
    legend.title = element_text(face = "bold")
  )

ggsave(
  filename = file.path(output_dir, paste0(dataset_name, "_group_mean_top10_plus_other_barplot.png")),
  plot = p_avg,
  width = 10,
  height = 6,
  dpi = 300
)

cat("Finished successfully for:", dataset_name, "\n")
