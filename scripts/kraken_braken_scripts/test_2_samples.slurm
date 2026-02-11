#!/bin/bash -l
#SBATCH --job-name=KB_2sample_test
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=02:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8

set -euo pipefail

#location
PROJECT="/scratch/prj/rosetree/Valentina"
DB_DIR="${PROJECT}/databases/KrakenDB_VMGC_v2"

OUT_DIR="${PROJECT}/sample_results/VMGCv2_test"
mkdir -p "${OUT_DIR}"

# Choosing a small test FASTQ 
R1="${PROJECT}/sample_data/your_sample_R1.fastq.gz"
R2="${PROJECT}/sample_data/your_sample_R2.fastq.gz"

# Safety checks
[[ -d "${DB_DIR}" ]] || { echo "[ERROR] DB not found: ${DB_DIR}"; exit 1; }
[[ -f "${R1}" ]] || { echo "[ERROR] Missing R1: ${R1}"; exit 1; }
[[ -f "${R2}" ]] || { echo "[ERROR] Missing R2: ${R2}"; exit 1; }

# Kraken2

echo "[INFO] Run Kraken2"
kraken2 \
  --db "${DB_DIR}" \
  --threads ${SLURM_CPUS_PER_TASK} \
  --paired "${R1}" "${R2}" \
  --report "${OUT_DIR}/test.report" \
  --output "${OUT_DIR}/test.kraken"

echo "[INFO] Run Bracken (example: species + genus + family)"

# Bracken
for LVL in S G F; do
  bracken \
    -d "${DB_DIR}" \
    -i "${OUT_DIR}/test.report" \
    -o "${OUT_DIR}/test.bracken.${LVL}.tsv" \
    -l "${LVL}"
done

echo "[INFO] Done. Outputs in ${OUT_DIR}"
echo "[INFO] Peek at top lines:"
head -n 20 "${OUT_DIR}/test.report" | cat
