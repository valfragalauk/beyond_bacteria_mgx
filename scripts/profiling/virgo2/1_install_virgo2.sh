#!/bin/bash -l
#SBATCH --job-name=install_virgo2
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=08:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=4

set -euo pipefail

# -----------------------------
# Clean environment setup
# -----------------------------
module purge
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate virgo2_env

# Make sure conda python stays first in PATH
export PATH="$CONDA_PREFIX/bin:$PATH"
hash -r

# Load HPC tools required by VIRGO2
module load bowtie2/2.5.1-gcc-13.2.0-python-3.11.6
module load samtools/1.17-gcc-13.2.0-python-3.11.6

# -----------------------------
# Sanity checks
# -----------------------------
echo "Python:"
which python
python --version

echo "Bowtie2:"
which bowtie2
bowtie2 --version

echo "Samtools:"
which samtools
samtools --version

echo "Git LFS:"
git lfs version

# -----------------------------
# Go to databases folder
# -----------------------------
cd /scratch/prj/rosetree/Valentina/databases

# Clone VIRGO2 if not already present
if [ ! -d "VIRGO2" ]; then
    git clone https://github.com/ravel-lab/VIRGO2.git
fi

cd VIRGO2

# Pull large files tracked with git-lfs
git lfs pull

# Install VIRGO2 resources and build the index
python VIRGO2.py install

echo "VIRGO2 installation completed successfully."
