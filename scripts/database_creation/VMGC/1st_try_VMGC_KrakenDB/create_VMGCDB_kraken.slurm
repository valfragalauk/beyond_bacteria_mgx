#!/bin/bash -l
#SBATCH --job-name=krakenDB_VMGC
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=6


set -euo pipefail

#location
PROJECT="/scratch/prj/rosetree/Valentina"
FA_DIR="${PROJECT}/databases/VMGC_DB/VMGC_DB_taxid_fastas"
TAX_DIR="${PROJECT}/databases/VMGC_DB/VMGC_custom_taxonomy"
DBDIR="${PROJECT}/databases/VMGC_DB/kraken2_vmgc_custom"

source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate kraken_env

# Safety checks
if [[ ! -f "${DBDIR}/seqid2taxid.map" ]]; then
  echo "ERROR: Missing ${DBDIR}/seqid2taxid.map"
  echo "Run the mapping job (10b_make_seqid2taxid_map) first."
  exit 1
fi

# taxonomy directory
mkdir -p "${DBDIR}/taxonomy"

# Minimal taxonomy root + custom VMGC taxonomy
cat > "${DBDIR}/taxonomy/nodes.dmp" <<'EOF'
1	|	1	|	no rank	|	-	|	-	|	0	|	0	|	0	|	0	|	0	|	0	|	0	|	0	|
EOF

cat > "${DBDIR}/taxonomy/names.dmp" <<'EOF'
1	|	root	|		|	scientific name	|
EOF

cat "${TAX_DIR}/nodes.dmp" >> "${DBDIR}/taxonomy/nodes.dmp"
cat "${TAX_DIR}/names.dmp" >> "${DBDIR}/taxonomy/names.dmp"

echo "Adding FASTAs to library (idempotent if already added, but safe)."
mapfile -t FASTAS < <(find "${FA_DIR}" -maxdepth 1 -type f \( -name "*.fa" -o -name "*.fna" -o -name "*.fasta" \) | sort)

for f in "${FASTAS[@]}"; do
  kraken2-build --add-to-library "${f}" --db "${DBDIR}"
done

echo "Building DB..."
kraken2-build --build --db "${DBDIR}" --threads "${SLURM_CPUS_PER_TASK}"

echo "Cleaning..."
kraken2-build --clean --db "${DBDIR}"

echo "DONE."
ls -lh "${DBDIR}" | head -n 30
