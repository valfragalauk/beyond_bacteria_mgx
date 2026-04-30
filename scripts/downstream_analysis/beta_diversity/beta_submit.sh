#!/bin/bash

PROJECT_DIR="/scratch/prj/rosetree/Valentina"
CONFIG="${PROJECT_DIR}/scripts/downstream_analysis/beta_diversity/dataset_paths.tsv"
JOB_SCRIPT="${PROJECT_DIR}/scripts/downstream_analysis/beta_diversity/beta_diversity.sbatch"

tail -n +2 "${CONFIG}" | while IFS=$'\t' read -r DATASET_ID DOMAIN DATABASE MATRIX_PATH
do
  echo "Submitting ${DATASET_ID}"
  sbatch \
    --export=ALL,DATASET_ID="${DATASET_ID}",MATRIX_PATH="${MATRIX_PATH}" \
    "${JOB_SCRIPT}"
done
