#!/bin/bash -l
#SBATCH --job-name=gb_k2_build
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=12

#Building kraken db with Genbank taxonomy

set -euo pipefail

#conda enviroment
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate kraken_env

DB=/scratch/prj/rosetree/Valentina/databases/Genbank

echo "Starting Kraken2 build..."
k2 build --db "${DB}" --threads "${SLURM_CPUS_PER_TASK}"

echo "Cleaning intermediate files..."
k2 clean --db "${DB}"

echo "Build complete. Checking DB contents:"
ls -lh "${DB}" | egrep "hash|taxo|opts|k2d"
