#!/bin/bash -l
#SBATCH --job-name=diamond_fungi_batch
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=4

set -euo pipefail

echo "start= $(date)"

source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate diamond_env

echo "[INFO] Host: $(hostname)"
echo "[INFO] Conda env: ${CONDA_DEFAULT_ENV:-not_set}"
echo "[INFO] DIAMOND path: $(which diamond)"
echo "[INFO] DIAMOND version: $(diamond --version)"
echo
