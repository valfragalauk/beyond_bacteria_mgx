#!/bin/bash -l
#SBATCH --job-name=K2_GB
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=48:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=4

set -euo pipefail

# conda and location
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate kraken_env

# Locations
PROJECT="/scratch/prj/rosetree/Valentina"

# GenBank Kraken2 DB 
DB_DIR="${PROJECT}/databases/Genbank"

# list of 87 merged FASTQs
LIST="${PROJECT}/sorted_data/final_fastq_87.txt"

# Output folder for this run
OUT_DIR="${PROJECT}/results/kraken_Genbank_87"
mkdir -p "${OUT_DIR}"

# Safety checks
echo "[INFO] DB:   ${DB_DIR}"
echo "[INFO] LIST: ${LIST}"
echo "[INFO] OUT:  ${OUT_DIR}"

[[ -d "${DB_DIR}" ]] || { echo "[ERROR] DB not found: ${DB_DIR}"; exit 1; }
[[ -f "${LIST}" ]]   || { echo "[ERROR] FASTQ list not found: ${LIST}"; exit 1; }

# Confirm Kraken DB index exists
if ! ls "${DB_DIR}"/hash.k2d "${DB_DIR}"/taxo.k2d "${DB_DIR}"/opts.k2d >/dev/null 2>&1; then
  echo "[ERROR] Kraken DB index files not found in ${DB_DIR}"
  exit 1
fi

# Count samples
N=$(grep -cv '^\s*$' "${LIST}" || true)
echo "[INFO] Samples in list: ${N}"

# Main loop
i=0
while IFS= read -r FASTQ; do
  [[ -z "${FASTQ// }" ]] && continue
  i=$((i+1))

  # Clean sample name
  SAMPLE=$(basename "${FASTQ}")
  SAMPLE=${SAMPLE%.fastq.gz}
  SAMPLE=${SAMPLE%.fq.gz}
  SAMPLE=${SAMPLE%.fastq}
  SAMPLE=${SAMPLE%.fq}

  SDIR="${OUT_DIR}/${SAMPLE}"
  mkdir -p "${SDIR}"

  echo "------------------------------------------------------------"
  echo "[INFO] (${i}/${N}) Sample: ${SAMPLE}"
  echo "[INFO] FASTQ: ${FASTQ}"
  echo "[INFO] Output dir: ${SDIR}"

  if [[ ! -f "${FASTQ}" ]]; then
    echo "[WARN] Missing FASTQ (skipping): ${FASTQ}"
    continue
  fi

  echo "[INFO] Running Kraken2..."

  kraken2 \
    --db "${DB_DIR}" \
    --threads "${SLURM_CPUS_PER_TASK}" \
    "${FASTQ}" \
    --report "${SDIR}/${SAMPLE}.report" \
    --output "${SDIR}/${SAMPLE}.kraken"

  touch "${SDIR}/${SAMPLE}.DONE"

done < "${LIST}"

echo "============================================================"
echo "[INFO] All done. Outputs in: ${OUT_DIR}"
