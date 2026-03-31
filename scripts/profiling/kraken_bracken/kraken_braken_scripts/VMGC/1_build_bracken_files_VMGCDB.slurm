#!/bin/bash -l
#SBATCH --job-name=brackenBuild_VMGCv2
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=04:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8

#Bracken needs a precomputed k-mer distribution file for the custom VMGC DB

set -euo pipefail

#Location

PROJECT="/scratch/prj/rosetree/Valentina"
DB_DIR="${PROJECT}/databases/VMGC_DB/KrakenDB_VMGC_bracken"

# read length used to build the kmer distribution for Bracken
# 100 is the default Bracken expectation 
READ_LEN=100

echo "[INFO] Building Bracken files for DB: ${DB_DIR}"
echo "[INFO] Read length: ${READ_LEN}"
echo "[INFO] Threads: ${SLURM_CPUS_PER_TASK}"

# Generating the database${READ_LEN}mers.kmer_distrib and other Bracken helper files in the DB directory
bracken-build \
  -d "${DB_DIR}" \
  -l "${READ_LEN}" \
  -t "${SLURM_CPUS_PER_TASK}"

echo "[INFO] Done. Check for output:"
ls -lh "${DB_DIR}/database${READ_LEN}mers.kmer_distrib" | cat
