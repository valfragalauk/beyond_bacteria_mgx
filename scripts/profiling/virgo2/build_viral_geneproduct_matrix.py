import pandas as pd

# ------------------------------------------------------------
# PURPOSE
# Build a viral functional matrix by collapsing viral genes
# into VIRGO2 gene product annotations.
#
# INPUT:
#   1. viral_gene_matrix.csv
#   2. 6.VIRGO2.geneProduct.txt
#
# OUTPUT:
#   viral_geneProduct_matrix.csv
#
#   - groups genes with the same product
#   - sums abundances across samples
# ------------------------------------------------------------

# -----------------------------
# Input/output paths
# -----------------------------
viral_matrix_file = "/scratch/prj/rosetree/Valentina/results/virgo2/viral_function/viral_gene_matrix.csv"
geneproduct_file = "/scratch/prj/rosetree/Valentina/databases/VIRGO2/AnnotationTables/6.VIRGO2.geneProduct.txt"
output_file = "/scratch/prj/rosetree/Valentina/results/virgo2/viral_function/viral_geneProduct_matrix.csv"
unannotated_file = "/scratch/prj/rosetree/Valentina/results/virgo2/viral_function/viral_genes_without_geneProduct.csv"

print("[INFO] Loading viral gene matrix...")
viral_df = pd.read_csv(viral_matrix_file)

print("[INFO] Viral matrix shape:", viral_df.shape)
print("[INFO] Viral matrix columns (first 10):", viral_df.columns[:10].tolist())

# -----------------------------
# Load gene product annotation
# -----------------------------
print("[INFO] Loading gene product annotation...")
gp_df = pd.read_csv(geneproduct_file, sep="\t")

print("[INFO] Gene product columns:", gp_df.columns.tolist())

# Choose gene column

if gp_df.columns[0] != "Gene":
    gp_df = gp_df.rename(columns={gp_df.columns[0]: "Gene"})

if "Gene" not in viral_df.columns:
    raise ValueError("Expected a 'Gene' column in viral_gene_matrix.csv")

# Choose the annotation column
annotation_col = gp_df.columns[1]
print(f"[INFO] Using annotation column: {annotation_col}")

gp_df = gp_df[["Gene", annotation_col]].copy()
gp_df = gp_df.rename(columns={annotation_col: "geneProduct"})

# -----------------------------
# Clean annotation text
# -----------------------------
gp_df["geneProduct"] = gp_df["geneProduct"].fillna("").astype(str).str.strip()

# Remove rows where annotation is empty
gp_df = gp_df[gp_df["geneProduct"] != ""].copy()

print("[INFO] Number of annotated genes in geneProduct table:", gp_df.shape[0])

# -----------------------------
# Merge viral genes with annotations
# -----------------------------
print("[INFO] Merging viral genes with gene product annotations...")
merged_df = viral_df.merge(gp_df, on="Gene", how="left")

print("[INFO] Merged shape:", merged_df.shape)

# Save genes that failed to get a geneProduct annotation
unannotated_df = merged_df[merged_df["geneProduct"].isna()].copy()
print("[INFO] Viral genes without geneProduct annotation:", unannotated_df.shape[0])

if unannotated_df.shape[0] > 0:
    unannotated_df.to_csv(unannotated_file, index=False)
    print(f"[INFO] Saved unannotated genes to: {unannotated_file}")

# Keep only annotated viral genes
annotated_df = merged_df.dropna(subset=["geneProduct"]).copy()

print("[INFO] Annotated viral genes retained:", annotated_df.shape[0])

# -----------------------------
# Collapse 
# -----------------------------
# Group by geneProduct and sum abundances across samples.
# -----------------------------
sample_cols = [c for c in annotated_df.columns if c not in ["Gene", "geneProduct"]]

print("[INFO] Number of sample columns:", len(sample_cols))

functional_df = (
    annotated_df
    .groupby("geneProduct", as_index=False)[sample_cols]
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

print(f"[INFO] Saved viral gene product matrix to: {output_file}")
