#!/bin/bash -l
#SBATCH --job-name=VIRGO2_extract_viral
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=02:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=2
#SBATCH -p msc_appbio

set -euo pipefail

# ------------------------------------------------------------
# Extract viral/phage genes from compiled VIRGO2 matrix
# ------------------------------------------------------------

# Load conda (same method as working scripts)
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh

conda activate pythonday
export PATH="$CONDA_PREFIX/bin:$PATH"
hash -r

# ------------------------------------------------------------
# Diagnostics 
# ------------------------------------------------------------
echo "========== ENVIRONMENT CHECK =========="
echo "Host: $(hostname)"
echo "Date: $(date)"
echo "Python: $(which python)"
python --version

python -c "import pandas, numpy; print('PANDAS=', pandas.__version__); print('NUMPY=', numpy.__version__)"
echo "======================================="

# ------------------------------------------------------------
# Run extraction
# ------------------------------------------------------------
SCRIPT="/scratch/prj/rosetree/Valentina/scripts/virgo2/extract_viral_genes.py"

echo "[INFO] Running viral gene extraction..."
python "${SCRIPT}"

echo "[INFO] Job completed."
