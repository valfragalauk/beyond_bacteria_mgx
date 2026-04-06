#!/bin/bash -l
#SBATCH --job-name=top10_comp_all
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=01:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1
#SBATCH -p msc_appbio

set -euo pipefail

# -----------------------------
# Activate conda environment
# -----------------------------
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate microbiome_plots

# -----------------------------
# Define input files
# -----------------------------
SCRIPT="/scratch/prj/rosetree/Valentina/scripts/downstream_analysis/descriptive_statistics/composition_barplots.R"

METADATA="/scratch/prj/rosetree/Valentina/metadata/Full_dataset_April2024_onlyBlackWomen.xlsx"

BASE_OUTPUT="/scratch/prj/rosetree/Valentina/results/downstream/descriptive_statistics"

GENBANK_FUNGAL="/scratch/prj/rosetree/Valentina/results/downstream/taxonomic_abundance_filtering/genbank/filtered/genbank_fungal_genus_2pct.totalcount_gt_1.prevalence_0p02.tsv"
GENBANK_VIRAL="/scratch/prj/rosetree/Valentina/results/downstream/taxonomic_abundance_filtering/genbank/filtered/genbank_viral_genus_2pct.totalcount_gt_1.prevalence_0p02.tsv"
REFSEQ_FUNGAL="/scratch/prj/rosetree/Valentina/results/downstream/taxonomic_abundance_filtering/refseq/filtered/refseq_fungal_genus_2pct.totalcount_gt_1.prevalence_0p02.tsv"
REFSEQ_VIRAL="/scratch/prj/rosetree/Valentina/results/downstream/taxonomic_abundance_filtering/refseq/filtered/refseq_viral_genus_2pct.totalcount_gt_1.prevalence_0p02.tsv"

# -----------------------------
# Make output directories
# -----------------------------
mkdir -p "${BASE_OUTPUT}/genbank_fungal"
mkdir -p "${BASE_OUTPUT}/genbank_viral"
mkdir -p "${BASE_OUTPUT}/refseq_fungal"
mkdir -p "${BASE_OUTPUT}/refseq_viral"

# -----------------------------
# Run all four datasets
# -----------------------------
echo "Running genbank fungal..."
Rscript "$SCRIPT" \
  "$GENBANK_FUNGAL" \
  "$METADATA" \
  "genbank_fungal" \
  "Fungal" \
  "${BASE_OUTPUT}/genbank_fungal"

echo "Running genbank viral..."
Rscript "$SCRIPT" \
  "$GENBANK_VIRAL" \
  "$METADATA" \
  "genbank_viral" \
  "Viral" \
  "${BASE_OUTPUT}/genbank_viral"

echo "Running refseq fungal..."
Rscript "$SCRIPT" \
  "$REFSEQ_FUNGAL" \
  "$METADATA" \
  "refseq_fungal" \
  "Fungal" \
  "${BASE_OUTPUT}/refseq_fungal"

echo "Running refseq viral..."
Rscript "$SCRIPT" \
  "$REFSEQ_VIRAL" \
  "$METADATA" \
  "refseq_viral" \
  "Viral" \
  "${BASE_OUTPUT}/refseq_viral"

echo "All four composition plots finished successfully."
