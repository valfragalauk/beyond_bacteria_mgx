#!/usr/bin/env Rscript


#Plotting the alpha diversity shannon index with Term vs sPTB with both databases

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(grid)
})

INPUT_DIR  <- "/scratch/prj/rosetree/Valentina/results/downstream/alpha_diversity"
OUTPUT_DIR <- "/scratch/prj/rosetree/Valentina/results/downstream/alpha_diversity/plots"

dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

alpha_files <- c(
  file.path(INPUT_DIR, "genbank_viral_alpha_diversity_per_sample.tsv"),
  file.path(INPUT_DIR, "genbank_fungal_alpha_diversity_per_sample.tsv"),
  file.path(INPUT_DIR, "refseq_viral_alpha_diversity_per_sample.tsv"),
  file.path(INPUT_DIR, "refseq_fungal_alpha_diversity_per_sample.tsv")
)

stats_files <- c(
  file.path(INPUT_DIR, "genbank_viral_alpha_diversity_TERM_vs_sPTB_stats.tsv"),
  file.path(INPUT_DIR, "genbank_fungal_alpha_diversity_TERM_vs_sPTB_stats.tsv"),
  file.path(INPUT_DIR, "refseq_viral_alpha_diversity_TERM_vs_sPTB_stats.tsv"),
  file.path(INPUT_DIR, "refseq_fungal_alpha_diversity_TERM_vs_sPTB_stats.tsv")
)

read_alpha_file <- function(path) {
  df <- read.delim(path, check.names = FALSE, stringsAsFactors = FALSE)
  file_name <- basename(path)

  database <- if (grepl("^genbank_", file_name)) {
    "GenBank"
  } else if (grepl("^refseq_", file_name)) {
    "RefSeq"
  } else {
    stop("Could not determine database from filename: ", file_name)
  }

  kingdom <- if (grepl("_viral_", file_name)) {
    "Viral"
  } else if (grepl("_fungal_", file_name)) {
    "Fungal"
  } else {
    stop("Could not determine kingdom from filename: ", file_name)
  }

  df$database <- database
  df$kingdom  <- kingdom
  df
}

read_stats_file <- function(path) {
  df <- read.delim(path, check.names = FALSE, stringsAsFactors = FALSE)
  file_name <- basename(path)

  database <- if (grepl("^genbank_", file_name)) {
    "GenBank"
  } else if (grepl("^refseq_", file_name)) {
    "RefSeq"
  } else {
    stop("Could not determine database from filename: ", file_name)
  }

  kingdom <- if (grepl("_viral_", file_name)) {
    "Viral"
  } else if (grepl("_fungal_", file_name)) {
    "Fungal"
  } else {
    stop("Could not determine kingdom from filename: ", file_name)
  }

  df$database <- database
  df$kingdom  <- kingdom
  df
}

combined <- bind_rows(lapply(alpha_files, read_alpha_file)) %>%
  filter(!is.na(outcome), !is.na(shannon)) %>%
  mutate(
    outcome = factor(outcome, levels = c("TERM", "sPTB"), labels = c("Term", "sPTB")),
    kingdom = factor(kingdom, levels = c("Viral", "Fungal")),
    database = factor(database, levels = c("GenBank", "RefSeq"))
  ) %>%
  mutate(
    color_group = case_when(
      kingdom == "Viral"  & outcome == "Term" ~ "viral_Term",
      kingdom == "Viral"  & outcome == "sPTB" ~ "viral_sPTB",
      kingdom == "Fungal" & outcome == "Term" ~ "fungal_Term",
      kingdom == "Fungal" & outcome == "sPTB" ~ "fungal_sPTB",
      TRUE ~ NA_character_
    )
  )

stats_df <- bind_rows(lapply(stats_files, read_stats_file)) %>%
  filter(metric == "shannon") %>%
  mutate(
    label = ifelse(
      test_used == "t_test",
      paste0("t-test p = ", formatC(p_value, format = "f", digits = 3)),
      paste0("Wilcoxon p = ", formatC(p_value, format = "f", digits = 3))
    )
  ) %>%
  select(database, kingdom, label)

label_positions <- combined %>%
  group_by(database, kingdom) %>%
  summarise(
    y = max(shannon, na.rm = TRUE) * 1.08,
    .groups = "drop"
  )

stats_df <- left_join(stats_df, label_positions, by = c("database", "kingdom"))

color_map <- c(
  "viral_Term"  = "#0072B2",
  "viral_sPTB"  = "#E69F00",
  "fungal_Term" = "#009E73",
  "fungal_sPTB" = "#CC79A7"
)

make_database_plot <- function(df, stats_annot, db_name, outfile) {
  plot_df <- df %>% filter(database == db_name)
  annot_df <- stats_annot %>% filter(database == db_name)

  p <- ggplot(plot_df, aes(x = outcome, y = shannon, colour = color_group)) +
    geom_boxplot(
      width = 0.55,
      fill = NA,
      linewidth = 0.4,
      outlier.shape = NA
    ) +
    geom_jitter(
      width = 0.10,
      size = 1.5,
      alpha = 0.75
    ) +
    geom_text(
      data = annot_df,
      aes(x = 1.5, y = y, label = label),
      inherit.aes = FALSE,
      size = 3.8
    ) +
    facet_wrap(~ kingdom, nrow = 1, scales = "free_y") +
    scale_colour_manual(values = color_map) +
    expand_limits(y = max(annot_df$y, na.rm = TRUE) * 1.03) +
    labs(
      title = db_name,
      x = NULL,
      y = "Shannon diversity index"
    ) +
    theme_classic(base_size = 13) +
    theme(
      plot.title = element_text(size = 16, face = "plain", hjust = 0.5),
      strip.text = element_text(size = 13, face = "plain"),
      axis.title.y = element_text(size = 13),
      axis.text.x = element_text(size = 11),
      axis.text.y = element_text(size = 11),
      axis.line = element_line(linewidth = 0.3, colour = "black"),
      axis.ticks = element_line(linewidth = 0.3, colour = "black"),
      legend.position = "none",
      panel.spacing = unit(1.2, "lines")
    )

  ggsave(
    filename = outfile,
    plot = p,
    width = 8.5,
    height = 4.8,
    dpi = 300,
    bg = "white"
  )
}

make_database_plot(
  df = combined,
  stats_annot = stats_df,
  db_name = "GenBank",
  outfile = file.path(OUTPUT_DIR, "alpha_diversity_shannon_index_GenBank.png")
)

make_database_plot(
  df = combined,
  stats_annot = stats_df,
  db_name = "RefSeq",
  outfile = file.path(OUTPUT_DIR, "alpha_diversity_shannon_index_RefSeq.png")
)

message("Alpha diversity plots created successfully.")
