#!/bin/bash -l
#SBATCH --job-name=DIAMOND_Fungi
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8

set -euo pipefail

# Load conda
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate diamond_env

PROJECT="/scratch/prj/rosetree/Valentina"
DB="${PROJECT}/databases/diamond/refseq_fungal_proteins/refseq_fungal_proteins"
OUT_DIR="${PROJECT}/results/diamond/fungal"

mkdir -p "${OUT_DIR}"

# Require a batch list file as input
if [[ $# -lt 1 ]]; then
  echo "[ERROR] Usage: sbatch run_diamond_fungal_batch.sh <sample_list_file>"
  exit 1
fi

LIST="$1"

echo "[INFO] DB:   ${DB}.dmnd"
echo "[INFO] LIST: ${LIST}"
echo "[INFO] OUT:  ${OUT_DIR}"

[[ -f "${DB}.dmnd" ]] || { echo "[ERROR] DIAMOND fungal DB not found: ${DB}.dmnd"; exit 1; }
[[ -f "${LIST}" ]]    || { echo "[ERROR] FASTQ list not found: ${LIST}"; exit 1; }

N=$(grep -cv '^\s*$' "${LIST}" || true)
echo "[INFO] Samples in batch: ${N}"

i=0
while IFS= read -r FASTQ; do
  [[ -z "${FASTQ// }" ]] && continue
  i=$((i+1))

  SAMPLE=$(basename "${FASTQ}")
  SAMPLE=${SAMPLE%_kneaddata.fastq}
  SAMPLE=${SAMPLE%.fastq.gz}
  SAMPLE=${SAMPLE%.fq.gz}
  SAMPLE=${SAMPLE%.fastq}
  SAMPLE=${SAMPLE%.fq}

  SDIR="${OUT_DIR}/${SAMPLE}"
  mkdir -p "${SDIR}"

  OUT_TSV="${SDIR}/${SAMPLE}_fungal_diamond.tsv"
  DONE_FILE="${SDIR}/${SAMPLE}.DONE"

  echo "------------------------------------------------------------"
  echo "[INFO] (${i}/${N}) Sample: ${SAMPLE}"
  echo "[INFO] FASTQ: ${FASTQ}"
  echo "[INFO] Output dir: ${SDIR}"

  if [[ ! -f "${FASTQ}" ]]; then
    echo "[WARN] Missing FASTQ (skipping): ${FASTQ}"
    continue
  fi

  if [[ -f "${DONE_FILE}" ]]; then
    echo "[INFO] DONE exists (skipping): ${SAMPLE}"
    continue
  fi

  echo "[INFO] Running DIAMOND blastx against fungal proteins..."

  diamond blastx \
    --db "${DB}" \
    --query "${FASTQ}" \
    --out "${OUT_TSV}" \
    --outfmt 6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle \
    --evalue 1e-5 \
    --max-target-seqs 1 \
    --threads "${SLURM_CPUS_PER_TASK}" \
    --sensitive

  if [[ -s "${OUT_TSV}" ]]; then
    touch "${DONE_FILE}"
    echo "[INFO] Completed: ${SAMPLE}"
  else
    echo "[WARN] Output missing or empty for ${SAMPLE}"
  fi

done < "${LIST}"

echo "============================================================"
echo "[INFO] Batch complete. Outputs in: ${OUT_DIR}"
