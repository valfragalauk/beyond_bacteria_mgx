#!/bin/bash -l
#SBATCH --job-name=test_diamond_viral
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=08:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8

set -euo pipefail

# -------------------------------
# Load conda environment
# -------------------------------
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate diamond_env

# -------------------------------
# Define project paths
# -------------------------------
BASE=/scratch/prj/rosetree/Valentina
LIST=$BASE/sorted_data/final_fastq_87.txt
DB=$BASE/databases/diamond/refseq_viral_proteins/refseq_viral_proteins
OUTDIR=$BASE/results/diamond/viral

mkdir -p "$OUTDIR"

# -------------------------------
# Use first sample in the list
# -------------------------------
QUERY=$(sed -n '1p' "$LIST")

# Extract a clean sample name from the filename
SAMPLE=$(basename "$QUERY" .fastq)

echo "Testing sample: $SAMPLE"
echo "Input file: $QUERY"
echo "Database: ${DB}.dmnd"

# -------------------------------
# Run DIAMOND blastx
# -------------------------------
# blastx = nucleotide query vs protein database
# sensitive mode = better detection for divergent sequences
# outfmt 6 = tab-separated output for easier downstream parsing
diamond blastx \
    --db "$DB" \
    --query "$QUERY" \
    --out "$OUTDIR/${SAMPLE}_viral_diamond.tsv" \
    --outfmt 6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle \
    --evalue 1e-5 \
    --max-target-seqs 10 \
    --threads ${SLURM_CPUS_PER_TASK} \
    --sensitive

echo "Test run complete for: $SAMPLE"
