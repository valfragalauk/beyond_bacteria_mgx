#! /bin/bash -l
#SBATCH --nodes=1
#SBATCH --ntasks=1
# #SBATCH --cpus-per-task=20 # set the number of threads
#SBATCH --cpus-per-task=10
#SBATCH --mem=64g

#load the module
module add utilities/use.dev
module add apps/kraken2/2.0.8-beta

# make sure you are in the following directory /scratch/users/k1773872/ this is where 
# the DB_kraken_virus folder is located otherwise if you put the full path it did not work 

echo `date`
echo "Download taxonomy"

kraken2-build --download-taxonomy --use-ftp --db DB_kraken_virus/ --threads 10


echo "started downloading bacteria database"

kraken2-build --download-library bacteria --use-ftp --db DB_kraken_virus  --threads 12 --no-masking

echo `date`
echo "finished downloading bacteria database - start with archaea"

kraken2-build --download-library archaea --db DB_kraken_virus  --threads 12 --no-masking -use-ftp

echo `date`
echo "done with archaea - start fungi"

kraken2-build --download-library fungi  --db DB_kraken_virus  --threads 12 --no-masking -use-ftp

echo `date`
echo "done with fungi - download virus"

kraken2-build --download-library viral  --db DB_kraken_virus  --threads 12 --no-masking -use-ftp

echo `date`
echo "build database"

kraken2-build --build --db DB_kraken_virus  --threads 10

echo `date`
echo "done building - time to clean"

# NOTE : if you want to run BRAKEN you will have to skip this next step 

kraken2-build --clean --db DB_kraken_virus  --threads 10

echo `date`
