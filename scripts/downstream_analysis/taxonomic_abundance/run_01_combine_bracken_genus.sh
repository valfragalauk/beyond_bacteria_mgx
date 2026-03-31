#!/bin/bash -l
#SBATCH --job-name=combine_bracken_genus
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=01:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1
#SBATCH -p msc_appbio

cd /scratch/prj/rosetree/Valentina

source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate pythonday

python scripts/downstream_analysis/taxonomic_abundance/01_combine_bracken_genus.py \
  --input_dir results/kraken_bracken/kraken_bracken_genbank/bracken_Genbank_87 \
  --long_output results/downstream/genbank/tables/genbank_genus_long.tsv \
  --matrix_output results/downstream/genbank/tables/genbank_genus_matrix.tsv
