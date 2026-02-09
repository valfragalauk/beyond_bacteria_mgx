#!/bin/bash -l
#SBATCH --job-name=kraken_test
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=01:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=4
#SBATCH -p msc_appbio

cd /scratch/prj/rosetree/Valentina

# initialise conda for non-interactive SLURM job shells, then activate env
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate kraken_env

# classify simulated reads against Minikraken database
kraken2 \
  --db databases/minikraken/minikraken2_v2_8GB_201904_UPDATE \
  --threads 8 \
  --report sample_results/minikraken_simulated.report \
  --output sample_results/minikraken_simulated.out \
  sample_data/simulated_reads/tutorial_reads.fastq
