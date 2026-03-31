#!/bin/bash -l
#SBATCH --job-name=gb_k2_build
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=12

set -euo pipefail

# PURPOSE:
# Build the Kraken2 index files for the GenBank database
# using the existing taxonomy/ and populated library/.

source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate kraken_env

DB="/scratch/prj/rosetree/Valentina/databases/Genbank"

echo "[INFO] Building Kraken2 DB: ${DB}"

# Safety checks
[[ -d "${DB}/taxonomy" ]] || { echo "[ERROR] Missing taxonomy folder: ${DB}/taxonomy"; exit 1; }
[[ -d "${DB}/library"  ]] || { echo "[ERROR] Missing library folder: ${DB}/library"; exit 1; }

echo "[INFO] Starting kraken2-build --build"
kraken2-build \
  --build \
  --threads "${SLURM_CPUS_PER_TASK}" \
  --db "${DB}"

echo "[INFO] Build complete. Checking DB index files:"
ls -lh "${DB}"/hash.k2d "${DB}"/taxo.k2d "${DB}"/opts.k2d

echo "[INFO] Quick inspect:"
kraken2-inspect --db "${DB}" | head -n 25

echo "[DONE] GenBank Kraken2 DB build finished."
