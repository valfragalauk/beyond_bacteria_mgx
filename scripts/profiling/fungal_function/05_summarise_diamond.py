import os
import glob
import pandas as pd

INPUT_DIR = "/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/diamond"
OUTDIR = "/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/tables"
os.makedirs(OUTDIR, exist_ok=True)

cols = [
    "qseqid", "sseqid", "pident", "length", "mismatch", "gapopen",
    "qstart", "qend", "sstart", "send", "evalue", "bitscore", "stitle"
]

all_data = []

files = glob.glob(os.path.join(INPUT_DIR, "*.diamond.tsv"))

for f in files:
    sample = os.path.basename(f).replace(".diamond.tsv", "")
    
    if os.path.getsize(f) == 0:
        continue
    
    df = pd.read_csv(f, sep="\t", header=None, names=cols)
    
    # Basic filtering (optional but recommended)
    df = df[(df["pident"] >= 40) & (df["length"] >= 20)]
    
    counts = df.groupby(["sseqid", "stitle"]).size().reset_index(name="count")
    counts["sample"] = sample
    
    all_data.append(counts)

result = pd.concat(all_data)

# Save long format
result.to_csv(os.path.join(OUTDIR, "fungal_function_long.csv"), index=False)

# Save wide format
wide = result.pivot_table(
    index="sample",
    columns="sseqid",
    values="count",
    fill_value=0
)

wide.to_csv(os.path.join(OUTDIR, "fungal_function_wide.csv"))
