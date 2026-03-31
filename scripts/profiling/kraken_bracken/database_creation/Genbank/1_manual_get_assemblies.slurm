#!/bin/bash -l
#SBATCH --job-name=gb_https_dl
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=12:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=2
#SBATCH -p msc_appbio

set -euo pipefail

DB=/scratch/prj/rosetree/Valentina/databases/Genbank
DL=$DB/manual_dl
mkdir -p "$DL"
cd "$DL"

echo "[INFO] Download assembly summaries via HTTPS"
curl -L -o fungi_assembly_summary.txt  https://ftp.ncbi.nlm.nih.gov/genomes/genbank/fungi/assembly_summary.txt
curl -L -o viral_assembly_summary.txt  https://ftp.ncbi.nlm.nih.gov/genomes/genbank/viral/assembly_summary.txt

echo "[INFO] Filter COMPLETE_GENOME entries and extract ftp_path (already https URLs)"
# Column header line starts with #assembly_accession. ftp_path is a column near the end.
# We keep rows where assembly_level == "Complete Genome" (exact match varies; sometimes "Complete Genome")
awk -F'\t' 'BEGIN{OFS="\t"} $0 !~ /^#/ && $12=="Complete Genome" {print $20}' fungi_assembly_summary.txt > fungi_complete_https_paths.txt
awk -F'\t' 'BEGIN{OFS="\t"} $0 !~ /^#/ && $12=="Complete Genome" {print $20}' viral_assembly_summary.txt > viral_complete_https_paths.txt

echo "[INFO] Example paths:"
head -n 5 fungi_complete_https_paths.txt || true
head -n 5 viral_complete_https_paths.txt || true

echo "[INFO] Counts:"
wc -l fungi_complete_https_paths.txt viral_complete_https_paths.txt
