#!/usr/bin/env python3

import argparse
import os
import math
import pandas as pd


def load_matrix(path):
    """
    FILTERING WIHT DIFFERENT THRESHOLDS
    Load abundance matrix with:
    rows = samples
    columns = taxa
    values = counts
    """
    df = pd.read_csv(path, sep="\t", index_col=0)
    return df


def filter_total_count(df, min_total_count=1):
    """
    Keep taxa with total count > min_total_count.
    If min_total_count = 1, this removes taxa with total count <= 1.
    """
    taxa_sums = df.sum(axis=0)
    keep_taxa = taxa_sums[taxa_sums > min_total_count].index
    return df[keep_taxa], taxa_sums


def filter_prevalence(df, min_samples_present):
    """
    Keep taxa present in at least min_samples_present samples.
    Presence is defined as count > 0.
    """
    prevalence = (df > 0).sum(axis=0)
    keep_taxa = prevalence[prevalence >= min_samples_present].index
    return df[keep_taxa], prevalence


def main():
    parser = argparse.ArgumentParser(description="Filter microbiome count matrix by total count and prevalence.")
    parser.add_argument("--input", required=True, help="Input samples x taxa count matrix (TSV)")
    parser.add_argument("--output_dir", required=True, help="Directory for filtered outputs")
    parser.add_argument("--prefix", required=True, help="Prefix for output filenames")
    parser.add_argument("--prevalences", nargs="+", type=float, default=[0.05, 0.10, 0.15],
                        help="Prevalence thresholds as proportions, e.g. 0.05 0.10 0.15")
    parser.add_argument("--min_total_count", type=int, default=1,
                        help="Remove taxa with total count <= this value")
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)

    # Load matrix
    df = load_matrix(args.input)
    n_samples = df.shape[0]
    n_taxa_start = df.shape[1]

    # Step 1: total count filtering
    df_total_filtered, taxa_sums = filter_total_count(df, min_total_count=args.min_total_count)
    n_taxa_after_total = df_total_filtered.shape[1]

    total_filtered_path = os.path.join(
        args.output_dir,
        f"{args.prefix}.totalcount_gt_{args.min_total_count}.tsv"
    )
    df_total_filtered.to_csv(total_filtered_path, sep="\t")

    # Save per-taxon stats after total-count filtering
    prevalence_after_total = (df_total_filtered > 0).sum(axis=0)
    taxa_summary = pd.DataFrame({
        "taxon": df_total_filtered.columns,
        "total_count": df_total_filtered.sum(axis=0).values,
        "n_samples_present": prevalence_after_total.values,
        "prevalence_fraction": (prevalence_after_total / n_samples).values
    })
    taxa_summary_path = os.path.join(
        args.output_dir,
        f"{args.prefix}.taxon_summary_after_total_filter.tsv"
    )
    taxa_summary.to_csv(taxa_summary_path, sep="\t", index=False)

    # Step 2: prevalence filtering
    summary_rows = []

    summary_rows.append({
        "dataset": args.prefix,
        "stage": "input",
        "n_samples": n_samples,
        "n_taxa": n_taxa_start,
        "threshold_type": "none",
        "threshold_value": "none"
    })

    summary_rows.append({
        "dataset": args.prefix,
        "stage": "after_total_count_filter",
        "n_samples": df_total_filtered.shape[0],
        "n_taxa": n_taxa_after_total,
        "threshold_type": "total_count",
        "threshold_value": f"> {args.min_total_count}"
    })

    for prev in args.prevalences:
        min_samples_present = math.ceil(prev * n_samples)

        df_prev_filtered, prevalence_counts = filter_prevalence(
            df_total_filtered,
            min_samples_present=min_samples_present
        )

        prev_label = str(prev).replace(".", "p")
        out_path = os.path.join(
            args.output_dir,
            f"{args.prefix}.totalcount_gt_{args.min_total_count}.prevalence_{prev_label}.tsv"
        )
        df_prev_filtered.to_csv(out_path, sep="\t")

        summary_rows.append({
            "dataset": args.prefix,
            "stage": "after_prevalence_filter",
            "n_samples": df_prev_filtered.shape[0],
            "n_taxa": df_prev_filtered.shape[1],
            "threshold_type": "prevalence",
            "threshold_value": f"{prev} ({min_samples_present}/{n_samples} samples)"
        })

    summary_df = pd.DataFrame(summary_rows)
    summary_path = os.path.join(
        args.output_dir,
        f"{args.prefix}.filtering_summary.tsv"
    )
    summary_df.to_csv(summary_path, sep="\t", index=False)

    print("Filtering complete")
    print(f"Input matrix: {args.input}")
    print(f"Samples: {n_samples}")
    print(f"Starting taxa: {n_taxa_start}")
    print(f"After total-count filter (> {args.min_total_count}): {n_taxa_after_total}")
    print(f"Outputs written to: {args.output_dir}")


if __name__ == "__main__":
    main()
