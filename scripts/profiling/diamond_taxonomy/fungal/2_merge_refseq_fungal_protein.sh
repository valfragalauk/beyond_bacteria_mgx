#!/bin/bash -l
#SBATCH --job-name=merge_fungiprot
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=1:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=4

set -euo pipefail

source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate diamond_env

BASE="/scratch/prj/rosetree/Valentina"
DBDIR="${BASE}/databases/diamond/refseq_fungal_proteins"

cd "${DBDIR}"

[[ -f fungal_protein_files.txt ]] || { echo "[ERROR] fungal_protein_files.txt not found"; exit 1; }

echo "[INFO] Merging fungal protein FASTAs..."

# Concatenate gzipped FASTAs safely
cat $(cat fungal_protein_files.txt) > refseq_fungal_proteins_all.faa.gz

# Check gzip integrity
gzip -t refseq_fungal_proteins_all.faa.gz

echo "[INFO] Merge complete"
ls -lh refseq_fungal_proteins_all.faa.gz
