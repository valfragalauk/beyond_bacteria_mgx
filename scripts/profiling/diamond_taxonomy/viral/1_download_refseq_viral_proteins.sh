#!/bin/bash -l
#SBATCH --job-name=dl_refseq_viralprot
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=02:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=2
#SBATCH -p msc_appbio

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
OUTDIR=$BASE/databases/diamond/refseq_viral_proteins

mkdir -p "$OUTDIR"
cd "$OUTDIR"

# Clean old temporary files from failed attempts
rm -f index.html* robots.txt* || true

# -------------------------------
# Download directory listing
# -------------------------------
wget -O viral_index.html https://ftp.ncbi.nlm.nih.gov/refseq/release/viral/

# -------------------------------
# Extract all viral protein FASTA filenames from the page
# -------------------------------
grep -oE 'viral\.[0-9]+\.protein\.faa\.gz' viral_index.html | sort -u > viral_protein_files.txt

echo "Files detected:"
cat viral_protein_files.txt

# Stop if nothing was found
if [[ ! -s viral_protein_files.txt ]]; then
    echo "ERROR: No viral protein FASTA files found in directory listing."
    exit 1
fi

# -------------------------------
# Download each protein FASTA file
# -------------------------------
while read -r file; do
    wget -c "https://ftp.ncbi.nlm.nih.gov/refseq/release/viral/${file}"
done < viral_protein_files.txt

# -------------------------------
# Merge all downloaded FASTA parts
# -------------------------------
cat viral.*.protein.faa.gz > refseq_viral_proteins_all.faa.gz

# Check merged file
gzip -t refseq_viral_proteins_all.faa.gz

echo "Download complete"
echo "Merged file: $OUTDIR/refseq_viral_proteins_all.faa.gz"
