#!/bin/bash -l
#SBATCH --job-name=mkFastqList
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=00:10:00
#SBATCH --mem=2G
#SBATCH --cpus-per-task=1
#SBATCH -p msc_appbio

set -euo pipefail

PROJECT="/scratch/prj/rosetree/Valentina"
SEQDIR="/scratch/prj/rosetree/recovered/kneaddata_M2020/Sequences"

# Your wanted IDs live in data/
IDS="${PROJECT}/data/wanted_ids_87.txt"

# Output list of absolute FASTQ paths (only the 87 you want)
OUT="${PROJECT}/data/final_fastq_87.txt"

# Missing/ambiguous matches report
MISSING="${PROJECT}/data/missing_fastqs.txt"

mkdir -p "${PROJECT}/data"
: > "${OUT}"
: > "${MISSING}"

echo "Using ID list: ${IDS}"
echo "Sequences dir: ${SEQDIR}"

# ---- Safety checks ----
if [[ ! -f "${IDS}" ]]; then
  echo "ERROR: ID list not found at: ${IDS}"
  echo "Fix the IDS= path or move your file into ${PROJECT}/data/"
  exit 1
fi

# Count IDs (ignore blank lines)
n_ids=$(grep -vc '^[[:space:]]*$' "${IDS}" || true)
echo "Non-empty IDs in list: ${n_ids}"

# ---- Build final FASTQ list ----
while IFS= read -r id; do
  # Remove Windows CR if present + trim whitespace
  id=$(echo "${id}" | tr -d '\r' | xargs)

  [[ -z "${id}" ]] && continue

  # Find matching .fastq that starts with the ID
  mapfile -t matches < <(find "${SEQDIR}" \
    \( -name "${id}*.fastq" \) | sort)

  if [[ ${#matches[@]} -eq 0 ]]; then
    echo "${id}  -->  NOT FOUND" >> "${MISSING}"

  elif [[ ${#matches[@]} -gt 1 ]]; then
    echo "${id}  -->  MULTIPLE MATCHES" >> "${MISSING}"
    printf '%s\n' "${matches[@]}" >> "${MISSING}"

  else
    echo "${matches[0]}" >> "${OUT}"
  fi

done < "${IDS}"

echo "FASTQs written to OUT: $(wc -l < "${OUT}" | tr -d ' ')"
echo "Missing/ambiguous IDs: $(wc -l < "${MISSING}" | tr -d ' ')"

# Fail if anything missing
if [[ -s "${MISSING}" ]]; then
  echo "ERROR: Some IDs did not map cleanly to exactly one FASTQ."
  echo "See: ${MISSING}"
  echo "First few problems:"
  head -n 40 "${MISSING}"
  exit 1
fi

echo "SUCCESS ✅"
echo "First 5 FASTQs:"
head -n 5 "${OUT}"
