#!/bin/bash -l
#SBATCH --job-name=taxa_filtering_all
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
echo "Starting taxa filtering pipeline"
date
echo "Host: $(hostname)"
echo "Working directory: $(pwd)"
echo "========================================"

PY_SCRIPT="/scratch/prj/rosetree/Valentina/scripts/downstream_analysis/filtering_taxa/filter_taxa_by_prevalence.py"

GENBANK_IN_DIR="/scratch/prj/rosetree/Valentina/results/downstream/genbank/tables"
GENBANK_OUT_DIR="/scratch/prj/rosetree/Valentina/results/downstream/genbank/filtered"

REFSEQ_IN_DIR="/scratch/prj/rosetree/Valentina/results/downstream/refseq/tables"
REFSEQ_OUT_DIR="/scratch/prj/rosetree/Valentina/results/downstream/refseq/filtered"

mkdir -p "$GENBANK_OUT_DIR"
mkdir -p "$REFSEQ_OUT_DIR"

run_or_skip() {
    local input_file="$1"
    local output_dir="$2"
    local prefix="$3"
    local prevalences="$4"
    local min_total_count="$5"

    local summary_file="${output_dir}/${prefix}.filtering_summary.tsv"
    local taxon_summary_file="${output_dir}/${prefix}.taxon_summary_after_total_filter.tsv"

    echo
    echo "----------------------------------------"
    echo "Dataset prefix: ${prefix}"
    echo "Input: ${input_file}"
    echo "Output dir: ${output_dir}"
    echo "Prevalence thresholds: ${prevalences}"
    echo "Min total count filter: > ${min_total_count}"
    echo "----------------------------------------"

    if [[ -f "$summary_file" && -f "$taxon_summary_file" ]]; then
        echo "SKIPPING ${prefix}: output files already exist"
        echo "  Found: $summary_file"
        echo "  Found: $taxon_summary_file"
    else
        echo "RUNNING ${prefix}"
        python "$PY_SCRIPT" \
            --input "$input_file" \
            --output_dir "$output_dir" \
            --prefix "$prefix" \
            --prevalences ${prevalences} \
            --min_total_count "$min_total_count"

        echo "DONE ${prefix}"
    fi
}

# -----------------------------
# GenBank datasets
# -----------------------------

run_or_skip \
    "${GENBANK_IN_DIR}/fungal_genus_matrix.tsv" \
    "${GENBANK_OUT_DIR}" \
    "genbank_fungal_genus" \
    "0.02 0.05 0.10" \
    "1"

run_or_skip \
    "${GENBANK_IN_DIR}/viral_genus_matrix.tsv" \
    "${GENBANK_OUT_DIR}" \
    "genbank_viral_genus" \
    "0.02 0.05 0.10" \
    "1"

# -----------------------------
# RefSeq datasets
# -----------------------------

run_or_skip \
    "${REFSEQ_IN_DIR}/refseq_fungi_G_counts_samples_x_taxa.tsv" \
    "${REFSEQ_OUT_DIR}" \
    "refseq_fungal_genus" \
    "0.02 0.05 0.10" \
    "1"

run_or_skip \
    "${REFSEQ_IN_DIR}/refseq_viral_G_counts_samples_x_taxa.tsv" \
    "${REFSEQ_OUT_DIR}" \
    "refseq_viral_genus" \
    "0.02 0.05 0.10" \
    "1"

echo
echo "========================================"
echo "Filtering pipeline finished"
date
echo "========================================"
