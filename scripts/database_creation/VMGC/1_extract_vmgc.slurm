#!/bin/bash -l
#SBATCH --job-name=extractVMGC
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=00:10:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=1
#SBATCH -p msc_appbio

set -euo pipefail

VMGC_DIR="/scratch/prj/rosetree/Valentina/databases/VMGC_DB"

cd "${VMGC_DIR}"

echo "Extracting VMGC virus..."
tar -xzf VMGC_virus.tar.gz

echo "Extracting VMGC eukaryocyte..."
tar -xzf VMGC_eukaryocyte.tar.gz

echo "Contents of ${VMGC_DIR}:"
ls -lh
