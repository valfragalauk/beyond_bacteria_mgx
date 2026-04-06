#!/bin/bash -l
#SBATCH --job-name=descriptive_prev_totals
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=01:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1
#SBATCH -p msc_appbio

set -euo pipefail

source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh

conda activate microbiome_plots


SCRIPT_DIR="/scratch/prj/rosetree/Valentina/scripts/downstream_analysis/descriptive_statistics"
RESULTS_DIR="/scratch/prj/rosetree/Valentina/results/downstream/descriptive_composition"
METADATA="/scratch/prj/rosetree/Valentina/metadata/Full_dataset_April2024_onlyBlackWomen.xlsx"
PLOT_SCRIPT="${SCRIPT_DIR}/plot_prevalence_and_sample_totals.R"

TOP_N=20
METADATA_SHEET="AUTO"

run_one () {
  local INPUT="$1"
  local DATASET_ID="$2"
  local KINGDOM="$3"
  local DATABASE="$4"

  echo "============================================================"
  echo "Running dataset: ${DATASET_ID}"
  echo "Input file: ${INPUT}"
  echo "Kingdom: ${KINGDOM}"
  echo "Database: ${DATABASE}"
  echo "============================================================"

  if [ ! -f "${INPUT}" ]; then
    echo "ERROR: input file not found: ${INPUT}" >&2
    exit 1
  fi

  Rscript "${PLOT_SCRIPT}" \
    "${INPUT}" \
    "${METADATA}" \
    "${RESULTS_DIR}" \
    "${DATASET_ID}" \
    "${KINGDOM}" \
    "${DATABASE}" \
    "${TOP_N}" \
    "${METADATA_SHEET}"

  echo "Finished dataset: ${DATASET_ID}"
}

# ------------------------------------------------------------
# Run all 4 datasets sequentially
# ------------------------------------------------------------

run_one \
  "/scratch/prj/rosetree/Valentina/results/downstream/taxonomic_abundance_filtering/genbank/filtered/genbank_fungal_genus_2pct.totalcount_gt_1.prevalence_0p02.tsv" \
  "genbank_fungal" \
  "Fungal" \
  "GB"

run_one \
  "/scratch/prj/rosetree/Valentina/results/downstream/taxonomic_abundance_filtering/genbank/filtered/genbank_viral_genus_2pct.totalcount_gt_1.prevalence_0p02.tsv" \
  "genbank_viral" \
  "Viral" \
  "GB"

run_one \
  "/scratch/prj/rosetree/Valentina/results/downstream/taxonomic_abundance_filtering/refseq/filtered/refseq_fungal_genus_2pct.totalcount_gt_1.prevalence_0p02.tsv" \
  "refseq_fungal" \
  "Fungal" \
  "RefSeq"

run_one \
  "/scratch/prj/rosetree/Valentina/results/downstream/taxonomic_abundance_filtering/refseq/filtered/refseq_viral_genus_2pct.totalcount_gt_1.prevalence_0p02.tsv" \
  "refseq_viral" \
  "Viral" \
  "RefSeq"

echo "All datasets completed successfully."
