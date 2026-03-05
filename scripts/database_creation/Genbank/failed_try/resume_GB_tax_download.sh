#!/bin/bash -l
#SBATCH --job-name=gbresume_tax_download
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=20:00:00
#SBATCH --mem=24G
#SBATCH --cpus-per-task=10

#resuming taxonomy download since time ran out

set -euo pipefail

#conda enviroment
source /software/spackages_v0_21_prod/apps/linux-ubuntu22.04-zen2/gcc-13.2.0/anaconda3-2022.10-5wy43yh5crcsmws4afls5thwoskzarhe/etc/profile.d/conda.sh
conda activate kraken_env

#location
DB=/scratch/prj/rosetree/Valentina/databases/Genbank

k2 download-taxonomy --db "${DB}"

# Resume viral download from GenBank
k2 download-library \
  --db "${DB}" \
  --library viral \
  --assembly-source genbank \
  --threads "${SLURM_CPUS_PER_TASK}" \
  --resume

# Resume fungi download from GenBank (if you also started/need it)
k2 download-library \
  --db "${DB}" \
  --library fungi \
  --assembly-source genbank \
  --threads "${SLURM_CPUS_PER_TASK}" \
  --resume

echo "Resume downloads finished."
