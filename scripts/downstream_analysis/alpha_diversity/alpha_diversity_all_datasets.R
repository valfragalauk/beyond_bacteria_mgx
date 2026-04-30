#!/usr/bin/env Rscript

############################################################
# Calculate alpha diversity for 4 microbiome datasets:
#   1. GenBank viral
#   2. GenBank fungal
#   3. RefSeq viral
#   4. RefSeq fungal
#
# Diversity metrics:
#   - Observed richness
#   - Shannon diversity
#   - Inverse Simpson diversity
#
# Then:
#   - merge with metadata
#   - compare TERM vs sPTB
#   - compare sPTB34 groups vs rest
#   - compare Term vs sPTB34 vs sPTB37
#   - correlate with gestational age at delivery
#
# This answers whether within-sample diversity differs
# between clinical outcome groups and whether diversity
# is associated with gestational age.
############################################################

suppressPackageStartupMessages({
  library(readxl)
  library(vegan)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(tools)
})

############################################################
# 1. INPUT FILES
############################################################

GENBANK_FUNGAL <- "/scratch/prj/rosetree/Valentina/results/downstream/descriptive_statistics/taxonomic_abundance_filtering/genbank/filtered/genbank_fungal_genus_2pct.totalcount_gt_1.prevalence_0p02.tsv"
GENBANK_VIRAL  <- "/scratch/prj/rosetree/Valentina/results/downstream/descriptive_statistics/taxonomic_abundance_filtering/genbank/filtered/genbank_viral_genus_2pct.totalcount_gt_1.prevalence_0p02.tsv"
REFSEQ_FUNGAL  <- "/scratch/prj/rosetree/Valentina/results/downstream/descriptive_statistics/taxonomic_abundance_filtering/refseq/filtered/refseq_fungal_genus_2pct.totalcount_gt_1.prevalence_0p02.tsv"
REFSEQ_VIRAL   <- "/scratch/prj/rosetree/Valentina/results/downstream/descriptive_statistics/taxonomic_abundance_filtering/refseq/filtered/refseq_viral_genus_2pct.totalcount_gt_1.prevalence_0p02.tsv"

METADATA_XLSX  <- "/scratch/prj/rosetree/Valentina/metadata/Full_dataset_April2024_onlyBlackWomen.xlsx"

############################################################
# 2. OUTPUT DIRECTORY
############################################################

OUTDIR <- "/scratch/prj/rosetree/Valentina/results/downstream/alpha_diversity"
dir.create(OUTDIR, recursive = TRUE, showWarnings = FALSE)

############################################################
# 3. HELPER FUNCTIONS
############################################################

clean_matrix_ids <- function(x) {
  x <- as.character(x)
  x <- sub("_1$", "", x)
  return(x)
}

read_metadata <- function(metadata_path) {
  meta <- readxl::read_excel(metadata_path)

  colnames(meta)[1] <- "sample_label"

  meta$sample_label <- as.character(meta$sample_label)
  meta$reads_ID     <- as.character(meta$reads_ID)

  keep_cols <- c(
    "sample_label",
    "reads_ID",
    "id",
    "Sample",
    "age",
    "Risk",
    "bmi",
    "smoking",
    "Ges_del_days",
    "outcome",
    "sPTB34",
    "sPTB37",
    "Term_outcome_detailed"
  )

  keep_cols <- keep_cols[keep_cols %in% colnames(meta)]
  meta <- meta[, keep_cols, drop = FALSE]

  # Standardise character columns
  char_cols <- c("sample_label", "reads_ID", "outcome", "sPTB34", "sPTB37", "Term_outcome_detailed", "Risk", "smoking")
  char_cols <- char_cols[char_cols %in% colnames(meta)]
  meta[char_cols] <- lapply(meta[char_cols], as.character)

  return(meta)
}

read_count_matrix <- function(path) {
  dat <- read.delim(path, sep = "\t", header = TRUE, check.names = FALSE)

  first_col_name <- colnames(dat)[1]

  if (first_col_name %in% c("sample", "Sample", "sample_id", "SampleID", "reads_ID", "id", "ID", "X", "")) {
    rownames(dat) <- dat[[1]]
    dat[[1]] <- NULL
  } else {
    if (!is.numeric(dat[[1]])) {
      rownames(dat) <- dat[[1]]
      dat[[1]] <- NULL
    }
  }

  dat[] <- lapply(dat, function(x) as.numeric(as.character(x)))
  dat[is.na(dat)] <- 0
  rownames(dat) <- clean_matrix_ids(rownames(dat))

  return(as.data.frame(dat))
}

calculate_alpha_diversity <- function(count_mat) {
  observed_richness <- rowSums(count_mat > 0)
  shannon <- vegan::diversity(count_mat, index = "shannon")
  invsimpson <- vegan::diversity(count_mat, index = "invsimpson")

  alpha_df <- data.frame(
    reads_ID = rownames(count_mat),
    observed_richness = observed_richness,
    shannon = shannon,
    invsimpson = invsimpson,
    stringsAsFactors = FALSE
  )

  return(alpha_df)
}

safe_shapiro <- function(x) {
  x <- x[is.finite(x)]
  if (length(unique(x)) < 3) return(NA_real_)
  if (length(x) < 3) return(NA_real_)
  out <- tryCatch(shapiro.test(x)$p.value, error = function(e) NA_real_)
  return(out)
}

compare_two_groups <- function(df, metric_col, group_col, dataset_name) {
  subdf <- df %>%
    dplyr::select(all_of(c(metric_col, group_col))) %>%
    dplyr::filter(!is.na(.data[[metric_col]]), !is.na(.data[[group_col]]))

  groups_present <- unique(subdf[[group_col]])
  groups_present <- groups_present[!is.na(groups_present)]

  if (length(groups_present) != 2) {
    return(data.frame(
      dataset = dataset_name,
      metric = metric_col,
      grouping_variable = group_col,
      comparison_type = "two_group",
      group1 = NA,
      group2 = NA,
      n_group1 = NA,
      n_group2 = NA,
      shapiro_p_group1 = NA,
      shapiro_p_group2 = NA,
      test_used = NA,
      statistic = NA,
      p_value = NA,
      stringsAsFactors = FALSE
    ))
  }

  g1 <- groups_present[1]
  g2 <- groups_present[2]

  x1 <- subdf %>% filter(.data[[group_col]] == g1) %>% pull(.data[[metric_col]])
  x2 <- subdf %>% filter(.data[[group_col]] == g2) %>% pull(.data[[metric_col]])

  shapiro1 <- safe_shapiro(x1)
  shapiro2 <- safe_shapiro(x2)

  both_normal <- !is.na(shapiro1) && !is.na(shapiro2) && shapiro1 > 0.05 && shapiro2 > 0.05

  test_res <- tryCatch({
    if (both_normal) {
      tt <- t.test(x1, x2)
      list(
        test_used = "t_test",
        statistic = unname(tt$statistic),
        p_value = tt$p.value
      )
    } else {
      wt <- wilcox.test(x1, x2, exact = FALSE)
      list(
        test_used = "wilcoxon",
        statistic = unname(wt$statistic),
        p_value = wt$p.value
      )
    }
  }, error = function(e) {
    list(
      test_used = NA,
      statistic = NA,
      p_value = NA
    )
  })

  out <- data.frame(
    dataset = dataset_name,
    metric = metric_col,
    grouping_variable = group_col,
    comparison_type = "two_group",
    group1 = as.character(g1),
    group2 = as.character(g2),
    n_group1 = length(x1),
    n_group2 = length(x2),
    shapiro_p_group1 = shapiro1,
    shapiro_p_group2 = shapiro2,
    test_used = test_res$test_used,
    statistic = test_res$statistic,
    p_value = test_res$p_value,
    stringsAsFactors = FALSE
  )

  return(out)
}

compare_three_groups <- function(df, metric_col, group_col, dataset_name) {
  subdf <- df %>%
    dplyr::select(all_of(c(metric_col, group_col))) %>%
    dplyr::filter(!is.na(.data[[metric_col]]), !is.na(.data[[group_col]]))

  subdf[[group_col]] <- as.character(subdf[[group_col]])

  # Keep only expected groups if present
  expected_groups <- c("Term", "sPTB34", "sPTB37")
  subdf <- subdf %>% filter(.data[[group_col]] %in% expected_groups)

  present_groups <- unique(subdf[[group_col]])

  if (length(present_groups) < 2) {
    return(list(
      overall = data.frame(
        dataset = dataset_name,
        metric = metric_col,
        grouping_variable = group_col,
        comparison_type = "three_group",
        groups_present = paste(sort(present_groups), collapse = ","),
        n_total = nrow(subdf),
        shapiro_p_Term = NA,
        shapiro_p_sPTB34 = NA,
        shapiro_p_sPTB37 = NA,
        test_used = NA,
        statistic = NA,
        p_value = NA,
        stringsAsFactors = FALSE
      ),
      posthoc = data.frame()
    ))
  }

  x_term   <- subdf %>% filter(.data[[group_col]] == "Term")   %>% pull(.data[[metric_col]])
  x_34     <- subdf %>% filter(.data[[group_col]] == "sPTB34") %>% pull(.data[[metric_col]])
  x_37     <- subdf %>% filter(.data[[group_col]] == "sPTB37") %>% pull(.data[[metric_col]])

  sh_term <- if (length(x_term)   > 0) safe_shapiro(x_term) else NA_real_
  sh_34   <- if (length(x_34)     > 0) safe_shapiro(x_34) else NA_real_
  sh_37   <- if (length(x_37)     > 0) safe_shapiro(x_37) else NA_real_

  shapiro_vals <- c(sh_term, sh_34, sh_37)
  non_missing_shapiro <- shapiro_vals[!is.na(shapiro_vals)]
  all_normal <- length(non_missing_shapiro) >= 2 && all(non_missing_shapiro > 0.05)

  subdf[[group_col]] <- factor(subdf[[group_col]], levels = expected_groups)

  if (all_normal) {
    fit <- tryCatch(aov(as.formula(paste(metric_col, "~", group_col)), data = subdf), error = function(e) NULL)

    if (is.null(fit)) {
      overall <- data.frame(
        dataset = dataset_name,
        metric = metric_col,
        grouping_variable = group_col,
        comparison_type = "three_group",
        groups_present = paste(sort(present_groups), collapse = ","),
        n_total = nrow(subdf),
        shapiro_p_Term = sh_term,
        shapiro_p_sPTB34 = sh_34,
        shapiro_p_sPTB37 = sh_37,
        test_used = NA,
        statistic = NA,
        p_value = NA,
        stringsAsFactors = FALSE
      )
      return(list(overall = overall, posthoc = data.frame()))
    }

    fit_sum <- summary(fit)[[1]]
    overall_p <- fit_sum[1, "Pr(>F)"]
    overall_F <- fit_sum[1, "F value"]

    overall <- data.frame(
      dataset = dataset_name,
      metric = metric_col,
      grouping_variable = group_col,
      comparison_type = "three_group",
      groups_present = paste(sort(present_groups), collapse = ","),
      n_total = nrow(subdf),
      shapiro_p_Term = sh_term,
      shapiro_p_sPTB34 = sh_34,
      shapiro_p_sPTB37 = sh_37,
      test_used = "anova",
      statistic = overall_F,
      p_value = overall_p,
      stringsAsFactors = FALSE
    )

    tuk <- TukeyHSD(fit)[[1]]
    tuk_df <- data.frame(
      dataset = dataset_name,
      metric = metric_col,
      grouping_variable = group_col,
      test_used = "tukeyHSD",
      comparison = rownames(tuk),
      estimate_diff = tuk[, "diff"],
      conf_low = tuk[, "lwr"],
      conf_high = tuk[, "upr"],
      p_value = tuk[, "p adj"],
      stringsAsFactors = FALSE
    )

    tuk_df$group1 <- NA_character_
    tuk_df$group2 <- NA_character_

    tuk_df <- tuk_df[, c(
      "dataset", "metric", "grouping_variable", "test_used",
      "comparison", "group1", "group2",
      "estimate_diff", "conf_low", "conf_high", "p_value"
    )]

    return(list(overall = overall, posthoc = tuk_df))
  } else {
    kw <- tryCatch(kruskal.test(as.formula(paste(metric_col, "~", group_col)), data = subdf), error = function(e) NULL)

    if (is.null(kw)) {
      overall <- data.frame(
        dataset = dataset_name,
        metric = metric_col,
        grouping_variable = group_col,
        comparison_type = "three_group",
        groups_present = paste(sort(present_groups), collapse = ","),
        n_total = nrow(subdf),
        shapiro_p_Term = sh_term,
        shapiro_p_sPTB34 = sh_34,
        shapiro_p_sPTB37 = sh_37,
        test_used = NA,
        statistic = NA,
        p_value = NA,
        stringsAsFactors = FALSE
      )
      return(list(overall = overall, posthoc = data.frame()))
    }

    overall <- data.frame(
      dataset = dataset_name,
      metric = metric_col,
      grouping_variable = group_col,
      comparison_type = "three_group",
      groups_present = paste(sort(present_groups), collapse = ","),
      n_total = nrow(subdf),
      shapiro_p_Term = sh_term,
      shapiro_p_sPTB34 = sh_34,
      shapiro_p_sPTB37 = sh_37,
      test_used = "kruskal_wallis",
      statistic = unname(kw$statistic),
      p_value = kw$p.value,
      stringsAsFactors = FALSE
    )

    pw <- pairwise.wilcox.test(
      x = subdf[[metric_col]],
      g = subdf[[group_col]],
      p.adjust.method = "fdr",
      exact = FALSE
    )

    pw_mat <- pw$p.value

    if (is.null(pw_mat)) {
      posthoc_df <- data.frame()
    } else {
      posthoc_df <- as.data.frame(as.table(pw_mat), stringsAsFactors = FALSE)
      colnames(posthoc_df) <- c("group1", "group2", "p_value")
      posthoc_df <- posthoc_df[!is.na(posthoc_df$p_value), , drop = FALSE]
      posthoc_df$comparison <- paste(posthoc_df$group1, "vs", posthoc_df$group2)
      posthoc_df$dataset <- dataset_name
      posthoc_df$metric <- metric_col
      posthoc_df$grouping_variable <- group_col
      posthoc_df$test_used <- "pairwise_wilcoxon_fdr"

      # Force consistent columns with Tukey output
      posthoc_df$estimate_diff <- NA_real_
      posthoc_df$conf_low <- NA_real_
      posthoc_df$conf_high <- NA_real_

      posthoc_df <- posthoc_df[, c(
        "dataset", "metric", "grouping_variable", "test_used",
        "comparison", "group1", "group2",
        "estimate_diff", "conf_low", "conf_high", "p_value"
      )]
    }

    return(list(overall = overall, posthoc = posthoc_df))
  }
}

correlate_with_gestational_age <- function(df, metric_col, dataset_name) {
  subdf <- df %>%
    dplyr::select(all_of(c(metric_col, "Ges_del_days"))) %>%
    dplyr::filter(!is.na(.data[[metric_col]]), !is.na(Ges_del_days))

  if (nrow(subdf) < 3) {
    return(data.frame(
      dataset = dataset_name,
      metric = metric_col,
      method = "spearman",
      n = nrow(subdf),
      rho = NA,
      p_value = NA,
      stringsAsFactors = FALSE
    ))
  }

  cor_res <- tryCatch({
    cor.test(subdf[[metric_col]], subdf$Ges_del_days, method = "spearman", exact = FALSE)
  }, error = function(e) NULL)

  if (is.null(cor_res)) {
    return(data.frame(
      dataset = dataset_name,
      metric = metric_col,
      method = "spearman",
      n = nrow(subdf),
      rho = NA,
      p_value = NA,
      stringsAsFactors = FALSE
    ))
  }

  out <- data.frame(
    dataset = dataset_name,
    metric = metric_col,
    method = "spearman",
    n = nrow(subdf),
    rho = unname(cor_res$estimate),
    p_value = cor_res$p.value,
    stringsAsFactors = FALSE
  )

  return(out)
}

process_dataset <- function(matrix_path, dataset_name, metadata_df, outdir) {

  message("Processing: ", dataset_name)

  count_mat <- read_count_matrix(matrix_path)
  alpha_df <- calculate_alpha_diversity(count_mat)

  alpha_df$reads_ID <- as.character(alpha_df$reads_ID)
  meta_sub <- metadata_df[match(alpha_df$reads_ID, metadata_df$reads_ID), , drop = FALSE]

  unmatched <- sum(is.na(meta_sub$reads_ID))
  if (unmatched > 0) {
    warning(dataset_name, ": ", unmatched, " samples could not be matched to metadata by reads_ID")
  }

  # Remove metadata reads_ID before cbind because alpha_df already contains it
  meta_sub_nodup <- meta_sub %>% dplyr::select(-reads_ID)

  merged_df <- cbind(alpha_df, meta_sub_nodup)

  write.table(
    merged_df,
    file = file.path(outdir, paste0(dataset_name, "_alpha_diversity_per_sample.tsv")),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
  )

  metrics <- c("observed_richness", "shannon", "invsimpson")

  outcome_results <- do.call(rbind, lapply(metrics, function(m) {
    compare_two_groups(merged_df, metric_col = m, group_col = "outcome", dataset_name = dataset_name)
  }))

  sptb34_results <- do.call(rbind, lapply(metrics, function(m) {
    compare_two_groups(merged_df, metric_col = m, group_col = "sPTB34", dataset_name = dataset_name)
  }))

  detailed_list <- lapply(metrics, function(m) {
    compare_three_groups(merged_df, metric_col = m, group_col = "Term_outcome_detailed", dataset_name = dataset_name)
  })

  detailed_overall <- do.call(rbind, lapply(detailed_list, function(x) x$overall))

  detailed_posthoc_nonempty <- lapply(detailed_list, function(x) x$posthoc)
  detailed_posthoc_nonempty <- detailed_posthoc_nonempty[sapply(detailed_posthoc_nonempty, nrow) > 0]

  if (length(detailed_posthoc_nonempty) > 0) {
    detailed_posthoc <- do.call(rbind, detailed_posthoc_nonempty)
  } else {
    detailed_posthoc <- data.frame()
  }

  cor_results <- do.call(rbind, lapply(metrics, function(m) {
    correlate_with_gestational_age(merged_df, metric_col = m, dataset_name = dataset_name)
  }))

  write.table(
    outcome_results,
    file = file.path(outdir, paste0(dataset_name, "_alpha_diversity_TERM_vs_sPTB_stats.tsv")),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
  )

  write.table(
    sptb34_results,
    file = file.path(outdir, paste0(dataset_name, "_alpha_diversity_sPTB34_stats.tsv")),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
  )

  write.table(
    detailed_overall,
    file = file.path(outdir, paste0(dataset_name, "_alpha_diversity_Term_outcome_detailed_overall_stats.tsv")),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
  )

  if (nrow(detailed_posthoc) > 0) {
    write.table(
      detailed_posthoc,
      file = file.path(outdir, paste0(dataset_name, "_alpha_diversity_Term_outcome_detailed_posthoc.tsv")),
      sep = "\t",
      quote = FALSE,
      row.names = FALSE
    )
  }

  write.table(
    cor_results,
    file = file.path(outdir, paste0(dataset_name, "_alpha_diversity_gestational_age_spearman.tsv")),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
  )

  return(merged_df)
}

############################################################
# 4. MAIN
############################################################

metadata_df <- read_metadata(METADATA_XLSX)

dataset_list <- list(
  genbank_viral  = GENBANK_VIRAL,
  genbank_fungal = GENBANK_FUNGAL,
  refseq_viral   = REFSEQ_VIRAL,
  refseq_fungal  = REFSEQ_FUNGAL
)

all_alpha_list <- list()

for (nm in names(dataset_list)) {
  all_alpha_list[[nm]] <- process_dataset(
    matrix_path = dataset_list[[nm]],
    dataset_name = nm,
    metadata_df = metadata_df,
    outdir = OUTDIR
  )
}

combined_alpha <- dplyr::bind_rows(
  lapply(names(all_alpha_list), function(nm) {
    df <- all_alpha_list[[nm]]
    df$dataset <- nm
    df
  })
)

write.table(
  combined_alpha,
  file = file.path(OUTDIR, "combined_alpha_diversity_all_datasets.tsv"),
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

message("Alpha diversity analysis complete.")
