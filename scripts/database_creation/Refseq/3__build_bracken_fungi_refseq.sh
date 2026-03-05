#!/bin/bash -l
#SBATCH --job-name=bracken_build_fungi
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=08:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8

set -euo pipefail

source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate kraken_env

DB=/scratch/prj/rosetree/Valentina/databases/RefSeq_Fungi
bracken-build -d "$DB" -t "$SLURM_CPUS_PER_TASK" -l 100
ls -lh "$DB"/database100mers.kmer_distrib
