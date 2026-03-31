#!/bin/bash -l
#SBATCH --job-name=virgo2_index
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=12:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=4

set -euo pipefail

# -----------------------------
# Clean environment setup
# -----------------------------
module purge
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate virgo2_env
export PATH="$CONDA_PREFIX/bin:$PATH"
hash -r

module load bowtie2/2.5.1-gcc-13.2.0-python-3.11.6
module load samtools/1.17-gcc-13.2.0-python-3.11.6

# -----------------------------
# Paths
# -----------------------------
DBDIR="/scratch/prj/rosetree/Valentina/databases/VIRGO2"
FASTA="${DBDIR}/FastaFiles/VIRGO2.fa"
INDEXDIR="${DBDIR}/Index"
PREFIX="${INDEXDIR}/VIRGO2"

mkdir -p "${INDEXDIR}"
cd "${DBDIR}"

echo "========== VIRGO2 index build =========="
echo "Date: $(date)"
echo "Host: $(hostname)"
echo "Working directory: $(pwd)"
echo "Python: $(which python)"
python --version
echo "bowtie2-build: $(which bowtie2-build)"
echo "samtools: $(which samtools)"
echo "Input FASTA: ${FASTA}"
echo "Index prefix: ${PREFIX}"
echo "Threads: ${SLURM_CPUS_PER_TASK}"
echo "========================================"

# -----------------------------
# Sanity checks
# -----------------------------
if [ ! -f "${FASTA}" ]; then
    echo "ERROR: FASTA file not found: ${FASTA}"
    exit 1
fi

echo "FASTA size:"
ls -lh "${FASTA}"

# -----------------------------
# Remove any previous/partial index files
# This makes the script safe to rerun cleanly.
# -----------------------------
echo "Removing old index files, if present..."
rm -f "${PREFIX}".*.bt2

# -----------------------------
# Build the Bowtie2 index
# -----------------------------
echo "Starting bowtie2-build..."
bowtie2-build --threads "${SLURM_CPUS_PER_TASK}" "${FASTA}" "${PREFIX}"

# -----------------------------
# Verify expected outputs
# -----------------------------
echo "Checking for completed index files..."

expected_files=(
    "${PREFIX}.1.bt2"
    "${PREFIX}.2.bt2"
    "${PREFIX}.3.bt2"
    "${PREFIX}.4.bt2"
    "${PREFIX}.rev.1.bt2"
    "${PREFIX}.rev.2.bt2"
)

for f in "${expected_files[@]}"; do
    if [ ! -s "${f}" ]; then
        echo "ERROR: Missing or empty expected index file: ${f}"
        exit 1
    fi
done

echo "Index build completed successfully."
ls -lh "${INDEXDIR}"
echo "Finished at: $(date)"
