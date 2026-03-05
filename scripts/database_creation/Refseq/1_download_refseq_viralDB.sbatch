#!/bin/bash -l
#SBATCH --job-name=get_k2_viral
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=01:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1
#SBATCH -p msc_appbio

set -euo pipefail

# location
BASE="/scratch/prj/rosetree/Valentina"
DBDIR="${BASE}/databases/RefSeq_Viral_20251015"
URL_TGZ="https://genome-idx.s3.amazonaws.com/kraken/k2_viral_20251015.tar.gz"

#conda

source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate kraken_env


mkdir -p "${DBDIR}"
cd "${DBDIR}"


#download

echo "[INFO] Downloading..."
wget -c "${URL_TGZ}"

echo "[INFO] Extracting..."
tar -xvzf "$(basename "${URL_TGZ}")"

echo "[INFO] Showing DB contents (top level):"
ls -lah

echo "[INFO] Quick check: kraken2-inspect reads the DB"
kraken2-inspect --db "${DBDIR}" | head -n 20

echo "[INFO] Done."
