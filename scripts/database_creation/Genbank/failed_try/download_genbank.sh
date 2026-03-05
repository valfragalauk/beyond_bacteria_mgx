#!/bin/bash -l
#SBATCH --job-name=gb_vifungi_dl
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=06:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=6

set -euo pipefail

# Script to download NCBI Genbank taxonomy
 
#Location
DB=/scratch/prj/rosetree/Valentina/databases/Genbank

# Load environment
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate kraken_env

# Taxonomy (names/nodes + accession maps used by Kraken2)
k2 download-taxonomy --db "${DB}"

# Download fungal assemblies from GenBank
k2 download-library \
  --db "${DB}" \
  --library fungi \
  --assembly-source genbank \
  --assembly-levels chromosome complete_genome \
  --threads "${SLURM_CPUS_PER_TASK}"

# Download viral genomes from GenBank
k2 download-library \
  --db "${DB}" \
  --library viral \
  --assembly-source genbank \
  --assembly-levels complete_genome \
  --threads "${SLURM_CPUS_PER_TASK}"

echo "Download stage complete."
echo "Next: build the DB with k2 build (separate job)."
