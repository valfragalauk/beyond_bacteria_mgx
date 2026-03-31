#!/bin/bash -l
#SBATCH --job-name=KB_2sample_test
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=02:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8

set -euo pipefail

# Locations
PROJECT="/scratch/prj/rosetree/Valentina"
DB_DIR="${PROJECT}/databases/VMGC_DB/KrakenDB_VMGC_bracken"
OUT_DIR="${PROJECT}/results/test_2_sample_krak_brack"
mkdir -p "${OUT_DIR}"

# Sample files
S1="/scratch/prj/rosetree/recovered/kneaddata_M2020/Sequences/V300043643_L1_DKWGS200331001-510_1_kneaddata.fastq"
S2="/scratch/prj/rosetree/recovered/kneaddata_M2020/Sequences/V300043643_L3_DKWGS200331029-554_1_kneaddata.fastq"

# Safety checks
[[ -d "${DB_DIR}" ]] || { echo "[ERROR] DB not found: ${DB_DIR}"; exit 1; }
[[ -f "${S1}" ]] || { echo "[ERROR] Missing S1: ${S1}"; exit 1; }
[[ -f "${S2}" ]] || { echo "[ERROR] Missing S2: ${S2}"; exit 1; }

# Function: run kraken+bracken
run_one() {
  local fq="$1"
  local prefix="$2"

  echo "[INFO] Kraken2 on ${prefix}"
  kraken2 \
    --db "${DB_DIR}" \
    --threads "${SLURM_CPUS_PER_TASK}" \
    "${fq}" \
    --report "${OUT_DIR}/${prefix}.report" \
    --output "${OUT_DIR}/${prefix}.kraken"

  echo "[INFO] Bracken on ${prefix} (S/G/F)"
  for LVL in S G F; do
    bracken \
      -d "${DB_DIR}" \
      -i "${OUT_DIR}/${prefix}.report" \
      -o "${OUT_DIR}/${prefix}.bracken.${LVL}.tsv" \
      -l "${LVL}"
  done
}

run_one "${S1}" "sample1"
run_one "${S2}" "sample2"

echo "[INFO] Done. Example report head:"
head -n 20 "${OUT_DIR}/sample1.report" | cat
