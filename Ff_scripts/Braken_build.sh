#! /bin/bash -l

#SBATCH --output=BRACKEN-%j.out
#SBATCH --job-name=Bracken_DB
#SBATCH --partition=brc
#SBATCH --nodes=1
#SBATCH --ntasks=1
# #SBATCH --cpus-per-task=20 # set the number of threads
#SBATCH --cpus-per-task=10
#SBATCH --mem=64g

# we need to load kraken2 
module load apps/kraken2/2.0.8-beta

# add bracken path 
export PATH=/opt/apps/apps/bracken:$PATH

echo `date`
# Note that in this case we are not specifying -k or -l which are respectively for k-mer size (default 35) and length of sequence (default 100)

bracken-build -d DB_kraken_microbes  -t 10 

echo `date`
