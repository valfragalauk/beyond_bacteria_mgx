#!/usr/bin/env python3
import argparse
import glob
import os
import pandas as pd

def read_bracken(path: str) -> pd.DataFrame:
    """
    Bracken output columns typically:
    name  taxonomy_id  taxonomy_lvl  kraken_assigned_reads  added_reads  new_est_reads  fraction_total_reads
    """
    df = pd.read_csv(path, sep="\t")
    # Normalize column names just in case
    df.columns = [c.strip() for c in df.columns]
    required = {"name","taxonomy_id","taxonomy_lvl","new_est_reads","fraction_total_reads"}
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"{path} is missing columns: {missing}")
    return df

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in_dir", required=True, help="Directory containing Bracken *.txt outputs")
    ap.add_argument("--pattern", default="*.bracken_*.txt", help="Glob pattern for Bracken outputs")
    ap.add_argument("--out_prefix", required=True, help="Output prefix (no extension)")
    args = ap.parse_args()

    paths = sorted(glob.glob(os.path.join(args.in_dir, args.pattern)))
    if not paths:
        raise SystemExit(f"No files matched in {args.in_dir} with pattern {args.pattern}")

    counts = {}
    fracs = {}
    meta_rows = []

    for p in paths:
        fname = os.path.basename(p)

        # sample name = everything before ".bracken_"
        if ".bracken_" not in fname:
            # fallback: strip extension
            sample = os.path.splitext(fname)[0]
        else:
            sample = fname.split(".bracken_")[0]

        df = read_bracken(p)

        # Use taxonomy_id as stable key, keep name/level for metadata
        df = df[["taxonomy_id","name","taxonomy_lvl","new_est_reads","fraction_total_reads"]].copy()
        df["taxonomy_id"] = df["taxonomy_id"].astype(str)

        # Store counts/fractions as Series indexed by taxonomy_id
        counts[sample] = df.set_index("taxonomy_id")["new_est_reads"]
        fracs[sample] = df.set_index("taxonomy_id")["fraction_total_reads"]

        # Add metadata (dedupe later)
        meta_rows.append(df[["taxonomy_id","name","taxonomy_lvl"]])

    # Combine into matrices (outer join across taxa)
    counts_df = pd.DataFrame(counts).fillna(0).astype(int)
    fracs_df = pd.DataFrame(fracs).fillna(0.0)

    meta_df = pd.concat(meta_rows, ignore_index=True).drop_duplicates(subset=["taxonomy_id"])
    meta_df = meta_df.sort_values(["taxonomy_lvl","taxonomy_id"])

    # Write outputs
    counts_path = f"{args.out_prefix}_counts.tsv"
    fracs_path  = f"{args.out_prefix}_fraction.tsv"
    meta_path   = f"{args.out_prefix}_meta.tsv"

    counts_df.to_csv(counts_path, sep="\t")
    fracs_df.to_csv(fracs_path, sep="\t")
    meta_df.to_csv(meta_path, sep="\t", index=False)

    print(f"[OK] Wrote:\n  {counts_path}\n  {fracs_path}\n  {meta_path}")
    print(f"[INFO] Samples: {counts_df.shape[1]}  Taxa: {counts_df.shape[0]}")

if __name__ == "__main__":
    main()
