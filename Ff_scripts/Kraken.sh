#!/bin/bash -l

#SBATCH --output=slurm-kraken-%j.out
#SBATCH --job-name=kraken_ff
#SBATCH --partition=brc
#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --mem-per-cpu=16G


echo "start=" `date`

# load Kraken
module load apps/kraken2/2.0.8-beta


#create a variable for the kraken db:
KRAKEN_DB=/scratch/groups/dixon_ngs/DB_kraken_virus/

# In the data/ directory
# be in the directory of the reads - run test in
# processed_reads

#paired reads -- need to be re-run for the unpaired reads spearate (new scritp R1 unpaired and anotehr R2 unpaired )


for i in `ls -1 *R1_paired.fastq.gz | sed 's/\_R1_paired.fastq.gz//'`
do
kraken2 --db $KRAKEN_DB --threads 16  --gzip-compressed  --use-names --paired  \
        $i\_R1_paired.fastq.gz $i\_R2_paired.fastq.gz --report flavia_kraken/${i}_report.txt  > flavia_kraken/${i}.kraken

done

echo "end" `date`
