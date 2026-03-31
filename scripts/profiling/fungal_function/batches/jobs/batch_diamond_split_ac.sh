#!/bin/bash -l
#SBATCH --job-name=diamond_fungi_batch
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=4

set -euo pipefail

echo "start= $(date)"

source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate diamond_env

echo "[INFO] Host: $(hostname)"
echo "[INFO] Conda env: ${CONDA_DEFAULT_ENV:-not_set}"
echo "[INFO] DIAMOND path: $(which diamond)"
echo "[INFO] DIAMOND version: $(diamond --version)"
echo
rm -f '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/diamond/V300043643_L3_DKWGS200331025-550_1.diamond.tsv'; rm -rf '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/tmp/V300043643_L3_DKWGS200331025-550_1'; mkdir -p '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/tmp/V300043643_L3_DKWGS200331025-550_1'; diamond blastx --db '/scratch/prj/rosetree/Valentina/databases/uniprot_fungi/uniprot_fungi_reviewed.dmnd' --query '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/fasta/V300043643_L3_DKWGS200331025-550_1.fasta' --out '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/diamond/V300043643_L3_DKWGS200331025-550_1.diamond.tsv' --threads 4 --evalue 1e-5 --max-target-seqs 1 --outfmt 6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle --tmpdir '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/tmp/V300043643_L3_DKWGS200331025-550_1'
rm -f '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/diamond/V300043643_L3_DKWGS200331026-551_1.diamond.tsv'; rm -rf '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/tmp/V300043643_L3_DKWGS200331026-551_1'; mkdir -p '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/tmp/V300043643_L3_DKWGS200331026-551_1'; diamond blastx --db '/scratch/prj/rosetree/Valentina/databases/uniprot_fungi/uniprot_fungi_reviewed.dmnd' --query '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/fasta/V300043643_L3_DKWGS200331026-551_1.fasta' --out '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/diamond/V300043643_L3_DKWGS200331026-551_1.diamond.tsv' --threads 4 --evalue 1e-5 --max-target-seqs 1 --outfmt 6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle --tmpdir '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/tmp/V300043643_L3_DKWGS200331026-551_1'
rm -f '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/diamond/V300043643_L3_DKWGS200331027-552_1.diamond.tsv'; rm -rf '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/tmp/V300043643_L3_DKWGS200331027-552_1'; mkdir -p '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/tmp/V300043643_L3_DKWGS200331027-552_1'; diamond blastx --db '/scratch/prj/rosetree/Valentina/databases/uniprot_fungi/uniprot_fungi_reviewed.dmnd' --query '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/fasta/V300043643_L3_DKWGS200331027-552_1.fasta' --out '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/diamond/V300043643_L3_DKWGS200331027-552_1.diamond.tsv' --threads 4 --evalue 1e-5 --max-target-seqs 1 --outfmt 6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle --tmpdir '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/tmp/V300043643_L3_DKWGS200331027-552_1'
rm -f '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/diamond/V300043643_L3_DKWGS200331028-553_1.diamond.tsv'; rm -rf '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/tmp/V300043643_L3_DKWGS200331028-553_1'; mkdir -p '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/tmp/V300043643_L3_DKWGS200331028-553_1'; diamond blastx --db '/scratch/prj/rosetree/Valentina/databases/uniprot_fungi/uniprot_fungi_reviewed.dmnd' --query '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/fasta/V300043643_L3_DKWGS200331028-553_1.fasta' --out '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/diamond/V300043643_L3_DKWGS200331028-553_1.diamond.tsv' --threads 4 --evalue 1e-5 --max-target-seqs 1 --outfmt 6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle --tmpdir '/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/tmp/V300043643_L3_DKWGS200331028-553_1'
