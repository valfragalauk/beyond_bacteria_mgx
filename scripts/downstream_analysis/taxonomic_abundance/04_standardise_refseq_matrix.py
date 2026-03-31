#!/usr/bin/env python3

"""
Standardise RefSeq Bracken merged matrices.

Currently, for RefSeq there are 6 tables; 2 of them are metadata and will be merged, resulting in a total of 4 abundance files: 
2 fungal (counts and ratio) and 2 viral (counts and ratio). This ensures that the count matrices match the GenBank matrices and are therefore comparable.

Input:
- counts or fraction matrix with rows = taxonomy_id and columns = samples
- meta table with taxonomy_id, name, taxonomy_lvl

Output:
- matrix with rows = samples and columns = genus names
"""

import argparse
import pandas as pd


def main():
    parser = argparse.ArgumentParser(description="Standardise RefSeq matrix to samples x taxa using names")
    parser.add_argument("--matrix", required=True, help="Input matrix TSV (taxonomy_id x samples)")
    parser.add_argument("--meta", required=True, help="Meta TSV with taxonomy_id and name")
    parser.add_argument("--output", required=True, help="Output TSV (samples x taxa)")
    args = parser.parse_args()

    # Read input matrix
    mat = pd.read_csv(args.matrix, sep="\t")

    # Read metadata
    meta = pd.read_csv(args.meta, sep="\t")

    # Merge names onto taxonomy_id
    mat = mat.merge(meta[["taxonomy_id", "name"]], on="taxonomy_id", how="left")

    # Check missing names
    missing = mat["name"].isna().sum()
    if missing > 0:
        print(f"Warning: {missing} taxonomy IDs have no name; using taxonomy_id as fallback")
        mat["name"] = mat["name"].fillna(mat["taxonomy_id"].astype(str))

    # Remove taxonomy_id and move name to index
    mat = mat.drop(columns=["taxonomy_id"])
    mat = mat.set_index("name")

    # If duplicate genus names exist, sum them
    mat = mat.groupby(mat.index).sum()

    # Transpose so rows = samples, columns = taxa
    mat = mat.T

    # Sort rows and columns for reproducibility
    mat = mat.sort_index()
    mat = mat.reindex(sorted(mat.columns), axis=1)

    # Save
    mat.to_csv(args.output, sep="\t")

    print(f"Saved standardised matrix to: {args.output}")
    print(f"Shape: {mat.shape[0]} samples x {mat.shape[1]} taxa")


if __name__ == "__main__":
    main()
