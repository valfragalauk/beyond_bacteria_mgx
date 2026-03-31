#!/bin/bash -l
#SBATCH --job-name=buildVMGCv2_bracken
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=08:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=8

set -euo pipefail

PROJECT="/scratch/prj/rosetree/Valentina"

# Rebuilding the Kraken DB for Bracken because the cleaned VMGC_DB no longer
# contains the original reference sequences (library/). Kraken does not need
# them for classification, but Bracken requires them to compute k-mer
# abundance distributions for abundance re-estimation.

# New DB directory
DB_DIR="${PROJECT}/databases/VMGC_DB/KrakenDB_VMGC_bracken"

# Inputs
IN_FASTA_DIR="${PROJECT}/databases/VMGC_DB/VMGC_DB_taxid_fastas"
VMGC_TAX_DIR="${PROJECT}/databases/VMGC_DB/VMGC_custom_taxonomy"

# accession map files from the old DB
OLD_DB_TAX="${PROJECT}/databases/VMGC_DB/accession2taxid"

mkdir -p "${DB_DIR}/taxonomy"

echo "[INFO] New DB: ${DB_DIR}"
echo "[INFO] FASTAs: ${IN_FASTA_DIR}"
echo "[INFO] VMGC taxonomy: ${VMGC_TAX_DIR}"

# Locating required accession2taxid files into the new DB taxonomy folder
echo "[INFO] Copy accession2taxid maps into new DB taxonomy folder"
cp "${OLD_DB_TAX}/nucl_gb.accession2taxid"  "${DB_DIR}/taxonomy/"
cp "${OLD_DB_TAX}/nucl_wgs.accession2taxid" "${DB_DIR}/taxonomy/"

# Copying custom VMGC taxonomy 
echo "[INFO] Copy VMGC nodes/names into new DB taxonomy folder"
cp "${VMGC_TAX_DIR}/nodes.dmp" "${DB_DIR}/taxonomy/nodes.dmp"
cp "${VMGC_TAX_DIR}/names.dmp" "${DB_DIR}/taxonomy/names.dmp"

# Adding VMGC FASTAs to the Kraken library
echo "[INFO] Add FASTAs to library"
find "${IN_FASTA_DIR}" -maxdepth 1 -type f -name "*.fa" -print0 \
  | xargs -0 -I{} -n1 kraken2-build --add-to-library {} --db "${DB_DIR}"

# Building the database
echo "[INFO] Build Kraken2 DB"
kraken2-build --build --db "${DB_DIR}" --threads "${SLURM_CPUS_PER_TASK}"

echo "[INFO] Done. Contents of DB dir:"
ls -lh "${DB_DIR}" | cat
echo "[INFO] Contents of DB library dir (should exist now):"
ls -lh "${DB_DIR}/library" | head -n 20
