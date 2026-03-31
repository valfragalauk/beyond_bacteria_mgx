#!/bin/bash -l
#SBATCH --job-name=dl_refseq_fungiprot
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=4

set -euo pipefail

# -------------------------------
# Load conda
# -------------------------------
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate diamond_env

BASE="/scratch/prj/rosetree/Valentina"
DBDIR="${BASE}/databases/diamond/refseq_fungal_proteins"
mkdir -p "${DBDIR}"
cd "${DBDIR}"

# -------------------------------
# Download RefSeq fungi assembly summary
# -------------------------------
wget -O assembly_summary_refseq_fungi.txt \
  https://ftp.ncbi.nlm.nih.gov/genomes/refseq/fungi/assembly_summary.txt

# Keep only real assembly lines and ftp paths
awk -F '\t' '
BEGIN{OFS="\t"}
!/^#/ && $20 != "na" {print $1, $8, $20}
' assembly_summary_refseq_fungi.txt > fungal_assemblies.tsv

echo "[INFO] Number of fungal assemblies with FTP paths:"
wc -l fungal_assemblies.tsv

mkdir -p protein_fastas

# -------------------------------
# Download protein FASTAs
# -------------------------------
# For each assembly FTP path, download the corresponding *_protein.faa.gz
while IFS=$'\t' read -r asm accession ftp_path; do
    base=$(basename "${ftp_path}")
    file="${base}_protein.faa.gz"
    url="${ftp_path}/${file}"

    echo "[INFO] Downloading: ${url}"
    wget -c -P protein_fastas "${url}" || echo "[WARN] Failed: ${url}"
done < fungal_assemblies.tsv

echo "[INFO] Download step finished"

# -------------------------------
# Check what was actually downloaded
# -------------------------------
find protein_fastas -name "*_protein.faa.gz" | wc -l

# Create a list of downloaded FASTAs
find "${DBDIR}/protein_fastas" -name "*_protein.faa.gz" | sort > fungal_protein_files.txt

if [[ ! -s fungal_protein_files.txt ]]; then
    echo "[ERROR] No fungal protein FASTA files downloaded."
    exit 1
fi

echo "[INFO] Downloaded fungal protein FASTAs:"
head fungal_protein_files.txt
