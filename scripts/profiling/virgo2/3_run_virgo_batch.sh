#!/bin/bash -l
#SBATCH --job-name=VIRGO2_map
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=16:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8

set -euo pipefail

# ------------------------------------------------------------
# Run VIRGO2 map on a batch list of FASTQ files, one by one.
# ------------------------------------------------------------

# ------------------------------------------------------------
# Load conda explicitly using the HPC conda.sh path
# ------------------------------------------------------------
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh

conda activate virgo2_env
export PATH="$CONDA_PREFIX/bin:$PATH"
hash -r

# Load required HPC modules
module purge
module load bowtie2/2.5.1-gcc-13.2.0-python-3.11.6
module load samtools/1.17-gcc-13.2.0-python-3.11.6

# Re-assert conda python after module loading
export PATH="$CONDA_PREFIX/bin:$PATH"
hash -r

# ------------------------------------------------------------
# Print environment diagnostics so the log proves what is used
# ------------------------------------------------------------
echo "========== ENVIRONMENT CHECK =========="
echo "Host: $(hostname)"
echo "Date: $(date)"
echo "CONDA_PREFIX: ${CONDA_PREFIX}"
echo "Python path: $(which python)"
python --version
echo "Bowtie2 path: $(which bowtie2)"
echo "Samtools path: $(which samtools)"
echo "Testing pandas/numpy imports..."
python -c "import sys, pandas, numpy; print('PYTHON_EXEC=', sys.executable); print('PANDAS=', pandas.__version__); print('NUMPY=', numpy.__version__)"
echo "======================================="

# ------------------------------------------------------------
# Define paths
# ------------------------------------------------------------
PROJECT="/scratch/prj/rosetree/Valentina"
VIRGO2_DIR="${PROJECT}/databases/VIRGO2"
OUT_DIR="${PROJECT}/results/virgo2/map"

mkdir -p "${OUT_DIR}"

# ------------------------------------------------------------
# Require a batch list input
# ------------------------------------------------------------
if [[ $# -lt 1 ]]; then
  echo "[ERROR] Usage: sbatch run_virgo2_map_batch.sh <sample_list_file>"
  exit 1
fi

LIST="$1"

# ------------------------------------------------------------
# Sanity checks
# ------------------------------------------------------------
[[ -d "${VIRGO2_DIR}" ]] || { echo "[ERROR] VIRGO2 directory missing"; exit 1; }
[[ -f "${VIRGO2_DIR}/VIRGO2.py" ]] || { echo "[ERROR] VIRGO2.py not found"; exit 1; }
[[ -d "${VIRGO2_DIR}/Index" ]] || { echo "[ERROR] VIRGO2 index folder missing"; exit 1; }
[[ -f "${LIST}" ]] || { echo "[ERROR] Sample list not found: ${LIST}"; exit 1; }

INDEX_COUNT=$(find "${VIRGO2_DIR}/Index" -maxdepth 1 -type f \( -name "*.bt2" -o -name "*.bt2l" \) | wc -l)
if [[ "${INDEX_COUNT}" -lt 6 ]]; then
  echo "[ERROR] VIRGO2 index appears incomplete; found ${INDEX_COUNT} files"
  exit 1
fi

echo "[INFO] VIRGO2 directory: ${VIRGO2_DIR}"
echo "[INFO] FASTQ list: ${LIST}"
echo "[INFO] Output directory: ${OUT_DIR}"

N=$(grep -cv '^\s*$' "${LIST}" || true)
echo "[INFO] Samples in batch: ${N}"

# ------------------------------------------------------------
# Process samples one by one
# ------------------------------------------------------------
i=0
while IFS= read -r FASTQ; do
  [[ -z "${FASTQ// }" ]] && continue
  i=$((i+1))

  SAMPLE=$(basename "${FASTQ}")
  SAMPLE=${SAMPLE%_kneaddata.fastq}
  SAMPLE=${SAMPLE%.fastq.gz}
  SAMPLE=${SAMPLE%.fq.gz}
  SAMPLE=${SAMPLE%.fastq}
  SAMPLE=${SAMPLE%.fq}

  SDIR="${OUT_DIR}/${SAMPLE}"
  mkdir -p "${SDIR}"

  OUT_PREFIX="${SDIR}/${SAMPLE}"
  DONE_FILE="${SDIR}/${SAMPLE}.DONE"

  echo "------------------------------------------------------------"
  echo "[INFO] (${i}/${N}) Sample: ${SAMPLE}"
  echo "[INFO] FASTQ: ${FASTQ}"
  echo "[INFO] Output folder: ${SDIR}"

  if [[ ! -f "${FASTQ}" ]]; then
    echo "[WARN] FASTQ missing, skipping: ${FASTQ}"
    continue
  fi

  if [[ -f "${DONE_FILE}" ]]; then
    echo "[INFO] DONE file exists, skipping sample"
    continue
  fi

  echo "[INFO] Running VIRGO2 map..."

  (
    cd "${VIRGO2_DIR}"
    python VIRGO2.py map \
      -r "${FASTQ}" \
      -p "${SLURM_CPUS_PER_TASK}" \
      -c 1 \
      -o "${OUT_PREFIX}"
  )

  FILE_COUNT=$(find "${SDIR}" -maxdepth 1 -type f | wc -l)

  if [[ "${FILE_COUNT}" -gt 0 ]]; then
    touch "${DONE_FILE}"
    echo "[INFO] Completed: ${SAMPLE}"
  else
    echo "[WARN] No output detected for ${SAMPLE}"
  fi

done < "${LIST}"

echo "============================================================"
echo "[INFO] VIRGO2 batch completed"
echo "[INFO] Results in: ${OUT_DIR}"
