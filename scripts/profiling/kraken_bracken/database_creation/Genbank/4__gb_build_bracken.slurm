#!/bin/bash -l
#SBATCH --job-name=gb_bracken_100
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=8

set -euo pipefail

# PURPOSE:
# Build Bracken k-mer distribution files for the GenBank Kraken2 DB.
# Read length confirmed earlier = 100 bp.

source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate kraken_env

DB="/scratch/prj/rosetree/Valentina/databases/Genbank"
READ_LEN=100

echo "[INFO] DB: ${DB}"
echo "[INFO] Building Bracken distributions for read length ${READ_LEN}"

# Safety checks
for f in hash.k2d taxo.k2d opts.k2d; do
  [[ -f "${DB}/${f}" ]] || { echo "[ERROR] Missing ${DB}/${f}"; exit 1; }
done

bracken-build \
  -d "${DB}" \
  -t "${SLURM_CPUS_PER_TASK}" \
  -l "${READ_LEN}"

echo "[INFO] Checking Bracken output:"
ls -lh "${DB}/database${READ_LEN}mers.kmer_distrib"

echo "[DONE] GenBank Bracken build finished."
