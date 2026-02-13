#!/bin/bash -l

#SBATCH --output=krona_%j.out 
#SBATCH --job-name=ifi_krona
#SBATCH --nodes=1
#SBATCH --ntasks=1
# #SBATCH --mem-per-cpu=4G

echo "start=" `date`

# Set the pathway for loading the programme
# this was project specific you might not need to do this if you are uding conda for example

cd /scratch/groups/dixon_ngs/KronaTools-2.7.1/bin

# Run Krona
for i in `ls -1 *_report.txt | sed 's/\_report.txt//'`;
do
./ktImportTaxonomy -s 3 -t 5 ../../raw_files/ifi_kraken/${i}_report.txt -o ../../raw_files/ifi_kraken/${i}.krona.html
done

echo "end=" `date`
