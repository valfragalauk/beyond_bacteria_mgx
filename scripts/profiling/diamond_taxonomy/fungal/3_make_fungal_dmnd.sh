#!/bin/bash -l
#SBATCH --job-name=mkdmnd_fungi
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=8

set -euo pipefail

source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate diamond_env

BASE="/scratch/prj/rosetree/Valentina"
DBDIR="${BASE}/databases/diamond/refseq_fungal_proteins"

cd "${DBDIR}"

[[ -f refseq_fungal_proteins_all.faa.gz ]] || { echo "[ERROR] Merged fungal FASTA not found"; exit 1; }

diamond makedb \
    --in refseq_fungal_proteins_all.faa.gz \
    --db refseq_fungal_proteins

echo "[INFO] DIAMOND fungal database built"
ls -lh refseq_fungal_proteins.dmnd
