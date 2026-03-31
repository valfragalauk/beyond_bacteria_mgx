#!/bin/bash -l
#SBATCH --job-name=make_diamond_list
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=01:00:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=1
#SBATCH -p msc_appbio

set -euo pipefail

echo "start= $(date)"

LIST=/scratch/prj/rosetree/Valentina/sorted_data/final_fastq_87.txt
FASTA_DIR=/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/fasta
OUTDIR=/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/diamond
TMPBASE=/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/tmp
DB=/scratch/prj/rosetree/Valentina/databases/uniprot_fungi/uniprot_fungi_reviewed.dmnd

BATCHDIR=/scratch/prj/rosetree/Valentina/scripts/fungal_function/batches
COMMAND_FILE=${BATCHDIR}/diamond_commands.sh

mkdir -p "${BATCHDIR}"
mkdir -p "${OUTDIR}"
mkdir -p "${TMPBASE}"

# Start fresh each time so the file reflects the current missing samples only
rm -f "${COMMAND_FILE}"

# Read each FASTQ path from your selected 87-sample list
while IFS= read -r FASTQ; do

    # Skip blank lines
    if [[ -z "${FASTQ}" ]]; then
        continue
    fi

    SAMPLE=$(basename "${FASTQ}" _kneaddata.fastq)
    QUERY="${FASTA_DIR}/${SAMPLE}.fasta"
    OUTFILE="${OUTDIR}/${SAMPLE}.diamond.tsv"
    TMPDIR="${TMPBASE}/${SAMPLE}"

    # Skip if FASTA input is missing
    if [[ ! -f "${QUERY}" ]]; then
        echo "[WARN] Missing FASTA, not writing command for: ${SAMPLE}"
        continue
    fi

    # Skip samples already completed (non-empty output exists)
    if [[ -s "${OUTFILE}" ]]; then
        echo "[INFO] Already completed, skipping command: ${SAMPLE}"
        continue
    fi

    # Write one DIAMOND command line for this sample
    echo "rm -f '${OUTFILE}'; rm -rf '${TMPDIR}'; mkdir -p '${TMPDIR}'; diamond blastx --db '${DB}' --query '${QUERY}' --out '${OUTFILE}' --threads 4 --evalue 1e-5 --max-target-seqs 1 --outfmt 6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle --tmpdir '${TMPDIR}'" >> "${COMMAND_FILE}"

done < "${LIST}"

echo
echo "[INFO] Command file created: ${COMMAND_FILE}"
echo "[INFO] Number of commands written:"
wc -l "${COMMAND_FILE}"

echo "end= $(date)"
