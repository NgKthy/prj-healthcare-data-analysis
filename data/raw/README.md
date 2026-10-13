# Raw Data Directory

## Overview
This directory stores the immutable, original source dataset as ingested from the benchmark provider.

- **Primary Source File**: `healthcare_dataset.csv`
- **Origin**: Prasad Patil — Kaggle Healthcare Dataset (`https://www.kaggle.com/datasets/prasad22/healthcare-dataset`)
- **Format**: Comma-Separated Values (CSV), UTF-8 encoding
- **Record Count**: 55,501 lines (1 header line + 55,500 record rows)
- **File Size**: ~8.34 MB

## Data Governance & Integrity Rule
**DO NOT MODIFY OR EDIT THIS FILE.**
This file represents the raw extraction layer. All deduplication, casing standardization, type casting, and feature engineering are handled downstream via PostgreSQL staging scripts (`sql/02_staging.sql` and `sql/04_cleaning.sql`) or the automated pipeline script (`scripts/verify_and_compute_metrics.py`).

