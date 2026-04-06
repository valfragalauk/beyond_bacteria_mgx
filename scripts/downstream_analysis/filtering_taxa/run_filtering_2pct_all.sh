#!/bin/bash -l
#SBATCH --job-name=taxa_filtering_2pct
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=01:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1
#SBATCH -p msc_appbio

set -euo pipefail

source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate pythonday

echo "========================================"
echo "Starting taxa filtering pipeline (2%)"
date
echo "========================================"

PY_SCRIPT="/scratch/prj/rosetree/Valentina/scripts/downstream_analysis/filtering_taxa/filter_taxa_by_prevalence.py"

BASE_DIR="/scratch/prj/rosetree/Valentina/results/downstream/taxonomic_abundance_filtering"

GENBANK_IN_DIR="${BASE_DIR}/genbank/tables"
GENBANK_OUT_DIR="${BASE_DIR}/genbank/filtered"

REFSEQ_IN_DIR="${BASE_DIR}/refseq/tables"
REFSEQ_OUT_DIR="${BASE_DIR}/refseq/filtered"

mkdir -p "$GENBANK_OUT_DIR"
mkdir -p "$REFSEQ_OUT_DIR"

run_filter() {
    local input_file="$1"
    local output_dir="$2"
    local prefix="$3"

    echo
    echo "----------------------------------------"
    echo "Running: ${prefix}"
    echo "Input: ${input_file}"
    echo "----------------------------------------"

    python "$PY_SCRIPT" \
        --input "$input_file" \
        --output_dir "$output_dir" \
        --prefix "$prefix" \
        --prevalences 0.02 \
        --min_total_count 1

    echo "DONE: ${prefix}"
}

# -----------------------------
# GenBank
# -----------------------------

run_filter \
    "${GENBANK_IN_DIR}/fungal_genus_matrix.tsv" \
    "${GENBANK_OUT_DIR}" \
    "genbank_fungal_genus_2pct"

run_filter \
    "${GENBANK_IN_DIR}/viral_genus_matrix.tsv" \
    "${GENBANK_OUT_DIR}" \
    "genbank_viral_genus_2pct"

# -----------------------------
# RefSeq
# -----------------------------

run_filter \
    "${REFSEQ_IN_DIR}/refseq_fungi_G_counts_samples_x_taxa.tsv" \
    "${REFSEQ_OUT_DIR}" \
    "refseq_fungal_genus_2pct"

run_filter \
    "${REFSEQ_IN_DIR}/refseq_viral_G_counts_samples_x_taxa.tsv" \
    "${REFSEQ_OUT_DIR}" \
    "refseq_viral_genus_2pct"

echo
echo "========================================"
echo "Filtering finished"
date
echo "========================================"
