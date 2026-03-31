#!/bin/bash -l
#SBATCH --job-name=gb_lib_dl
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8

set -euo pipefail

# ------------------------
# PURPOSE:
# Build Kraken2 index files (hash.k2d, taxo.k2d, opts.k2d)
# from the downloaded GenBank libraries (fungi + viral) and existing taxonomy.
# ------------------------

source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate kraken_env

DB="/scratch/prj/rosetree/Valentina/databases/Genbank"

echo "[INFO] DB: ${DB}"

mkdir -p "${DB}/library/viral"
mkdir -p "${DB}/library/fungi"

# Safety checks: ensure library has both fungi and viral
[[ -d "${DB}/library/fungi" ]] || { echo "[ERROR] Missing ${DB}/library/fungi"; exit 1; }
[[ -d "${DB}/library/viral" ]] || { echo "[ERROR] Missing ${DB}/library/viral"; exit 1; }
[[ -d "${DB}/taxonomy" ]] || { echo "[ERROR] Missing ${DB}/taxonomy"; exit 1; }

# Build Kraken2 DB index
echo "[INFO] Starting k2 build..."
k2 build --db "${DB}" --threads "${SLURM_CPUS_PER_TASK}"

echo "[INFO] Build complete. Checking index files:"
ls -lh "${DB}"/hash.k2d "${DB}"/taxo.k2d "${DB}"/opts.k2d

# Optional: remove intermediate build artifacts (keeps final DB)
echo "[INFO] Cleaning intermediate files..."
k2 clean --db "${DB}"

echo "[INFO] Done."
