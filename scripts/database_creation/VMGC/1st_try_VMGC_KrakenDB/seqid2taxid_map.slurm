#!/bin/bash -l
#SBATCH --job-name=vmgcMap
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=00:30:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=1
#SBATCH -p msc_appbio

set -euo pipefail

#location
PROJECT="/scratch/prj/rosetree/Valentina"
FA_DIR="${PROJECT}/databases/VMGC_DB/VMGC_DB_taxid_fastas"
DBDIR="${PROJECT}/databases/VMGC_DB/kraken2_vmgc_custom"

mkdir -p "${DBDIR}"

OUTMAP="${DBDIR}/seqid2taxid.map"
: > "${OUTMAP}"

echo "Building seqid2taxid map from FASTAs in: ${FA_DIR}"
echo "Output: ${OUTMAP}"

# For each FASTA header, extract:
#   seqid = first token after '>' (up to whitespace)
#   taxid = number after '|kraken:taxid|'
# Output format :<seqid>\t<taxid>

find "${FA_DIR}" -maxdepth 1 -type f \( -name "*.fa" -o -name "*.fna" -o -name "*.fasta" \) | sort | \
while read -r f; do
  echo "Scanning: $(basename "$f")"
  awk '
    /^>/{
      # remove leading >
      header=substr($0,2)

      # seqid is up to first whitespace
      split(header, a, /[ \t]/)
      seqid=a[1]

      # find taxid in seqid token
      # expecting ...|kraken:taxid|12345
      if (match(seqid, /\|kraken:taxid\|[0-9]+/)) {
        tax=substr(seqid, RSTART+14, RLENGTH-14)  # 14 = length("|kraken:taxid|")
        print seqid "\t" tax
      }
    }
  ' "$f" >> "${OUTMAP}"
done

echo "Done. Lines in map:"
wc -l "${OUTMAP}"

echo "First 5 lines:"
head -n 5 "${OUTMAP}"
