#!/bin/bash -l
#SBATCH --job-name=gb_https_add
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=48:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=4

set -euo pipefail

# PURPOSE:
# - Download GenBank fungi (complete genomes) and GenBank viral ICTV exemplars (complete genomes)
#   via HTTPS, then add sequences to a Kraken2 library.
# - Robust to occasional 403/rate-limits: retries with backoff and SKIPS failures (logs them).
# - Resume-safe: skips any genome already downloaded (.fna.gz exists and non-empty).
#
# INPUT LISTS (already created in manual_dl):
# - fungi_complete_https_paths.txt (587)
# - viral_ICTV_complete_paths.txt (15029)
#
# OUTPUT:
# - Downloaded .fna.gz files in DB/manual_dl/genomes/
# - Kraken library populated in DB/library/ via kraken2-build --add-to-library
# - Any failed URLs logged to DB/manual_dl/failed_downloads_urls.txt

# Activate environment with kraken2-build
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate kraken_env

DB="/scratch/prj/rosetree/Valentina/databases/Genbank"
MANUAL="${DB}/manual_dl"
GENOMES="${MANUAL}/genomes"

FUNGI_LIST="${MANUAL}/fungi_complete_https_paths.txt"
VIRAL_LIST="${MANUAL}/viral_ICTV_complete_paths.txt"

THREADS="${SLURM_CPUS_PER_TASK}"

echo "[INFO] DB:      ${DB}"
echo "[INFO] GENOMES: ${GENOMES}"
echo "[INFO] FUNGI:   ${FUNGI_LIST}"
echo "[INFO] VIRAL:   ${VIRAL_LIST}"
echo "[INFO] Threads: ${THREADS}"

# Safety checks
[[ -d "${DB}/taxonomy" ]] || { echo "[ERROR] Missing taxonomy folder at ${DB}/taxonomy"; exit 1; }
[[ -f "${FUNGI_LIST}" ]]  || { echo "[ERROR] Missing fungi list: ${FUNGI_LIST}"; exit 1; }
[[ -f "${VIRAL_LIST}" ]]  || { echo "[ERROR] Missing viral list: ${VIRAL_LIST}"; exit 1; }

mkdir -p "${GENOMES}"
touch "${MANUAL}/failed_downloads_urls.txt"

#download
download_one() {
  local base_url="$1"
  local outdir="$2"

  local asm
  asm="$(basename "${base_url}")"
  local fna="${asm}_genomic.fna.gz"
  local url="${base_url}/${fna}"
  local dest="${outdir}/${fna}"

  # Skip if already downloaded
  if [[ -s "${dest}" ]]; then
    echo "[SKIP] Already have ${dest}"
    return 0
  fi

  local ua="ValentinaFragala-KCL-KrakenDB/1.0 (contact: valentina@kcl.ac.uk)"
  local max_tries=8
  local try=1
  local wait=10

  while [[ $try -le $max_tries ]]; do
    echo "[DL] (try ${try}/${max_tries}) ${url}"

    if curl -L --fail \
        -A "${ua}" \
        --retry 3 --retry-delay 5 --retry-all-errors \
        -o "${dest}.part" "${url}"; then
      mv "${dest}.part" "${dest}"
      return 0
    fi

    echo "[WARN] Download failed (try ${try}). Backing off ${wait}s..."
    rm -f "${dest}.part" || true
    sleep "${wait}"

    try=$((try+1))
    wait=$((wait*2))
    if [[ $wait -gt 600 ]]; then wait=600; fi
  done

  echo "[ERROR] Giving up on: ${url}"
  echo "${url}" >> "${MANUAL}/failed_downloads_urls.txt"
  return 1
}

add_one_to_kraken_library() {
  local gz="$1"

  local fa="${gz%.gz}"
  if [[ ! -s "${fa}" ]]; then
    gunzip -c "${gz}" > "${fa}"
  fi

  kraken2-build --add-to-library "${fa}" --db "${DB}"

  # Remove decompressed fasta to save space (keep .gz)
  rm -f "${fa}"
}

process_list() {
  local listfile="$1"
  local label="$2"

  echo "============================================================"
  echo "[INFO] Processing ${label} list: ${listfile}"

  local n
  n=$(grep -cv '^\s*$' "${listfile}" || true)
  echo "[INFO] Entries: ${n}"

  local i=0
  while IFS= read -r base_url; do
    [[ -z "${base_url// }" ]] && continue
    i=$((i+1))

    echo "------------------------------------------------------------"
    echo "[INFO] (${i}/${n}) ${label}: ${base_url}"

    # Download; if it fails after retries, skip and continue
    if ! download_one "${base_url}" "${GENOMES}"; then
      echo "[WARN] Skipping (download failed): ${base_url}"
      continue
    fi

    local asm
    asm="$(basename "${base_url}")"
    local gz="${GENOMES}/${asm}_genomic.fna.gz"

    if [[ -s "${gz}" ]]; then
      add_one_to_kraken_library "${gz}"
    else
      echo "[WARN] Missing downloaded file (skipping): ${gz}"
      echo "${base_url}/${asm}_genomic.fna.gz" >> "${MANUAL}/failed_downloads_urls.txt"
      continue
    fi

    sleep 0.2

  done < "${listfile}"
}

# Fungi first (smaller), then viral (larger)
process_list "${FUNGI_LIST}" "FUNGI"
process_list "${VIRAL_LIST}" "VIRAL"

echo "============================================================"
echo "[DONE] Download + add-to-library finished."
echo "[INFO] Failed URL log (if any): ${MANUAL}/failed_downloads_urls.txt"
echo "[INFO] Example library files:"
find "${DB}/library" -maxdepth 2 -type f | head -n 20 || true
