#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(ggplot2)
})

# -----------------------------
# Paths
# -----------------------------
meta_path <- "/scratch/prj/rosetree/Valentina/results/downstream/metadata_clean/metadata_clean.tsv"
out_dir   <- "/scratch/prj/rosetree/Valentina/results/downstream/cohort_summary"

table_out   <- file.path(out_dir, "cohort_table1.tsv")
bmi_hist_out <- file.path(out_dir, "bmi_histogram.png")
bmi_box_out  <- file.path(out_dir, "bmi_boxplot_by_outcome.png")
audit_out     <- file.path(out_dir, "table1_pvalue_audit.tsv")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# -----------------------------
# Read metadata
# -----------------------------
meta <- read.delim(meta_path, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)

meta$outcome <- factor(meta$outcome, levels = c("TERM", "sPTB"))

# -----------------------------
# IMD rank
# -----------------------------
if (!("IMD_rank" %in% names(meta))) {
  stop("IMD_rank is not present in metadata_clean.tsv. Add it to the metadata cleaning step first.")
}

meta$IMD_rank <- suppressWarnings(as.numeric(meta$IMD_rank))

# -----------------------------
# Plot colours 
# -----------------------------
term_col <- "#0072B2"
sptb_col <- "#E69F00"

# -----------------------------
# Helper functions
# -----------------------------
fmt_mean_sd_n <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) return("NA")
  sprintf("%.2f ± %.2f\n(n=%d)", mean(x), sd(x), length(x))
}

fmt_n_pct <- function(x, level) {
  x_nonmiss <- x[!is.na(x)]
  n_total <- length(x_nonmiss)
  if (n_total == 0) return("0 (0.00%)")
  n_level <- sum(x_nonmiss == level)
  sprintf("%d (%.2f%%)", n_level, 100 * n_level / n_total)
}

safe_wilcox <- function(x, group) {
  dat <- data.frame(x = x, group = group)
  dat <- dat[!is.na(dat$x) & !is.na(dat$group), , drop = FALSE]
  if (length(unique(dat$group)) != 2) return(NA_real_)
  tryCatch(wilcox.test(x ~ group, data = dat, exact = FALSE)$p.value,
           error = function(e) NA_real_)
}

fmt_p <- function(p) {
  if (is.na(p)) return("")
  if (p < 0.001) return(sprintf("%.6f", p))
  sprintf("%.3f", p)
}

add_continuous_row <- function(df, var, label, p_display) {
  data.frame(
    Variable = label,
    TERM = fmt_mean_sd_n(df[df$outcome == "TERM", var]),
    sPTB = fmt_mean_sd_n(df[df$outcome == "sPTB", var]),
    Total = fmt_mean_sd_n(df[[var]]),
    P_value = p_display,
    stringsAsFactors = FALSE
  )
}

add_section_header <- function(label, p_display = "") {
  data.frame(
    Variable = label,
    TERM = "",
    sPTB = "",
    Total = "",
    P_value = p_display,
    stringsAsFactors = FALSE
  )
}

add_level_row <- function(df, var, level, label = NULL) {
  if (is.null(label)) label <- paste0("  ", level)

  data.frame(
    Variable = label,
    TERM = fmt_n_pct(df[df$outcome == "TERM", var], level),
    sPTB = fmt_n_pct(df[df$outcome == "sPTB", var], level),
    Total = fmt_n_pct(df[[var]], level),
    P_value = "",
    stringsAsFactors = FALSE
  )
}

# -----------------------------
# P-values for continuous vars only
# -----------------------------
cont_tests <- c(
  age = safe_wilcox(meta$age, meta$outcome),
  bmi = safe_wilcox(meta$bmi, meta$outcome),
  IMD_rank = safe_wilcox(meta$IMD_rank, meta$outcome)
)

cont_padj <- p.adjust(cont_tests, method = "BH")
cont_p_display <- setNames(vapply(cont_tests, fmt_p, character(1)), names(cont_tests))

# -----------------------------
# Build table
# -----------------------------
rows <- list()

# Continuous variables with p-values
rows[[length(rows) + 1]] <- add_continuous_row(meta, "age", "Maternal age\n(mean ± sd)", cont_p_display["age"])
rows[[length(rows) + 1]] <- add_continuous_row(meta, "bmi", "BMI\n(mean ± sd)", cont_p_display["bmi"])
rows[[length(rows) + 1]] <- add_continuous_row(meta, "IMD_rank", "IMD rank\n(mean ± sd)", cont_p_display["IMD_rank"])

# Risk
if ("Risk" %in% names(meta)) {
  rows[[length(rows) + 1]] <- add_section_header("Risk status at enrolment", "")
  risk_levels <- c("High risk", "Low risk")
  risk_levels <- risk_levels[risk_levels %in% unique(meta$Risk)]
  for (lvl in risk_levels) {
    rows[[length(rows) + 1]] <- add_level_row(meta, "Risk", lvl, paste0("  ", lvl))
  }
}

# Smoking
if ("smoking" %in% names(meta)) {
  rows[[length(rows) + 1]] <- add_section_header("Smoking status", "")
  smoking_levels <- c("Current", "Ex - gave up before pregnancy", "Never")
  smoking_levels <- smoking_levels[smoking_levels %in% unique(meta$smoking)]
  for (lvl in smoking_levels) {
    rows[[length(rows) + 1]] <- add_level_row(meta, "smoking", lvl, paste0("  ", lvl))
  }
}

# sPTB category
rows[[length(rows) + 1]] <- add_section_header("sPTB category", "")

rows[[length(rows) + 1]] <- data.frame(
  Variable = "  Term",
  TERM = sprintf("%d (100%%)", sum(meta$outcome == "TERM", na.rm = TRUE)),
  sPTB = "",
  Total = sprintf("%d (%.2f%%)",
                  sum(meta$outcome == "TERM", na.rm = TRUE),
                  100 * sum(meta$outcome == "TERM", na.rm = TRUE) / nrow(meta)),
  P_value = "",
  stringsAsFactors = FALSE
)

rows[[length(rows) + 1]] <- data.frame(
  Variable = "  Early sPTB (sPTB34)",
  TERM = "",
  sPTB = sprintf("%d (%.2f%%)",
                 sum(meta$outcome == "sPTB" & meta$sPTB34 == "yes", na.rm = TRUE),
                 100 * sum(meta$outcome == "sPTB" & meta$sPTB34 == "yes", na.rm = TRUE) /
                   sum(meta$outcome == "sPTB", na.rm = TRUE)),
  Total = sprintf("%d (%.2f%%)",
                  sum(meta$sPTB34 == "yes", na.rm = TRUE),
                  100 * sum(meta$sPTB34 == "yes", na.rm = TRUE) / nrow(meta)),
  P_value = "",
  stringsAsFactors = FALSE
)

rows[[length(rows) + 1]] <- data.frame(
  Variable = "  Late sPTB (sPTB37)",
  TERM = "",
  sPTB = sprintf("%d (%.2f%%)",
                 sum(meta$outcome == "sPTB" & meta$sPTB34 == "no", na.rm = TRUE),
                 100 * sum(meta$outcome == "sPTB" & meta$sPTB34 == "no", na.rm = TRUE) /
                   sum(meta$outcome == "sPTB", na.rm = TRUE)),
  Total = sprintf("%d (%.2f%%)",
                  sum(meta$outcome == "sPTB" & meta$sPTB34 == "no", na.rm = TRUE),
                  100 * sum(meta$outcome == "sPTB" & meta$sPTB34 == "no", na.rm = TRUE) / nrow(meta)),
  P_value = "",
  stringsAsFactors = FALSE
)

table1 <- do.call(rbind, rows)

write.table(
  table1,
  file = table_out,
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

# -----------------------------
# BMI plots
# -----------------------------
plot_df <- meta[!is.na(meta$bmi) & !is.na(meta$outcome), , drop = FALSE]
plot_df$outcome_plot <- factor(plot_df$outcome, levels = c("TERM", "sPTB"), labels = c("Term", "sPTB"))
plot_df$color_group <- ifelse(plot_df$outcome_plot == "Term", "Term", "sPTB")

color_map <- c(
  "Term" = term_col,
  "sPTB" = sptb_col
)

p_hist <- ggplot(plot_df, aes(x = bmi)) +
  geom_histogram(
    bins = 20,
    fill = "#0072B2",
    colour = "black",
    linewidth = 0.3
  ) +
  labs(
    title = "BMI distribution",
    x = "BMI",
    y = "Count"
  ) +
  theme_classic(base_size = 13) +
  theme(
    plot.title = element_text(size = 16, face = "plain", hjust = 0.5),
    axis.title = element_text(size = 13),
    axis.text = element_text(size = 11),
    axis.line = element_line(linewidth = 0.3, colour = "black"),
    axis.ticks = element_line(linewidth = 0.3, colour = "black")
  )

ggsave(
  filename = bmi_hist_out,
  plot = p_hist,
  width = 7.2,
  height = 4.8,
  dpi = 300,
  bg = "white"
)

p_box <- ggplot(plot_df, aes(x = outcome_plot, y = bmi, colour = color_group)) +
  geom_boxplot(
    width = 0.55,
    fill = NA,
    linewidth = 0.4,
    outlier.shape = NA
  ) +
  geom_jitter(
    width = 0.10,
    size = 2.0,
    alpha = 0.75
  ) +
  scale_colour_manual(values = color_map) +
  labs(
    title = "BMI by outcome",
    x = "Outcome",
    y = "BMI"
  ) +
  theme_classic(base_size = 13) +
  theme(
    plot.title = element_text(size = 16, face = "plain", hjust = 0.5),
    axis.title = element_text(size = 13),
    axis.text = element_text(size = 11),
    axis.line = element_line(linewidth = 0.3, colour = "black"),
    axis.ticks = element_line(linewidth = 0.3, colour = "black"),
    legend.position = "none"
  )

ggsave(
  filename = bmi_box_out,
  plot = p_box,
  width = 6.2,
  height = 4.8,
  dpi = 300,
  bg = "white"
)

# -----------------------------
# Audit output for tested vars only
# -----------------------------
audit_df <- data.frame(
  variable = names(cont_tests),
  raw_p = unname(cont_tests),
  BH_adjusted_p = unname(cont_padj),
  stringsAsFactors = FALSE
)

write.table(
  audit_df,
  file = audit_out,
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

cat("Done.\n")
cat("Table written to:", table_out, "\n")
cat("BMI histogram written to:", bmi_hist_out, "\n")
cat("BMI boxplot written to:", bmi_box_out, "\n")
cat("P-value audit written to:", audit_out, "\n")
