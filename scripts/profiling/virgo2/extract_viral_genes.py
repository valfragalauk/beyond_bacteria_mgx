import pandas as pd

# ------------------------------------------------------------
# Extract viral/phage genes from compiled VIRGO2 matrix
# ------------------------------------------------------------

# Input files
compiled_file = "/scratch/prj/rosetree/Valentina/results/virgo2/compiled/virgo2_87samples.summary.NR.txt"
phage_file = "/scratch/prj/rosetree/Valentina/databases/VIRGO2/AnnotationTables/10.VIRGO2.phage.txt"

# Output
output_file = "/scratch/prj/rosetree/Valentina/results/virgo2/viral_function/viral_gene_matrix.csv"

print("[INFO] Loading compiled matrix...")
df = pd.read_csv(compiled_file, sep="\t")

print("[INFO] Loading phage annotation...")
phage_df = pd.read_csv(phage_file, sep="\t")

print("[INFO] Phage file columns:", phage_df.columns.tolist())

phage_genes = set(phage_df.iloc[:, 0])  # first column = gene IDs

print(f"[INFO] Number of phage genes: {len(phage_genes)}")

# ------------------------------------------------------------
# Filter compiled matrix
# ------------------------------------------------------------
print("[INFO] Filtering viral genes...")

viral_df = df[df["Gene"].isin(phage_genes)]

print(f"[INFO] Viral matrix shape: {viral_df.shape}")

# ------------------------------------------------------------
# Save
# ------------------------------------------------------------
viral_df.to_csv(output_file, index=False)

print(f"[INFO] Saved viral gene matrix to: {output_file}")
