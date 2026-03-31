#!/usr/bin/env Rscript

library(ggplot2)
library(readr)

# Input file
input_file <- "/scratch/prj/rosetree/Valentina/results/downstream/genbank/filtered/genbank_fungal_genus.taxon_summary_after_total_filter.tsv"

# Output plot
output_file <- "/scratch/prj/rosetree/Valentina/results/downstream/genbank/summary/fungal_prevalence_vs_abundance.png"

# Load data
df <- read_tsv(input_file)

# Plot
p <- ggplot(df, aes(x = total_count, y = prevalence_fraction)) +
  geom_point(alpha = 0.6, size = 2) +
  scale_x_log10() +
  geom_hline(yintercept = 0.05, linetype = "dashed") +
  labs(
    title = "Fungal genera: prevalence vs abundance",
    x = "Total abundance (log scale)",
    y = "Prevalence (fraction of samples)"
  ) +
  theme_minimal()

# Save plot
ggsave(output_file, p, width = 7, height = 5)

cat("Plot saved to:", output_file, "\n")
