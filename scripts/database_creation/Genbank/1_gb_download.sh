#!/bin/bash -l
#SBATCH --job-name=gb_restricted_dl
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=20:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8

set -euo pipefail

source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate kraken_env

DB=/scratch/prj/rosetree/Valentina/databases/Genbank

# Download taxonomy
k2 download-taxonomy --db "${DB}"

# Download High quality GenBank fungi only
k2 download-library \
  --db "${DB}" \
  --library fungi \
  --assembly-source genbank \
  --assembly-levels chromosome complete_genome \
  --threads "${SLURM_CPUS_PER_TASK}"

# Download High Quality Genbank viral only
k2 download-library \
  --db "${DB}" \
  --library viral \
  --assembly-source genbank \
  --assembly-levels complete_genome \
  --threads "${SLURM_CPUS_PER_TASK}"

echo "Restricted download complete."
