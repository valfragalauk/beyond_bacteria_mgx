# Beyond Bacteria: Investigating the Vaginal Mycobiome and Virome in Spontaneous Preterm Birth

This repository contains the code used for the analyses presented in the MSc dissertation:

**"Beyond Bacteria: Investigation of Fungal and Viral Biomarkers Associated with Spontaneous Preterm Birth Using Shotgun Metagenomics."**

The project investigates fungal and viral communities in the vaginal microbiome of Black women at high risk of spontaneous preterm birth (sPTB) using shotgun metagenomic sequencing, functional profiling and multi-omics integration.

---

## Repository Structure

```
.
├── krona/
│   └── Interactive Krona plots for visualising taxonomic classification results
│
├── scripts/
│   ├── profiling/
│   │   └── Taxonomic and functional profiling workflows
│   │
│   └── downstream_analysis/
│       └── Statistical analyses, visualisation, machine learning and multi-omics integration
│
└── README.md
```

---

## Folder Description

### `krona/`

Contains interactive Krona charts generated from the taxonomic profiling results. These can be opened in a web browser to explore fungal and viral taxonomic composition across samples.

---

### `scripts/`

Contains all scripts used throughout the analysis pipeline.

#### `profiling/`

Scripts used for initial processing and profiling of shotgun metagenomic data, including:

- Taxonomic classification
- Reference database construction
- Functional profiling


#### `downstream_analysis/`

Scripts used for downstream analyses, including:

- Data preprocessing
- Diversity analyses
- Differential abundance testing
- Correlation analyses
- Logistic regression
- Random Forest modelling
- Similarity Network Fusion (SNF)
- Statistical analyses
- Figure generation

---

---

## Notes

Software versions, analytical parameters and methodological details are described in the accompanying MSc dissertation.
