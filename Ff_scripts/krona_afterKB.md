### Krona after kraken2 /Braken

after you run kraken2 you might want to run krona on the output 

```bash
ktImportTaxonomy -s 3 -t 5 1366_LIB14449_LDI12062_AGTTCC_L001_report.txt -o 1366_14449.krona.html

```

the choice of the new flags is based on this[https://www.biostars.org/p/293561/] 

```
For example, let’s imagine we have a subset of a Kraken report that looks like this:

1.93    104417  104105  P   1224    Proteobacteria

0.18    96419   1968    P   201174  Actinobacteria

0.17    80738   10469   P   1239    Firmicutes
The columns of the report, according to the Kraken manual are:

1. Percentage of reads covered by the clade rooted at this taxon
2. Number of reads covered by the clade rooted at this taxon
3. Number of reads assigned directly to this taxon
4. A taxonomy rank code
5. NCBI taxonomy ID
6. indented scientific name
```

you can also use s1 


from the same post as above: 

*It makes much more sense to use the results from column 1 and 2 as these represent all taxa that are assigned to (for example) Proteobacteria and any descendant taxa of Proteobacteria, e.g. Acidithiobacillia and Alphaproteobacteria etc... If using column 3, you would be looking at k-mers that are only assigned to Proteobacteria and not to any descendant nodes. This is equivalent to only counting reads with this type of assignment in NCBI (see ORGANISM): https://www.ncbi.nlm.nih.gov/nuccore/X97116.1*




