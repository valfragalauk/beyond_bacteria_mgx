#!/bin/bash -l
#SBATCH --job-name=k2_build_fungi
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=20:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=8

set -euo pipefail

# directory 

BASE="/scratch/prj/rosetree/Valentina"
DB="${BASE}/databases/RefSeq_Fungi_custom"

# conda
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate kraken_env

mkdir -p "${DB}"
cd "${DB}"

echo "[INFO] Download NCBI taxonomy (needed for kraken classification tree)"
kraken2-build --download-taxonomy --use-ftp --db "${DB}"

echo "[INFO] Download RefSeq fungi library"

# This downloads RefSeq fungal genomes into the DB library

kraken2-build --download-library fungi --use-ftp --db "${DB}"

echo "[INFO] Build the Kraken2 DB (this is the heavy step)"
# --threads uses your allocated CPUs
kraken2-build --build --threads "${SLURM_CPUS_PER_TASK}" --db "${DB}"

echo "[INFO] Sanity check"
kraken2-inspect --db "${DB}" | head -n 25

echo "[INFO] Done building fungi DB: ${DB}"
