#!/bin/bash -l
#SBATCH --job-name=bracken_build_GB
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=8

set -euo pipefail

DB_DIR="/scratch/prj/rosetree/Valentina/databases/Genbank"

source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate kraken_env

# ---- DEBUG (keep until it works once) ----
echo "[DEBUG] Host: $(hostname)"
echo "[DEBUG] PATH=$PATH"
echo "[DEBUG] which bracken-build: $(which bracken-build || echo MISSING)"
echo "[DEBUG] which bracken: $(which bracken || echo MISSING)"
echo "[DEBUG] which kraken2: $(which kraken2 || echo MISSING)"
echo "[DEBUG] bracken-build --version:"
bracken-build --version || true
echo "[DEBUG] bracken-build --help (first lines):"
bracken-build --help 2>&1 | head -n 20 || true
echo "----------------------------------------"

KMER_LEN=35
READ_LEN=100

echo "[INFO] Building Bracken files for DB: ${DB_DIR}"
echo "[INFO] Using KMER_LEN=${KMER_LEN}"
echo "[INFO] Using READ_LEN=${READ_LEN}"
echo "[INFO] Threads: ${SLURM_CPUS_PER_TASK}"

bracken-build \
  -d "${DB_DIR}" \
  -t "${SLURM_CPUS_PER_TASK}" \
  -k "${KMER_LEN}" \
  -l "${READ_LEN}"

echo "[INFO] Bracken files created (showing kmer_distrib outputs):"
find "${DB_DIR}" -maxdepth 2 -type f -name "*kmer_distrib*" -ls || true

echo "[DONE] Bracken DB build finished."
