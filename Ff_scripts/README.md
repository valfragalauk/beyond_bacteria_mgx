Flavia's quick notes 

Build using the Kraken_build.sh (edit as needed) 

When you build Kraken there are some known issues. I have linked some on the CREATE forum https://forum.er.kcl.ac.uk/t/kraken2-metagenomics/232


Make sure that you don't run the clean up step before you are done building Braken




For Braken, once you have run Kraken you can do the following: 


```bash
for name in *.kraken
do 
braken -d ../../virus_braken/ -i $name  -o ${name}_braken.species.txt -l S
done
```
