#!/bin/bash -l
#SBATCH --job-name=diamond_fungi_all
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=48:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=8

set -euo pipefail

###############################################################################
# Load environment
###############################################################################
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate diamond_env

###############################################################################
# Define paths
###############################################################################
LIST=/scratch/prj/rosetree/Valentina/sorted_data/final_fastq_87.txt
FASTA_DIR=/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/fasta
OUTDIR=/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/diamond
TMPBASE=/scratch/prj/rosetree/Valentina/results/fungal_function/uniprot/tmp
DB=/scratch/prj/rosetree/Valentina/databases/uniprot_fungi/uniprot_fungi_reviewed.dmnd

mkdir -p "${OUTDIR}"
mkdir -p "${TMPBASE}"

###############################################################################
# Log software versions for reproducibility
###############################################################################
echo "[INFO] Job started: $(date)"
echo "[INFO] Host: $(hostname)"
echo "[INFO] Conda env: ${CONDA_DEFAULT_ENV:-not_set}"
echo "[INFO] Conda prefix: ${CONDA_PREFIX:-not_set}"
echo "[INFO] DIAMOND path: $(which diamond)"
echo "[INFO] DIAMOND version: $(diamond --version)"
echo "[INFO] DB: ${DB}"
echo "[INFO] FASTA dir: ${FASTA_DIR}"
echo "[INFO] Output dir: ${OUTDIR}"
echo

###############################################################################
# Safety checks
###############################################################################
if [[ ! -f "${LIST}" ]]; then
    echo "[ERROR] Input list not found: ${LIST}"
    exit 1
fi

if [[ ! -f "${DB}" ]]; then
    echo "[ERROR] DIAMOND database not found: ${DB}"
    exit 1
fi

TOTAL=$(wc -l < "${LIST}")
echo "[INFO] Total FASTQ entries in list: ${TOTAL}"
echo

###############################################################################
# Loop through all samples
###############################################################################
DONE_COUNT=0
SKIP_COUNT=0
MISSING_COUNT=0
FAIL_COUNT=0

while IFS= read -r FASTQ; do

    # Skip empty lines
    if [[ -z "${FASTQ}" ]]; then
        continue
    fi

    SAMPLE=$(basename "${FASTQ}" _kneaddata.fastq)
    QUERY="${FASTA_DIR}/${SAMPLE}.fasta"
    OUTFILE="${OUTDIR}/${SAMPLE}.diamond.tsv"
    TMPDIR="${TMPBASE}/${SAMPLE}"

    echo "============================================================"
    echo "[INFO] Sample: ${SAMPLE}"
    echo "[INFO] Original FASTQ listed: ${FASTQ}"
    echo "[INFO] FASTA query: ${QUERY}"
    echo "[INFO] Output file: ${OUTFILE}"
    echo "[INFO] Temp dir: ${TMPDIR}"

    # Check FASTA exists
    if [[ ! -f "${QUERY}" ]]; then
        echo "[WARN] FASTA file missing, skipping sample: ${QUERY}"
        ((MISSING_COUNT+=1))
        continue
    fi

    # Skip completed outputs
    if [[ -s "${OUTFILE}" ]]; then
        echo "[INFO] Output already exists and is non-empty, skipping: ${OUTFILE}"
        ((SKIP_COUNT+=1))
        continue
    fi

    mkdir -p "${TMPDIR}"

    echo "[INFO] Running DIAMOND blastx..."

    if diamond blastx \
        --db "${DB}" \
        --query "${QUERY}" \
        --out "${OUTFILE}" \
        --threads "${SLURM_CPUS_PER_TASK}" \
        --evalue 1e-5 \
        --max-target-seqs 1 \
        --outfmt 6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle \
        --tmpdir "${TMPDIR}"
    then
        if [[ -s "${OUTFILE}" ]]; then
            echo "[INFO] DIAMOND completed successfully for ${SAMPLE}"
            ((DONE_COUNT+=1))
        else
            echo "[WARN] DIAMOND finished but output file is empty: ${OUTFILE}"
            ((FAIL_COUNT+=1))
        fi
    else
        echo "[ERROR] DIAMOND failed for ${SAMPLE}"
        ((FAIL_COUNT+=1))
    fi

    echo "[INFO] Finished sample: ${SAMPLE}"
    echo

done < "${LIST}"

###############################################################################
# Final summary
###############################################################################
echo "============================================================"
echo "[INFO] Job finished: $(date)"
echo "[INFO] Completed samples: ${DONE_COUNT}"
echo "[INFO] Skipped existing outputs: ${SKIP_COUNT}"
echo "[INFO] Missing FASTA files: ${MISSING_COUNT}"
echo "[INFO] Failed/empty outputs: ${FAIL_COUNT}"
echo "============================================================"
