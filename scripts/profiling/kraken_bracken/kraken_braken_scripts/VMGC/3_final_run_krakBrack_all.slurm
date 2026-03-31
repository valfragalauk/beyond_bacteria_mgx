#!/bin/bash -l
#SBATCH --job-name=KB_87
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=8

set -euo pipefail

# Locations
PROJECT="/scratch/prj/rosetree/Valentina"

# Bracken-ready Kraken DB 
DB_DIR="${PROJECT}/databases/VMGC_DB/KrakenDB_VMGC_bracken"

# list of 87 FASTQs 
LIST="${PROJECT}/sorted_data/final_fastq_87.txt"

# Output folder for this run
OUT_DIR="${PROJECT}/results/kraken_bracken_VMGC_87"
mkdir -p "${OUT_DIR}"

# Bracken settings
THRESH=10          # minimum reads threshold 
READ_LEN=100       # matches database100mers.kmer_distrib 
KMER_DIST="${DB_DIR}/database${READ_LEN}mers.kmer_distrib"

# Safety checks
echo "[INFO] DB:   ${DB_DIR}"
echo "[INFO] LIST: ${LIST}"
echo "[INFO] OUT:  ${OUT_DIR}"

[[ -d "${DB_DIR}" ]] || { echo "[ERROR] DB not found: ${DB_DIR}"; exit 1; }
[[ -f "${LIST}" ]]   || { echo "[ERROR] FASTQ list not found: ${LIST}"; exit 1; }
[[ -f "${KMER_DIST}" ]] || { echo "[ERROR] Missing Bracken kmer distrib: ${KMER_DIST}"; exit 1; }

# Count how many samples
N=$(grep -cv '^\s*$' "${LIST}" || true)
echo "[INFO] Samples in list: ${N}"

# Main loop to run kraken and bracken through all 87 samples
i=0
while IFS= read -r FASTQ; do
  # Skip blank lines
  [[ -z "${FASTQ// }" ]] && continue

  i=$((i+1))

  # Sample ID = filename without extension
  SAMPLE=$(basename "${FASTQ}" .fastq)

  # Per-sample output folder
  SDIR="${OUT_DIR}/${SAMPLE}"
  mkdir -p "${SDIR}"

  echo "------------------------------------------------------------"
  echo "[INFO] (${i}/${N}) Sample: ${SAMPLE}"
  echo "[INFO] FASTQ: ${FASTQ}"
  echo "[INFO] Output dir: ${SDIR}"

  # Check file exists before running
  if [[ ! -f "${FASTQ}" ]]; then
    echo "[WARN] Missing FASTQ (skipping): ${FASTQ}"
    continue
  fi

  # Kraken2
  echo "[INFO] Running Kraken2..."
  kraken2 \
    --db "${DB_DIR}" \
    --threads "${SLURM_CPUS_PER_TASK}" \
    "${FASTQ}" \
    --report "${SDIR}/${SAMPLE}.report" \
    --output "${SDIR}/${SAMPLE}.kraken"

  # Bracken 
  echo "[INFO] Running Bracken (threshold=${THRESH})..."
  for LVL in S G F; do
    bracken \
      -d "${DB_DIR}" \
      -i "${SDIR}/${SAMPLE}.report" \
      -o "${SDIR}/${SAMPLE}.bracken.${LVL}.tsv" \
      -l "${LVL}" \
      -t "${THRESH}"
  done

  # Done
  touch "${SDIR}/${SAMPLE}.DONE"

done < "${LIST}"

echo "============================================================"
echo "[INFO] All done. Outputs in: ${OUT_DIR}"
