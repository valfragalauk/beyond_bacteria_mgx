#!/bin/bash -l
#SBATCH --job-name=beta
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=01:00:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=1
#SBATCH -p msc_appbio

source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate microbiome_plots

PROJECT_DIR="/scratch/prj/rosetree/Valentina"
SCRIPT="${PROJECT_DIR}/scripts/downstream_analysis/beta_diversity/beta_diversity_single_dataset.R"
CONFIG="${PROJECT_DIR}/scripts/downstream_analysis/beta_diversity/dataset_paths.tsv"
META="${PROJECT_DIR}/results/downstream/metadata_clean/metadata_clean.tsv"
BASE_OUTDIR="${PROJECT_DIR}/results/downstream/beta_diversity"

echo "Starting beta diversity pipeline"
echo "Config file: ${CONFIG}"
echo "Metadata file: ${META}"
echo "R script: ${SCRIPT}"

tail -n +2 "${CONFIG}" | while IFS=$'\t' read -r DATASET_ID DOMAIN DATABASE MATRIX_PATH
do
  echo "======================================"
  echo "Running dataset: ${DATASET_ID}"
  echo "Domain: ${DOMAIN}"
  echo "Database: ${DATABASE}"
  echo "Matrix: ${MATRIX_PATH}"
  echo "======================================"

  OUTDIR="${BASE_OUTDIR}/${DATASET_ID}"
  mkdir -p "${OUTDIR}"

  Rscript "${SCRIPT}" \
    --dataset_id "${DATASET_ID}" \
    --matrix_path "${MATRIX_PATH}" \
    --metadata_path "${META}" \
    --outdir "${OUTDIR}"

  echo "Finished dataset: ${DATASET_ID}"
done

echo "All beta diversity analyses completed."

