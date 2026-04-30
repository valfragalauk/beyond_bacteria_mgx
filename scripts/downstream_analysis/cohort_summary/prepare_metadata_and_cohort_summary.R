#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(tibble)
})

# =========================================================
# Script: 01_prepare_metadata_and_cohort_summary.R
# =========================================================
# Purpose:
# 1. Read the original metadata Excel file
# 2. Rename the first unnamed column to "sample_label"
# 3. Keep sample_label for display only
# 4. Keep reads_ID as the true matching key
# 5. Clean key metadata variables
# 6. Create smoking_ever from smoking
# 7. Export cleaned metadata
# 8. Produce cohort summary tables overall and by outcome
# 9. Report missingness
#
# =========================================================

# -----------------------------
# Paths
# -----------------------------
project_dir <- "/scratch/prj/rosetree/Valentina"
metadata_file <- file.path(project_dir, "metadata", "Full_dataset_April2024_onlyBlackWomen.xlsx")
out_dir <- file.path(project_dir, "results", "downstream", "metadata_clean")
summary_dir <- file.path(project_dir, "results", "downstream", "cohort_summary")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)

# -----------------------------
# Read metadata
# -----------------------------
meta_raw <- read_excel(metadata_file)

# The first metadata column is unnamed and contains labels like ID_1, ID_2, etc.
colnames(meta_raw)[1] <- "sample_label"

# -----------------------------
# Clean metadata
# -----------------------------
meta <- meta_raw %>%
  mutate(
    # ID variables
    sample_label = as.character(sample_label),   # for plotting / display only
    reads_ID = as.character(reads_ID),           # true matching key
    Sample = as.character(Sample),

    # Outcomes
    outcome = factor(outcome, levels = c("TERM", "sPTB")),
    sPTB34 = factor(sPTB34, levels = c("no", "yes")),
    sPTB37 = factor(sPTB37, levels = c("no", "yes")),

    # Covariates / descriptive variables
    Risk = factor(Risk, levels = c("Low risk", "High risk")),
    eth = factor(eth, levels = c("African", "African-Caribbean")),
    smoking = factor(
      smoking,
      levels = c("Never", "Ex - gave up before pregnancy", "Current")
    ),

    # Main smoking variable for adjusted analyses
    smoking_ever = case_when(
      smoking == "Never" ~ "Never",
      smoking %in% c("Ex - gave up before pregnancy", "Current") ~ "Ever",
      TRUE ~ NA_character_
    ),
    smoking_ever = factor(smoking_ever, levels = c("Never", "Ever")),

    # Continuous variables
    age = as.numeric(age),
    bmi = as.numeric(bmi),
    Ges_del_days = as.numeric(Ges_del_days)
  )

# -----------------------------
# Keep the variables needed downstream
# -----------------------------
meta_clean <- meta %>%
  select(sample_label, reads_ID, age, bmi, IMD_rank, smoking, smoking_ever, Risk, eth, outcome, sPTB34, sPTB37, Ges_del_days)
# -----------------------------
# Export cleaned metadata
# -----------------------------
write_tsv(meta_clean, file.path(out_dir, "metadata_clean.tsv"))
write_csv(meta_clean, file.path(out_dir, "metadata_clean.csv"))

# -----------------------------
# Missingness table
# -----------------------------
missingness_tbl <- tibble(
  variable = c(
    "sample_label",
    "reads_ID",
    "Sample",
    "age",
    "bmi",
    "smoking",
    "smoking_ever",
    "Risk",
    "eth",
    "outcome",
    "sPTB34",
    "sPTB37",
    "Ges_del_days"
  ),
  n_missing = c(
    sum(is.na(meta_clean$sample_label)),
    sum(is.na(meta_clean$reads_ID)),
    sum(is.na(meta_clean$Sample)),
    sum(is.na(meta_clean$age)),
    sum(is.na(meta_clean$bmi)),
    sum(is.na(meta_clean$smoking)),
    sum(is.na(meta_clean$smoking_ever)),
    sum(is.na(meta_clean$Risk)),
    sum(is.na(meta_clean$eth)),
    sum(is.na(meta_clean$outcome)),
    sum(is.na(meta_clean$sPTB34)),
    sum(is.na(meta_clean$sPTB37)),
    sum(is.na(meta_clean$Ges_del_days))
  )
) %>%
  mutate(percent_missing = round(100 * n_missing / nrow(meta_clean), 2))

write_tsv(missingness_tbl, file.path(summary_dir, "metadata_missingness.tsv"))

# -----------------------------
# Helper: continuous summary
# -----------------------------
summarise_continuous <- function(df, var) {
  x <- df[[var]]

  tibble(
    variable = var,
    n_nonmissing = sum(!is.na(x)),
    mean = mean(x, na.rm = TRUE),
    sd = sd(x, na.rm = TRUE),
    median = median(x, na.rm = TRUE),
    iqr = IQR(x, na.rm = TRUE),
    min = min(x, na.rm = TRUE),
    max = max(x, na.rm = TRUE)
  )
}

# -----------------------------
# Helper: categorical summary
# -----------------------------
summarise_categorical <- function(df, var) {
  df %>%
    filter(!is.na(.data[[var]])) %>%
    count(.data[[var]], name = "n") %>%
    mutate(
      variable = var,
      level = as.character(.data[[var]]),
      percent = round(100 * n / sum(n), 2)
    ) %>%
    select(variable, level, n, percent)
}

# -----------------------------
# Overall cohort summary
# -----------------------------
overall_cont <- bind_rows(
  summarise_continuous(meta_clean, "age"),
  summarise_continuous(meta_clean, "bmi"),
  summarise_continuous(meta_clean, "Ges_del_days")
)

overall_cat <- bind_rows(
  summarise_categorical(meta_clean, "outcome"),
  summarise_categorical(meta_clean, "sPTB34"),
  summarise_categorical(meta_clean, "sPTB37"),
  summarise_categorical(meta_clean, "Risk"),
  summarise_categorical(meta_clean, "eth"),
  summarise_categorical(meta_clean, "smoking"),
  summarise_categorical(meta_clean, "smoking_ever")
)

write_tsv(overall_cont, file.path(summary_dir, "cohort_summary_overall_continuous.tsv"))
write_tsv(overall_cat, file.path(summary_dir, "cohort_summary_overall_categorical.tsv"))

# -----------------------------
# Summary by TERM vs sPTB
# -----------------------------
by_outcome_cont <- meta_clean %>%
  filter(!is.na(outcome)) %>%
  group_by(outcome) %>%
  group_modify(~ bind_rows(
    summarise_continuous(.x, "age"),
    summarise_continuous(.x, "bmi"),
    summarise_continuous(.x, "Ges_del_days")
  )) %>%
  ungroup()

write_tsv(by_outcome_cont, file.path(summary_dir, "cohort_summary_by_outcome_continuous.tsv"))

make_cat_by_group <- function(df, var, group_var = "outcome") {
  df %>%
    filter(!is.na(.data[[group_var]]), !is.na(.data[[var]])) %>%
    count(.data[[group_var]], .data[[var]], name = "n") %>%
    group_by(.data[[group_var]]) %>%
    mutate(percent = round(100 * n / sum(n), 2)) %>%
    ungroup() %>%
    rename(group = .data[[group_var]], level = .data[[var]]) %>%
    mutate(variable = var) %>%
    select(variable, group, level, n, percent)
}

by_outcome_cat <- bind_rows(
  make_cat_by_group(meta_clean, "sPTB34"),
  make_cat_by_group(meta_clean, "sPTB37"),
  make_cat_by_group(meta_clean, "Risk"),
  make_cat_by_group(meta_clean, "eth"),
  make_cat_by_group(meta_clean, "smoking"),
  make_cat_by_group(meta_clean, "smoking_ever")
)

write_tsv(by_outcome_cat, file.path(summary_dir, "cohort_summary_by_outcome_categorical.tsv"))

message("Metadata cleaning and cohort summary completed.")
