import pandas as pd

# PURPOSE
# Build a viral functional matrix by collapsing viral genes
# into VIRGO2 KEGG annotations.
#
# INPUT:
#   1. viral_gene_matrix.csv
#   2. 7.VIRGO2.kegg.txt
#
# OUTPUT:
#   viral_kegg_matrix.csv
#   viral_genes_without_kegg.csv
#
# -----------------------------
# Input/output paths
# -----------------------------
viral_matrix_file = "/scratch/prj/rosetree/Valentina/results/virgo2/viral_function/viral_gene_matrix.csv"
kegg_file = "/scratch/prj/rosetree/Valentina/databases/VIRGO2/AnnotationTables/7.VIRGO2.kegg.txt"
output_file = "/scratch/prj/rosetree/Valentina/results/virgo2/viral_function/viral_kegg_matrix.csv"
unannotated_file = "/scratch/prj/rosetree/Valentina/results/virgo2/viral_function/viral_genes_without_kegg.csv"

print("[INFO] Loading viral gene matrix...")
viral_df = pd.read_csv(viral_matrix_file)

print("[INFO] Viral matrix shape:", viral_df.shape)
print("[INFO] Viral matrix columns (first 10):", viral_df.columns[:10].tolist())

# -----------------------------
# Load KEGG annotation table
# -----------------------------
print("[INFO] Loading KEGG annotation...")
kegg_df = pd.read_csv(kegg_file, sep="\t")

print("[INFO] KEGG columns:", kegg_df.columns.tolist())

# -----------------------------
# Gene column
# -----------------------------
if kegg_df.columns[0] != "Gene":
    kegg_df = kegg_df.rename(columns={kegg_df.columns[0]: "Gene"})

if "Gene" not in viral_df.columns:
    raise ValueError("Expected a 'Gene' column in viral_gene_matrix.csv")

# -----------------------------
# Annotation column
# -----------------------------
if kegg_df.shape[1] < 2:
    raise ValueError("KEGG annotation file does not have enough columns.")

annotation_col = kegg_df.columns[1]
print(f"[INFO] Using KEGG annotation column: {annotation_col}")

kegg_df = kegg_df[["Gene", annotation_col]].copy()
kegg_df = kegg_df.rename(columns={annotation_col: "KEGG"})

# -----------------------------
# Clean annotation text
# -----------------------------
kegg_df["KEGG"] = kegg_df["KEGG"].fillna("").astype(str).str.strip()

# Remove empty annotations
kegg_df = kegg_df[kegg_df["KEGG"] != ""].copy()

print("[INFO] Number of annotated genes in KEGG table:", kegg_df.shape[0])

# -----------------------------
# Merge viral genes with KEGG annotations
# -----------------------------
print("[INFO] Merging viral genes with KEGG annotations...")
merged_df = viral_df.merge(kegg_df, on="Gene", how="left")

print("[INFO] Merged shape:", merged_df.shape)

# Save viral genes that do not get a KEGG annotation
unannotated_df = merged_df[merged_df["KEGG"].isna()].copy()
print("[INFO] Viral genes without KEGG annotation:", unannotated_df.shape[0])

if unannotated_df.shape[0] > 0:
    unannotated_df.to_csv(unannotated_file, index=False)
    print(f"[INFO] Saved unannotated genes to: {unannotated_file}")

# Keep only genes with KEGG annotation
annotated_df = merged_df.dropna(subset=["KEGG"]).copy()

print("[INFO] Annotated viral genes retained:", annotated_df.shape[0])

# -----------------------------
# Split multiple KEGG annotations if present
# -----------------------------
annotated_df["KEGG"] = annotated_df["KEGG"].astype(str).str.split(r"[;|]")
annotated_df = annotated_df.explode("KEGG")
annotated_df["KEGG"] = annotated_df["KEGG"].astype(str).str.strip()

# Remove blank entries after splitting
annotated_df = annotated_df[annotated_df["KEGG"] != ""].copy()

print("[INFO] Shape after splitting multiple KEGG annotations:", annotated_df.shape)

# -----------------------------
# Collapse from genes -> KEGG
# All columns except Gene and KEGG are sample columns.
# -----------------------------
sample_cols = [c for c in annotated_df.columns if c not in ["Gene", "KEGG"]]

print("[INFO] Number of sample columns:", len(sample_cols))

functional_df = (
    annotated_df
    .groupby("KEGG", as_index=False)[sample_cols]
    .sum()
)

print("[INFO] Functional matrix shape:", functional_df.shape)

# -----------------------------
# Sort rows by total abundance across all samples
# -----------------------------
functional_df["TOTAL_ABUNDANCE"] = functional_df[sample_cols].sum(axis=1)
functional_df = functional_df.sort_values("TOTAL_ABUNDANCE", ascending=False)
functional_df = functional_df.drop(columns=["TOTAL_ABUNDANCE"])

# -----------------------------
# Save result
# -----------------------------
functional_df.to_csv(output_file, index=False)

print(f"[INFO] Saved viral KEGG matrix to: {output_file}")
