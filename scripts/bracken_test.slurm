#!/bin/bash -l
#SBATCH --job-name=bracken_test
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=01:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1
#SBATCH -p msc_appbio

cd /scratch/prj/rosetree/Valentina

# initialise conda inside non-interactive SLURM shell
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate kraken_env

# Species-level abundance estimation
bracken \
  -d databases/minikraken/minikraken2_v2_8GB_201904_UPDATE \
  -i sample_results/minikraken_simulated.report \
  -o sample_results/minikraken_simulated.bracken.S.tsv \
  -r 150 \
  -l S

# Genus-level abundance estimation
bracken \
  -d databases/minikraken/minikraken2_v2_8GB_201904_UPDATE \
  -i sample_results/minikraken_simulated.report \
  -o sample_results/minikraken_simulated.bracken.G.tsv \
  -r 150 \
  -l G
