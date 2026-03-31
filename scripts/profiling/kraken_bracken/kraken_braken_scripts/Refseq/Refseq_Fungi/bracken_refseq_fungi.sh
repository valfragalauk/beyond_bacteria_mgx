#!/bin/bash -l
#SBATCH --job-name=BR_RefF
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=12:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=1
#SBATCH -p msc_appbio

set -euo pipefail

source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate kraken_env

PROJECT="/scratch/prj/rosetree/Valentina"

DB_DIR="${PROJECT}/databases/RefSeq_Fungi"
K2_DIR="${PROJECT}/results/kraken_RefSeqFungi_87"
LIST="${PROJECT}/sorted_data/final_fastq_87.txt"

OUT_DIR="${PROJECT}/results/bracken_RefSeqFungi_87"
mkdir -p "${OUT_DIR}"

READ_LEN=100
LEVEL="G"

[[ -f "${DB_DIR}/database100mers.kmer_distrib" ]] || { echo "[ERROR] Missing ${DB_DIR}/database100mers.kmer_distrib"; exit 1; }
[[ -d "${K2_DIR}" ]] || { echo "[ERROR] Missing Kraken results dir: ${K2_DIR}"; exit 1; }

N=$(grep -cv '^\s*$' "${LIST}" || true)
echo "[INFO] Samples in list: ${N}"
echo "[INFO] Bracken level=${LEVEL}, read_len=${READ_LEN}"

i=0
while IFS= read -r FASTQ; do
  [[ -z "${FASTQ// }" ]] && continue
  i=$((i+1))

  SAMPLE=$(basename "${FASTQ}")
  SAMPLE=${SAMPLE%_kneaddata.fastq}

  REPORT="${K2_DIR}/${SAMPLE}/${SAMPLE}.report"
  [[ -f "${REPORT}" ]] || { echo "[WARN] Missing report (skipping): ${REPORT}"; continue; }

  OUT="${OUT_DIR}/${SAMPLE}.bracken_${LEVEL}.txt"
  DONE="${OUT_DIR}/${SAMPLE}.DONE"
  [[ -f "${DONE}" ]] && { echo "[INFO] (${i}/${N}) DONE exists, skipping ${SAMPLE}"; continue; }

  echo "[INFO] (${i}/${N}) Bracken fungi: ${SAMPLE}"
  bracken -d "${DB_DIR}" -i "${REPORT}" -o "${OUT}" -r "${READ_LEN}" -l "${LEVEL}"

  touch "${DONE}"
done < "${LIST}"

echo "[INFO] All done. Outputs in: ${OUT_DIR}"
