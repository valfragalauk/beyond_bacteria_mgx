#!/usr/bin/env Rscript

# PURPOSE:
# Generate sample-level descriptive summaries for filtered
# genus-level fungal or viral count matrices.
#
# Current output:
# 1) Sample total counts histogram
#    - Shows how much signal remains per sample after filtering
#    - Used as a sparsity / QC / interpretation plot
#
# INPUT:
# - Filtered genus-level count matrix (samples x taxa)
# - Metadata Excel file with sample_label, reads_ID, and Ges_del_days
#
# OUTPUT:
# - Sample total count tables
# - Sample total count histogram

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(readxl)
  library(scales)
  library(glue)
})

# ============================================================
# 1. PARSE COMMAND LINE ARGUMENTS
# ============================================================

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 8) {
  stop(
    paste(
      "Expected 8 arguments:",
      "1=input_matrix",
      "2=metadata_xlsx",
      "3=output_base_dir",
      "4=dataset_id",
      "5=kingdom_label",
      "6=database_label",
      "7=top_n_taxa_unused",
      "8=metadata_sheet_or_AUTO",
      sep = "\n"
    )
  )
}

input_matrix    <- args[1]
metadata_xlsx   <- args[2]
output_base_dir <- args[3]
dataset_id      <- args[4]
kingdom_label   <- args[5]
database_label  <- args[6]
top_n_taxa      <- args[7]   # kept only so the SLURM script does not need changing
metadata_sheet  <- args[8]

if (!tolower(kingdom_label) %in% c("fungal", "viral")) {
  stop("kingdom_label must be 'Fungal' or 'Viral'")
}

# ============================================================
# 2. OUTPUT DIRECTORY
# ============================================================

sample_totals_dir <- file.path(output_base_dir, "sample_totals", dataset_id)
dir.create(sample_totals_dir, recursive = TRUE, showWarnings = FALSE)

# ============================================================
# 3. READ METADATA
# ============================================================

read_metadata_safely <- function(xlsx_path, sheet_choice = "AUTO") {

  rename_first_col_if_needed <- function(df) {
    if (ncol(df) > 0) {
      first_col_name <- colnames(df)[1]

      if (is.na(first_col_name) ||
          first_col_name == "" ||
          grepl("^Unnamed", first_col_name, ignore.case = TRUE) ||
          grepl("^\\.\\.\\.[0-9]+$", first_col_name)) {
        colnames(df)[1] <- "sample_label"
      }
    }
    df
  }

  if (sheet_choice == "AUTO") {
    sheets <- excel_sheets(xlsx_path)

    for (sh in sheets) {
      tmp <- read_excel(xlsx_path, sheet = sh, .name_repair = "unique")
      tmp <- rename_first_col_if_needed(tmp)

      if (all(c("sample_label", "reads_ID", "Ges_del_days") %in% colnames(tmp))) {
        return(tmp)
      }
    }

    stop("Could not find a metadata sheet containing sample_label, reads_ID, and Ges_del_days.")
  } else {
    tmp <- read_excel(xlsx_path, sheet = sheet_choice, .name_repair = "unique")
    tmp <- rename_first_col_if_needed(tmp)

    if (!all(c("sample_label", "reads_ID", "Ges_del_days") %in% colnames(tmp))) {
      stop("Chosen metadata sheet does not contain sample_label, reads_ID, and Ges_del_days.")
    }

    return(tmp)
  }
}

metadata <- read_metadata_safely(metadata_xlsx, metadata_sheet) %>%
  mutate(
    sample_label = as.character(sample_label),
    reads_ID     = as.character(reads_ID),
    Ges_del_days = as.numeric(Ges_del_days)
  ) %>%
  select(sample_label, reads_ID, Ges_del_days) %>%
  distinct()

# ============================================================
# 4. DEFINE DELIVERY GROUPS
# ============================================================

assign_delivery_group <- function(days) {
  case_when(
    is.na(days) ~ NA_character_,
    days < 239 ~ "34 sPTB",
    days >= 239 & days <= 259 ~ "37 sPTB",
    days > 259 ~ "Term"
  )
}

metadata <- metadata %>%
  mutate(
    delivery_group = assign_delivery_group(Ges_del_days)
  ) %>%
  filter(!is.na(Ges_del_days), !is.na(delivery_group)) %>%
  mutate(
    delivery_group = factor(
      delivery_group,
      levels = c("34 sPTB", "37 sPTB", "Term")
    )
  )

# ============================================================
# 5. READ COUNT MATRIX
# ============================================================

mat <- read.delim(
  input_matrix,
  check.names = FALSE,
  stringsAsFactors = FALSE
)

if (ncol(mat) < 2) {
  stop("Input matrix must contain at least one sample ID column and one taxon column.")
}

# Some matrices have a blank first column header
colnames(mat)[1] <- "matrix_sample_id"

mat <- mat %>%
  mutate(
    matrix_sample_id = as.character(matrix_sample_id),
    cleaned_reads_ID = sub("_1$", "", matrix_sample_id)
  )

taxa_cols <- setdiff(colnames(mat), c("matrix_sample_id", "cleaned_reads_ID"))
mat[taxa_cols] <- lapply(mat[taxa_cols], as.numeric)

# ============================================================
# 6. MATCHING: MATRIX <-> METADATA
# ============================================================

common_ids <- intersect(mat$cleaned_reads_ID, metadata$reads_ID)

cat("Samples in matrix before matching:", nrow(mat), "\n")
cat("Samples in metadata before matching:", nrow(metadata), "\n")
cat("Samples shared between matrix and metadata:", length(common_ids), "\n")

if (length(common_ids) == 0) {
  stop("No shared sample IDs found between cleaned matrix IDs and metadata reads_ID.")
}

mat_matched <- mat %>%
  filter(cleaned_reads_ID %in% common_ids)

metadata_matched <- metadata[match(mat_matched$cleaned_reads_ID, metadata$reads_ID), ]

if (nrow(mat_matched) != nrow(metadata_matched)) {
  stop("Matrix and metadata row counts do not match after alignment.")
}

if (!all(mat_matched$cleaned_reads_ID == metadata_matched$reads_ID)) {
  stop("Matrix and metadata are not aligned correctly after matching.")
}

rownames(mat_matched) <- mat_matched$cleaned_reads_ID

dat <- bind_cols(
  metadata_matched %>% select(sample_label, reads_ID, Ges_del_days, delivery_group),
  mat_matched %>% select(all_of(taxa_cols))
)

cat("Samples retained after strict matching and metadata filtering:", nrow(dat), "\n")

# ============================================================
# 7. SAMPLE TOTAL COUNTS
# ============================================================

sample_totals <- dat %>%
  mutate(
    total_filtered_counts = rowSums(across(all_of(taxa_cols)), na.rm = TRUE)
  ) %>%
  select(sample_label, reads_ID, Ges_del_days, delivery_group, total_filtered_counts) %>%
  arrange(total_filtered_counts)

write.table(
  sample_totals,
  file = file.path(sample_totals_dir, glue("{dataset_id}_sample_total_counts.tsv")),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

sample_totals_summary <- sample_totals %>%
  summarise(
    n_samples               = n(),
    min_total               = min(total_filtered_counts, na.rm = TRUE),
    q1_total                = quantile(total_filtered_counts, 0.25, na.rm = TRUE),
    median_total            = median(total_filtered_counts, na.rm = TRUE),
    mean_total              = mean(total_filtered_counts, na.rm = TRUE),
    q3_total                = quantile(total_filtered_counts, 0.75, na.rm = TRUE),
    max_total               = max(total_filtered_counts, na.rm = TRUE),
    zero_count_samples      = sum(total_filtered_counts == 0, na.rm = TRUE),
    prop_zero_count_samples = mean(total_filtered_counts == 0, na.rm = TRUE)
  )

write.table(
  sample_totals_summary,
  file = file.path(sample_totals_dir, glue("{dataset_id}_sample_total_counts_summary.tsv")),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

# ============================================================
# 8. SAMPLE TOTALS HISTOGRAM
# ============================================================
# This is after filtering
# A log10 scale was applied because sample counts spanned a wide range, allowing both low- and high-count samples to be visualised clearly.

p_hist <- ggplot(sample_totals, aes(x = total_filtered_counts)) +
  geom_histogram(
    bins = 18,
    fill = "#56B4E9",
    colour = "white",
    linewidth = 0.4
  ) +
  scale_x_log10(labels = comma_format()) +
  labs(
    title = glue("{kingdom_label} sample totals"),
    subtitle = glue("{kingdom_label} {database_label} database"),
    x = "Total filtered counts per sample (log10 scale)",
    y = "Number of samples"
  ) +
  theme_gray(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold"),
    plot.subtitle = element_text(size = 12),
    panel.grid.minor = element_blank()
  )

ggsave(
  filename = file.path(sample_totals_dir, glue("{dataset_id}_sample_total_counts_histogram.pdf")),
  plot = p_hist,
  width = 8,
  height = 6
)

ggsave(
  filename = file.path(sample_totals_dir, glue("{dataset_id}_sample_total_counts_histogram.png")),
  plot = p_hist,
  width = 8,
  height = 6,
  dpi = 300
)

# ============================================================
# 9. SAMPLE LABEL KEY
# ============================================================

sample_label_key <- dat %>%
  select(sample_label, reads_ID, Ges_del_days, delivery_group) %>%
  distinct()

write.table(
  sample_label_key,
  file = file.path(sample_totals_dir, glue("{dataset_id}_sample_label_key.tsv")),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

cat("Completed:", dataset_id, "\n")
