#!/bin/bash -l
#SBATCH --job-name=vmgcTaxid
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=01:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1
#SBATCH -p msc_appbio

set -euo pipefail

PROJECT="/scratch/prj/rosetree/Valentina"
IN_DIR="${PROJECT}/databases/VMGC_DB"

# Kraken will only do taxonomy identification if the ids of the reference genomes form the DB contain a numerical ID. So we will make it.
# We will still keep the original name that came from the VMGC DB so we can compare afterwards

# Rewritten FASTAs will go here
OUT_DIR="${PROJECT}/databases/VMGC_DB_taxid_fastas"

# Custom taxonomy entries we’ll later append to Kraken taxonomy
TAX_DIR="${PROJECT}/databases/VMGC_custom_taxonomy"
mkdir -p "${OUT_DIR}" "${TAX_DIR}"

# Output mapping tables 
MAP="${TAX_DIR}/vmgc_name_to_taxid.tsv"
NODES="${TAX_DIR}/nodes.dmp"
NAMES="${TAX_DIR}/names.dmp"

: > "${MAP}"
: > "${NODES}"
: > "${NAMES}"

# Use a very high taxid range to avoid colliding with real NCBI taxids
START_TAXID=900000001

echo "Input VMGC FASTA dir: ${IN_DIR}"
echo "Output FASTA dir:     ${OUT_DIR}"
echo "Custom taxonomy dir:  ${TAX_DIR}"

# Find fasta files only 
mapfile -t FASTAS < <(find "${IN_DIR}" -maxdepth 1 -type f \( -name "*.fa" -o -name "*.fna" -o -name "*.fasta" \) | sort)

if [[ ${#FASTAS[@]} -eq 0 ]]; then
  echo "ERROR: No FASTA files found in ${IN_DIR}"
  exit 1
fi

taxid=${START_TAXID}

# For each viral genome file:Extract the filename and remove the .fa extension to get just the name
for f in "${FASTAS[@]}"; do
  base=$(basename "${f}")
  name="${base%.*}"  # remove .fa
# This script assigns each viral genome a fake ID (900000001, 
# 900000002, etc.) and rewrites the FASTA headers to include these IDs.
# It also creates taxonomy files (nodes.dmp, names.dmp) that tell Kraken2 
# what these IDs mean.
 
  # Record this virus name and its assigned taxid in mapping file
  echo -e "${name}\t${taxid}" >> "${MAP}"
  
  # Add entry to nodes.dmp (Kraken's taxonomy tree format)
  # Format: taxid | parent_id | rank | other_fields
  # We set parent to 1 (root) and rank to species
  echo -e "${taxid}\t|\t1\t|\tspecies\t|\t-\t|\t-\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t" >> "${NODES}"
  
  # Add entry to names.dmp (maps taxid to readable name)
  echo -e "${taxid}\t|\t${name}\t|\t\t|\tscientific name\t|" >> "${NAMES}"

  # Rewrite FASTA headers: append |kraken:taxid|TAXID to every header
  # Also keep the original header content for traceability.
  out_fa="${OUT_DIR}/${name}.fa"

  awk -v tid="${taxid}" '
    BEGIN{OFS=""}
    /^>/ {
      h=substr($0,2)
      print ">", h, "|kraken:taxid|", tid
      next
    }
    {print}
  ' "${f}" > "${out_fa}"

  taxid=$((taxid + 1))
done

#Print summary

echo "Done."
echo "FASTAs processed: ${#FASTAS[@]}"
echo "Example mapping:"
head -n 10 "${MAP}"
echo "Example rewritten header:"
awk 'NR==1{print; exit}' "${OUT_DIR}/$(basename "${FASTAS[0]}" .fa).fa"
