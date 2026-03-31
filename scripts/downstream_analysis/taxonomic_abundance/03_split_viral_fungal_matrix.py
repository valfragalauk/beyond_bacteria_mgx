#!/usr/bin/env python3

"""
Split the combined genus abundance matrix into viral and fungal matrices
using the taxonomy annotation table created.
"""

import argparse
import pandas as pd


def main():
    parser = argparse.ArgumentParser(description="Split genus matrix into viral and fungal matrices")
    parser.add_argument("--matrix", required=True, help="Combined genus matrix TSV")
    parser.add_argument("--long_table", required=True, help="Combined long table TSV")
    parser.add_argument("--annotation", required=True, help="taxonomy_annotation.tsv")
    parser.add_argument("--viral_output", required=True, help="Output viral matrix TSV")
    parser.add_argument("--fungal_output", required=True, help="Output fungal matrix TSV")
    args = parser.parse_args()

    # Read files
    matrix = pd.read_csv(args.matrix, sep="\t", index_col=0)
    long_df = pd.read_csv(args.long_table, sep="\t")
    annot = pd.read_csv(args.annotation, sep="\t")

    # Get unique genus-taxid mapping
    genus_taxid = long_df[["name", "taxonomy_id"]].drop_duplicates()

    # Merge with annotation
    genus_annot = genus_taxid.merge(annot, on="taxonomy_id", how="left")

    # Get lists of genera by category
    viral_genera = genus_annot.loc[genus_annot["category"] == "Virus", "name"].unique().tolist()
    fungal_genera = genus_annot.loc[genus_annot["category"] == "Fungi", "name"].unique().tolist()

    # Keep only genera that actually exist in matrix columns
    viral_genera = [g for g in viral_genera if g in matrix.columns]
    fungal_genera = [g for g in fungal_genera if g in matrix.columns]

    viral_matrix = matrix[viral_genera].copy()
    fungal_matrix = matrix[fungal_genera].copy()

    viral_matrix.to_csv(args.viral_output, sep="\t")
    fungal_matrix.to_csv(args.fungal_output, sep="\t")

    print(f"Viral matrix saved to: {args.viral_output}")
    print(f"Fungal matrix saved to: {args.fungal_output}")
    print(f"Viral matrix shape: {viral_matrix.shape[0]} samples x {viral_matrix.shape[1]} genera")
    print(f"Fungal matrix shape: {fungal_matrix.shape[0]} samples x {fungal_matrix.shape[1]} genera")


if __name__ == "__main__":
    main()
