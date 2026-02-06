#!/bin/bash -l
#SBATCH --job-name=simulate_fastq
#SBATCH --output=/scratch/prj/rosetree/Valentina/logs/%x_%j.out
#SBATCH --error=/scratch/prj/rosetree/Valentina/logs/%x_%j.err
#SBATCH --time=01:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1
#SBATCH -p msc_appbio

# move to project root so relative paths work
cd /scratch/prj/rosetree/Valentina

# ensure output directory exists
mkdir -p sample_data/simulated_reads

# running kraken simulator to turn the test fasta files into fastq files so they represent the real data fastq files
perl scripts/simulator.pl \
  sample_data/COVID_19.fa \
  sample_data/HIV_1.fa \
  > sample_data/simulated_reads/tutorial_reads.fastq
