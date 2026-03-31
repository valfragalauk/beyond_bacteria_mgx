#!/bin/bash -l
#SBATCH --job-name=BR_GB
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=1
#SBATCH -p msc_appbio

set -euo pipefail

# Activate environment
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate kraken_env

PROJECT="/scratch/prj/rosetree/Valentina"

DB_DIR="${PROJECT}/databases/Genbank"
K2_DIR="${PROJECT}/results/kraken_Genbank_87"
LIST="${PROJECT}/sorted_data/final_fastq_87.txt"

OUT_DIR="${PROJECT}/results/bracken_Genbank_87"
mkdir -p "${OUT_DIR}"

READ_LEN=100
LEVEL="G"

echo "[INFO] DB: ${DB_DIR}"
echo "[INFO] Kraken reports: ${K2_DIR}"
echo "[INFO] Bracken output: ${OUT_DIR}"
echo "[INFO] Read length: ${READ_LEN}"
echo "[INFO] Level: ${LEVEL}"

[[ -f "${DB_DIR}/database100mers.kmer_distrib" ]] || { echo "[ERROR] Missing ${DB_DIR}/database100mers.kmer_distrib"; exit 1; }

N=$(grep -cv '^\s*$' "${LIST}" || true)
echo "[INFO] Samples in list: ${N}"

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

  REPORT="${K2_DIR}/${SAMPLE}/${SAMPLE}.report"
  OUT="${OUT_DIR}/${SAMPLE}.bracken_${LEVEL}.txt"
  DONE="${OUT_DIR}/${SAMPLE}.DONE"

  echo "------------------------------------------------------------"
  echo "[INFO] (${i}/${N}) Sample: ${SAMPLE}"
  echo "[INFO] Report: ${REPORT}"

  if [[ ! -f "${REPORT}" ]]; then
    echo "[WARN] Missing report (skipping): ${REPORT}"
    continue
  fi

  if [[ -f "${DONE}" ]]; then
    echo "[INFO] DONE exists (skipping): ${SAMPLE}"
    continue
  fi

  bracken \
    -d "${DB_DIR}" \
    -i "${REPORT}" \
    -o "${OUT}" \
    -r "${READ_LEN}" \
    -l "${LEVEL}"

  touch "${DONE}"

done < "${LIST}"

echo "============================================================"
echo "[DONE] All GenBank Bracken runs finished. Outputs in: ${OUT_DIR}"
