#!/bin/bash -l
#SBATCH --job-name=K_B
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%A_%a.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%A_%a.err
#SBATCH --time=02:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=6
#SBATCH -p msc_appbio
#SBATCH --array=1-87

set -euo pipefail

PROJECT="/scratch/prj/rosetree/Valentina"
DBDIR="${PROJECT}/databases/kraken2_refseq_viral_fungi"

# This is the file you just created successfully
LIST="${PROJECT}/data/final_fastq_87.txt"

OUTDIR="${PROJECT}/results/taxonomy/kraken2_refseq_viral_fungi"
mkdir -p "${OUTDIR}/kraken" "${OUTDIR}/reports" "${OUTDIR}/bracken"

source ~/.bashrc
conda activate kraken_env

# Get the FASTQ for this array task
fastq=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${LIST}")

if [[ -z "${fastq}" ]]; then
  echo "ERROR: No FASTQ found for array index ${SLURM_ARRAY_TASK_ID}"
  exit 1
fi

if [[ ! -f "${fastq}" ]]; then
  echo "ERROR: FASTQ does not exist: ${fastq}"
  exit 1
fi

# Create a stable sample ID from filename (handles .fastq or .fastq.gz)
sample_id=$(basename "${fastq}")
sample_id=${sample_id%.fastq}
sample_id=${sample_id%.gz}

echo "Task ${SLURM_ARRAY_TASK_ID}"
echo "FASTQ: ${fastq}"
echo "Sample: ${sample_id}"

kraken_out="${OUTDIR}/kraken/${sample_id}.kraken"
report_out="${OUTDIR}/reports/${sample_id}.kreport"

# ---- Kraken2 classification ----
kraken2 \
  --db "${DBDIR}" \
  --threads "${SLURM_CPUS_PER_TASK}" \
  --report "${report_out}" \
  --output "${kraken_out}" \
  "${fastq}"

# ---- Bracken abundance re-estimation ----
# IMPORTANT: set READ_LEN to whatever you used when building Bracken.
READ_LEN=150

bracken -d "${DBDIR}" -i "${report_out}" -o "${OUTDIR}/bracken/${sample_id}.bracken.S.tsv" -r "${READ_LEN}" -l S
bracken -d "${DBDIR}" -i "${report_out}" -o "${OUTDIR}/bracken/${sample_id}.bracken.G.tsv" -r "${READ_LEN}" -l G

echo "DONE: ${sample_id}"
