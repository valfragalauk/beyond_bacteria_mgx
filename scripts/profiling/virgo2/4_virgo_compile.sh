#!/bin/bash -l
#SBATCH --job-name=VIRGO2_compile
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=04:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=2

set -euo pipefail

# ------------------------------------------------------------
# Combine all per-sample VIRGO2 mapping outputs into one
# gene-by-sample matrix.
# ------------------------------------------------------------

source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh

conda activate virgo2_env
export PATH="$CONDA_PREFIX/bin:$PATH"
hash -r

module purge
module load bowtie2/2.5.1-gcc-13.2.0-python-3.11.6
module load samtools/1.17-gcc-13.2.0-python-3.11.6

# Re-assert conda python after module loading
export PATH="$CONDA_PREFIX/bin:$PATH"
hash -r

# ------------------------------------------------------------
# Print environment diagnostics
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
MAP_DIR="${PROJECT}/results/virgo2/map_flat"
OUT_DIR="${PROJECT}/results/virgo2/compiled"
OUT_PREFIX="${OUT_DIR}/virgo2_87samples"

mkdir -p "${OUT_DIR}"

# ------------------------------------------------------------
# Check inputs
# ------------------------------------------------------------
[[ -d "${VIRGO2_DIR}" ]] || { echo "[ERROR] VIRGO2 directory not found: ${VIRGO2_DIR}"; exit 1; }
[[ -f "${VIRGO2_DIR}/VIRGO2.py" ]] || { echo "[ERROR] VIRGO2.py not found"; exit 1; }
[[ -d "${MAP_DIR}" ]] || { echo "[ERROR] Map directory not found: ${MAP_DIR}"; exit 1; }

OUT_COUNT=$(find "${MAP_DIR}" -type f -name "*.out" | wc -l)
echo "[INFO] Number of per-sample .out files found: ${OUT_COUNT}"

if [[ "${OUT_COUNT}" -lt 1 ]]; then
  echo "[ERROR] No VIRGO2 per-sample .out files found in ${MAP_DIR}"
  exit 1
fi

echo "[INFO] VIRGO2 dir: ${VIRGO2_DIR}"
echo "[INFO] Map dir:    ${MAP_DIR}"
echo "[INFO] Output dir: ${OUT_DIR}"
echo "[INFO] Output prefix: ${OUT_PREFIX}"

# ------------------------------------------------------------
# Run compile
# ------------------------------------------------------------
cd "${VIRGO2_DIR}"

python VIRGO2.py compile \
  -i "${MAP_DIR}" \
  -o "${OUT_PREFIX}"

# ------------------------------------------------------------
# Check output was actually created
# ------------------------------------------------------------
if [[ -s "${OUT_PREFIX}.txt" ]]; then
  echo "[INFO] Compile finished successfully: ${OUT_PREFIX}.txt"
else
  echo "[ERROR] Compile did not create expected output: ${OUT_PREFIX}.txt"
  exit 1
fi
