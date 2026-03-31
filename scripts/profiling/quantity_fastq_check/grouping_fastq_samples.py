#!/usr/bin/env python3
"""
Grouping FASTQ files into one folder per sample_id (from Excel metadata).

We use *symbolic links* instead of copying files to:
- avoid duplicating large FASTQs
- keep the original data untouched
- allow reproducible downstream analysis
"""

#Importing packages

import os
import sys
from pathlib import Path
import pandas as pd

#For each sample ID, finds ALL FASTQs whose filename contains that ID

METADATA_XLSX = "/scratch/prj/rosetree/Valentina/metadata/Full_dataset_April2024_onlyBlackWomen.xlsx"
SAMPLE_ID_COLUMN = "reads_ID"
FASTQ_DIR = "/scratch/prj/rosetree/recovered/kneaddata_M2020/Sequences"

OUT_BASE = "/scratch/prj/rosetree/Valentina/data/grouped_fastqs"
REPORT_DIR = "/scratch/prj/rosetree/Valentina/data/grouped_fastqs_reports"

# FASTQ extension
FASTQ_EXTS = (".fastq")

# If True: match if sample ID appears anywhere in filename 
SUBSTRING_MATCH = True

# -----------------------------

# Normalize sample id variable to string and ignore whitespace
def norm(x: str) -> str:
    return str(x).strip()

# Return a list of FASTQ files found in FASTQ_DIR.
def list_fastqs(fastq_dir: str) -> list[Path]:
    p = Path(fastq_dir)
    if not p.exists():
        raise FileNotFoundError(f"FASTQ_DIR does not exist: {fastq_dir}")
    files = [f for f in p.iterdir() if f.is_file() and f.name.endswith(FASTQ_EXTS)]
    return sorted(files)

# reate a symbolic link pointing to src at dst 
def safe_symlink(src: Path, dst: Path) -> None:
    """Create symlink dst -> src, skipping if it already exists."""
    if dst.exists():
        return
    os.symlink(str(src), str(dst))


#MAIN SCRIPT

def main():
    os.makedirs(OUT_BASE, exist_ok=True)
    os.makedirs(REPORT_DIR, exist_ok=True)

    # 1) Read metadata
    try:
        df = pd.read_excel(METADATA_XLSX, engine="openpyxl")
    except Exception as e:
        print(f"ERROR: Could not read Excel: {e}", file=sys.stderr)
        sys.exit(1)

    if SAMPLE_ID_COLUMN not in df.columns:
        print(f"ERROR: Column '{SAMPLE_ID_COLUMN}' not found in Excel.", file=sys.stderr)
        print("Excel columns are:", list(df.columns), file=sys.stderr)
        sys.exit(1)

    sample_ids = [norm(x) for x in df[SAMPLE_ID_COLUMN].dropna().tolist()]
    sample_ids = [x for x in sample_ids if x != ""]
    # remove duplicates (keep order)
    seen = set()
    sample_ids_unique = []
    for s in sample_ids:
        if s not in seen:
            seen.add(s)
            sample_ids_unique.append(s)

    # 2) Inventory FASTQs
    fastqs = list_fastqs(FASTQ_DIR)
    fastq_names = [f.name for f in fastqs]

    # Reports we will write
    missing_ids = []
    mapping_rows = []
    used_fastqs = set()

    # 3) For each sample ID, find ALL matching fastqs and symlink into folder
    for sid in sample_ids_unique:
        sample_folder = Path(OUT_BASE) / sid
        sample_folder.mkdir(parents=True, exist_ok=True)

        if SUBSTRING_MATCH:
            hits = [f for f in fastqs if sid in f.name]
        else:
            # If the FASTQ filename contains the sample ID anywhere inside it, treat it as belonging to that sample
            hits = [f for f in fastqs if f.stem == sid]

        if not hits:
            missing_ids.append(sid)
            mapping_rows.append({"sample_id": sid, "n_files": 0, "files": ""})
            continue

        # Symlink every hit into the sample folder
        for f in hits:
            dst = sample_folder / f.name
            safe_symlink(f, dst)
            used_fastqs.add(str(f))

        mapping_rows.append({
            "sample_id": sid,
            "n_files": len(hits),
            "files": ";".join([h.name for h in hits])
        })

    # 4) Extra FASTQs (not linked to any sample folder)
    extra_fastqs = [str(f) for f in fastqs if str(f) not in used_fastqs]

    # 5) Report
    pd.DataFrame(mapping_rows).to_csv(
        Path(REPORT_DIR) / "sample_to_fastqs.tsv",
        sep="\t",
        index=False
    )

    Path(REPORT_DIR, "missing_sample_ids.txt").write_text(
        "\n".join(missing_ids) + ("\n" if missing_ids else "")
    )

    Path(REPORT_DIR, "extra_fastqs.txt").write_text(
        "\n".join(extra_fastqs) + ("\n" if extra_fastqs else "")
    )

    # Simple per-sample FASTQ count summary
    pd.DataFrame(mapping_rows)[["sample_id", "n_files"]] \
        .sort_values("n_files", ascending=False) \
        .to_csv(Path(REPORT_DIR) / "counts_per_sample.tsv", sep="\t", index=False)
    
    # 6) Print final summary

    print("=== GROUPING SUMMARY ===")
    print(f"Samples in metadata:        {len(sample_ids_unique)}")
    print(f"FASTQs found on disk:       {len(fastqs)}")
    print(f"Samples with no FASTQs:     {len(missing_ids)}")
    print(f"Unused FASTQs:              {len(extra_fastqs)}")
    print(f"Grouped sample folders:     {OUT_BASE}")
    print(f"Reports written to:         {REPORT_DIR}")

    # Exit with non-zero status if something needs attention
    if missing_ids:
        print("WARNING: Some sample IDs had no matching FASTQs.", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
