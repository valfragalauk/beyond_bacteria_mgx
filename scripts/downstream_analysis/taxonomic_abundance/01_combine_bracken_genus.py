#!/usr/bin/env python3

"""
Combine all Bracken genus-level reports (*.bracken_G.txt) into one long table
and one wide abundance matrix.

Input:
    A directory of Bracken genus files, one per sample.

Expected file format columns:
    name
    taxonomy_id
    taxonomy_lvl
    kraken_assigned_reads
    added_reads
    new_est_reads
    fraction_total_reads

Outputs:
    1. combined long-format table
    2. combined genus abundance matrix using new_est_reads
"""

import argparse
import pandas as pd
from pathlib import Path


def parse_sample_id(filename: str) -> str:
    return filename.replace(".bracken_G.txt", "")


def main():
    parser = argparse.ArgumentParser(description="Combine Bracken genus files into long and wide tables")
    parser.add_argument("--input_dir", required=True, help="Directory containing *.bracken_G.txt files")
    parser.add_argument("--long_output", required=True, help="Output path for combined long table")
    parser.add_argument("--matrix_output", required=True, help="Output path for abundance matrix")
    args = parser.parse_args()

    input_dir = Path(args.input_dir)
    long_output = Path(args.long_output)
    matrix_output = Path(args.matrix_output)

    long_output.parent.mkdir(parents=True, exist_ok=True)
    matrix_output.parent.mkdir(parents=True, exist_ok=True)

    files = sorted(input_dir.glob("*.bracken_G.txt"))

    if not files:
        raise FileNotFoundError(f"No .bracken_G.txt files found in {input_dir}")

    all_dfs = []

    for file in files:
        sample_id = parse_sample_id(file.name)

        df = pd.read_csv(file, sep=r"\s+", engine="python")

        expected_cols = [
            "name",
            "taxonomy_id",
            "taxonomy_lvl",
            "kraken_assigned_reads",
            "added_reads",
            "new_est_reads",
            "fraction_total_reads",
        ]
        missing = [c for c in expected_cols if c not in df.columns]
        if missing:
            raise ValueError(f"{file} is missing columns: {missing}\nFound columns: {list(df.columns)}")

        # Keep genus-level only
        df = df[df["taxonomy_lvl"] == "G"].copy()

        # Add sample ID
        df["sample_id"] = sample_id

        # Keep only useful columns for downstream work
        df = df[
            [
                "sample_id",
                "name",
                "taxonomy_id",
                "taxonomy_lvl",
                "kraken_assigned_reads",
                "added_reads",
                "new_est_reads",
                "fraction_total_reads",
            ]
        ].copy()

        all_dfs.append(df)

    combined = pd.concat(all_dfs, ignore_index=True)

    # Clean names 
    combined["name"] = combined["name"].astype(str).str.strip()

    # Save long table
    combined.to_csv(long_output, sep="\t", index=False)

    # Create abundance matrix using Bracken-estimated reads
    matrix = (
        combined.pivot_table(
            index="sample_id",
            columns="name",
            values="new_est_reads",
            aggfunc="sum",
            fill_value=0,
        )
        .sort_index()
    )

    # Columns are sorted alphabetically
    matrix = matrix.reindex(sorted(matrix.columns), axis=1)

    matrix.to_csv(matrix_output, sep="\t")

    print(f"Processed {len(files)} files")
    print(f"Combined long table saved to: {long_output}")
    print(f"Genus abundance matrix saved to: {matrix_output}")
    print(f"Matrix shape: {matrix.shape[0]} samples x {matrix.shape[1]} genera")


if __name__ == "__main__":
    main()
