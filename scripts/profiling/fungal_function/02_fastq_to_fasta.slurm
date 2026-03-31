#!/bin/bash -l
#SBATCH --job-name=fastq2fasta_all
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=04:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=1
#SBATCH -p msc_appbio

set -euo pipefail

# Load your shell settings and activate the conda environment
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate diamond_env

# Input list containing the 87 FASTQ file paths
LIST=/scratch/prj/rosetree/Valentina/sorted_data/final_fastq_87.txt

# Output directory for FASTA files
OUTDIR=/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/fasta

mkdir -p "${OUTDIR}"

echo "[INFO] Starting FASTQ to FASTA conversion"
echo "[INFO] Input list: ${LIST}"
echo "[INFO] Output directory: ${OUTDIR}"
echo "[INFO] Date: $(date)"
echo

# Safety check: make sure the list exists
if [[ ! -f "${LIST}" ]]; then
    echo "[ERROR] Input list not found: ${LIST}"
    exit 1
fi

# Count how many files are listed
TOTAL=$(wc -l < "${LIST}")
echo "[INFO] Total files listed: ${TOTAL}"
echo

# Loop through every FASTQ file in the list
while IFS= read -r FASTQ; do

    # Skip empty lines just in case
    if [[ -z "${FASTQ}" ]]; then
        continue
    fi

    # Check that the FASTQ file actually exists
    if [[ ! -f "${FASTQ}" ]]; then
        echo "[WARN] FASTQ file not found, skipping: ${FASTQ}"
        continue
    fi

    # Build a clean sample name by removing the ending suffix
    SAMPLE=$(basename "${FASTQ}" _kneaddata.fastq)

    # Define the output FASTA file name
    OUTFASTA="${OUTDIR}/${SAMPLE}.fasta"

    echo "[INFO] Converting sample: ${SAMPLE}"
    echo "[INFO] Input: ${FASTQ}"
    echo "[INFO] Output: ${OUTFASTA}"

    # Convert FASTQ to FASTA
    seqtk seq -A "${FASTQ}" > "${OUTFASTA}"

    # Check the output was created and is not empty
    if [[ -s "${OUTFASTA}" ]]; then
        echo "[INFO] Successfully created: ${OUTFASTA}"
    else
        echo "[WARN] Output FASTA is empty or missing: ${OUTFASTA}"
    fi

    echo "------------------------------------------------------------"

done < "${LIST}"

echo
echo "[INFO] FASTQ to FASTA conversion completed"
echo "[INFO] Date: $(date)"
