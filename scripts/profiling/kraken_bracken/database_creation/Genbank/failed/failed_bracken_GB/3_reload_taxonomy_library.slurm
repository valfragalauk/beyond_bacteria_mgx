#!/bin/bash -l
#SBATCH --job-name=gb_restore_lib
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=2

set -euo pipefail

source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate kraken_env

DB="/scratch/prj/rosetree/Valentina/databases/Genbank"
DL_THREADS=1

echo "[INFO] Restoring taxonomy (if missing)..."
mkdir -p "${DB}/taxonomy"
k2 download-taxonomy --db "${DB}"

echo "[INFO] Restoring GenBank fungi library (restricted HQ) with threads=${DL_THREADS}..."
k2 download-library \
  --db "${DB}" \
  --library fungi \
  --assembly-source genbank \
  --assembly-levels chromosome complete_genome \
  --threads "${DL_THREADS}"

echo "[INFO] Restoring GenBank viral library (restricted HQ) with threads=${DL_THREADS}..."
k2 download-library \
  --db "${DB}" \
  --library viral \
  --assembly-source genbank \
  --assembly-levels complete_genome \
  --threads "${DL_THREADS}"

echo "[INFO] Quick check of library folder:"
find "${DB}/library" -maxdepth 2 -type f | head -n 30 || true
du -sh "${DB}/library" "${DB}/taxonomy" || true

echo "[DONE] Library+taxonomy restore step finished."
