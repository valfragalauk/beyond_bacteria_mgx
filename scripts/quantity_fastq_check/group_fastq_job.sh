#!/bin/bash -l
#SBATCH --job-name=group_fastqs
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=00:10:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=1
#SBATCH -p msc_appbio

#job script to run the python grouping script

set -euo pipefail

# initialise conda for non-interactive SLURM job shells, then activate env
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate kraken_env

python /scratch/prj/rosetree/Valentina/scripts/grouping_fastq_samples.py
