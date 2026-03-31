#!/bin/bash -l
#SBATCH --job-name=split_viral_fungal
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=01:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1
#SBATCH -p msc_appbio

cd /scratch/prj/rosetree/Valentina
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate pythonday

python scripts/downstream_analysis/taxonomic_abundance/03_split_viral_fungal_matrix.py \
  --matrix results/downstream/genbank/tables/genbank_genus_matrix.tsv \
  --long_table results/downstream/genbank/tables/genbank_genus_long.tsv \
  --annotation results/downstream/genbank/tables/taxonomy_annotation.tsv \
  --viral_output results/downstream/genbank/tables/viral_genus_matrix.tsv \
  --fungal_output results/downstream/genbank/tables/fungal_genus_matrix.tsv
