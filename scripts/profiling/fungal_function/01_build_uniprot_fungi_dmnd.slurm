#!/bin/bash -l
#SBATCH --job-name=uniprot_fungi_db
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=04:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=4
#SBATCH -p msc_appbio

set -euo pipefail

source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate diamond_env

DBDIR=/scratch/prj/rosetree/Valentina/databases/uniprot_fungi
mkdir -p "${DBDIR}"
cd "${DBDIR}"

echo "[INFO] Downloading reviewed fungal UniProt proteins"
wget -O uniprot_fungi_reviewed.fasta \
"https://rest.uniprot.org/uniprotkb/stream?compressed=false&format=fasta&query=%28taxonomy_id%3A4751%29%20AND%20%28reviewed%3Atrue%29"

echo "[INFO] Building DIAMOND database"
diamond makedb \
  --in uniprot_fungi_reviewed.fasta \
  -d uniprot_fungi_reviewed

echo "[INFO] Done"
ls -lh
