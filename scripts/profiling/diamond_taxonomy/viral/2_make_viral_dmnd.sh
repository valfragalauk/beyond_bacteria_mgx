#!/bin/bash -l
#SBATCH --job-name=mkdmnd_viral
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=04:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8

set -euo pipefail

# -------------------------------
# Load conda environment
# -------------------------------
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate diamond_env

# -------------------------------
# Define directories
# -------------------------------
BASE=/scratch/prj/rosetree/Valentina
DBDIR=$BASE/databases/diamond/refseq_viral_proteins

cd "$DBDIR"

# -------------------------------
# Build DIAMOND database
# -------------------------------
# Input = protein FASTA
# Output = DIAMOND database (.dmnd)
diamond makedb \
    --in refseq_viral_proteins_all.faa.gz \
    --db refseq_viral_proteins

echo "DIAMOND viral database built successfully"
echo "Database: $DBDIR/refseq_viral_proteins.dmnd"
