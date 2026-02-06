#!/bin/bash -l
#SBATCH --job-name=checkVMGC
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=00:15:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=1
#SBATCH -p msc_appbio

set -euo pipefail

VMGC_DIR="/scratch/prj/rosetree/Valentina/databases/VMGC_DB"

echo "Searching for FASTA files..."
find "${VMGC_DIR}" -type f \( -name "*.fa" -o -name "*.fasta" -o -name "*.fna" \)

echo ""
echo "Checking FASTA headers for taxids..."

found_taxid=0

for f in $(find "${VMGC_DIR}" -type f \( -name "*.fa" -o -name "*.fasta" -o -name "*.fna" \)); do
  echo "---- ${f} ----"
  awk '/^>/{print; exit}' "${f}"

  if awk '/^>/{print; exit}' "${f}" | grep -Eq "taxid|kraken"; then
    echo "Taxid pattern found"
    found_taxid=1
  else
    echo "No taxid pattern detected"
  fi
done

if [[ "${found_taxid}" -eq 0 ]]; then
  echo ""
  echo "ERROR: No taxids detected in VMGC FASTA headers."
  echo "Kraken2 CANNOT classify without taxids."
  exit 1
fi

echo ""
echo "SUCCESS: Taxids detected. Safe to build Kraken DB."
