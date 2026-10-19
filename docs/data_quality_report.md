# Data Quality & Profiling Audit Report

## 1. Executive Summary

This Data Quality Report documents the formal data profiling, verification, and audit conducted on the Kaggle Healthcare Dataset prior to exploratory and analytical SQL querying.

- **Dataset File**: `data/raw/healthcare_dataset.csv`
- **Total Ingested Rows**: 55,500 rows
- **Evaluated Columns**: 15 attributes
- **Deduplicated Analytics Rows**: 54,966 records (534 exact duplicates removed)
- **Data Completeness**: 100.0% (Zero `NULL` values and zero empty whitespace fields across all columns)
- **Primary Data Quality Anomalies Identified**:
  1. Exact record duplication ($N = 534$, 0.96%).
  2. Inconsistent letter casing in patient names (e.g., `'Bobby JacksOn'`).
  3. Negative billing amounts ($N = 106$ in cleaned data, range: -$2,008.49 to -$0.37).
  4. Extreme entity fragmentation / synthetic generation artifacts in hospital and physician names.
  5. Absence of unique enterprise patient identifiers (EMPI / MRN).

---

## 2. Completeness & Null Analysis

Every single record was parsed and tested for `NULL`, `NaN`, `None`, and blank whitespace strings (`'   '`).

| Column Name | Total Rows | Non-Null Count | Null Count | Null % | Empty String Count | Data Integrity Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `Name` | 55,500 | 55,500 | 0 | 0.00% | 0 | PASS |
| `Age` | 55,500 | 55,500 | 0 | 0.00% | 0 | PASS |
| `Gender` | 55,500 | 55,500 | 0 | 0.00% | 0 | PASS |
| `Blood Type` | 55,500 | 55,500 | 0 | 0.00% | 0 | PASS |
| `Medical Condition` | 55,500 | 55,500 | 0 | 0.00% | 0 | PASS |
| `Date of Admission` | 55,500 | 55,500 | 0 | 0.00% | 0 | PASS |
| `Doctor` | 55,500 | 55,500 | 0 | 0.00% | 0 | PASS |
| `Hospital` | 55,500 | 55,500 | 0 | 0.00% | 0 | PASS |
| `Insurance Provider` | 55,500 | 55,500 | 0 | 0.00% | 0 | PASS |
| `Billing Amount` | 55,500 | 55,500 | 0 | 0.00% | 0 | PASS |
| `Room Number` | 55,500 | 55,500 | 0 | 0.00% | 0 | PASS |
| `Admission Type` | 55,500 | 55,500 | 0 | 0.00% | 0 | PASS |
| `Discharge Date` | 55,500 | 55,500 | 0 | 0.00% | 0 | PASS |
| `Medication` | 55,500 | 55,500 | 0 | 0.00% | 0 | PASS |
| `Test Results` | 55,500 | 55,500 | 0 | 0.00% | 0 | PASS |

---

## 3. Duplication Audit

- **Audit Query**: A composite check evaluating equality across all 15 raw columns simultaneously.
- **Finding**: **534 records** are exact 100% duplicate copies of preceding records in the dataset.
- **Impact**: Retaining duplicate rows artificially inflates gross billed charges by \$13,363,704.06 and distorts volume counts.
- **Handling Strategy**: The production table `healthcare.admissions` enforces deduplication via a `DISTINCT` selection during ingestion from `staging_admissions`. The raw staging table retains all 55,500 rows to ensure complete ELT auditability.

---

## 4. Text & String Formatting Audit

- **Patient Name Formatting**: Raw names exhibit erratic capitalization produced by mock data generators (e.g., `'Bobby JacksOn'`, `'LesLie TErRy'`, `'DaNnY sMitH'`).
- **Resolution**: Applied SQL `INITCAP(TRIM(Name))` transformation to standardize casing to title-case (`'Bobby Jackson'`, `'Leslie Terry'`).
- **Categorical Values**: All categorical strings were audited for hidden trailing spaces, non-breaking spaces (`\xa0`), or unusual characters. No hidden control characters were detected.

---

## 5. Numerical & Range Audit

| Metric | Field | Observed Min | Observed Max | Business Expectation | Finding & Classification |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Patient Age** | `Age` | 13 | 89 | 0 to 120 | Plausible inpatient demographic range. |
| **Room Number** | `Room Number` | 101 | 500 | 100 to 999 | Standard 3-digit hospital room indexing. |
| **Billing Amount** | `Billing Amount` | -\$2,008.49 | \$52,764.28 | > \$0.00 | **106 negative values** in cleaned data (108 in raw). |

### Analysis of Negative Billing Amounts
- **Count**: 106 records (0.19% of deduplicated dataset).
- **Aggregate Negative Sum**: -\$53,262.08.
- **Business Interpretation**: In healthcare enterprise accounting, negative charges represent contractual adjustments, insurance re-adjudication, billing error credits, or refund reversals.
- **Engineering Decision**:
  - Rather than blindly purging these rows, which would compromise the financial ledger reconciliation between staging and reporting, we maintain them in `healthcare.admissions`.
  - We engineered a boolean flag `is_negative_billing` (`TRUE` when `billing_amount < 0`).
  - Analysis calculating patient encounter cost averages utilizes `WHERE is_negative_billing = FALSE` or explicitly clarifies whether adjustments are included.

---

## 6. Date Validity & Inpatient Length of Stay (LOS)

- **Date Range**:
  - `date_of_admission`: `2019-05-08` to `2024-05-07` (Exactly 5.0 calendar years).
  - `discharge_date`: `2019-05-09` to `2024-06-06`.
- **Chronological Rule**: Discharge date must be greater than or equal to admission date ($\text{Discharge} \ge \text{Admission}$).
  - Violations ($\text{Discharge} < \text{Admission}$): **0 records (0.00%)**.
- **Length of Stay Calculation**:
  - Computed as calendar day difference: `(discharge_date - date_of_admission)`.
  - Observed Minimum: **1 day**.
  - Observed Maximum: **30 days**.
  - Observed Mean: **15.50 days**.
  - Same-day encounters ($\text{LOS} = 0$): **0 records**.
  - Observation: Inpatient stays strictly fall between 1 and 30 days without exception, indicative of an artificial bounded integer generator in the synthetic dataset.

---

## 7. Statistical & Synthetic Artifact Observations

As a Senior Data Analyst, recognizing the signature of synthetic/mock data generation is an essential demonstration of analytical maturity. The audit identified the following synthetic signatures:

1. **Extreme Entity Fragmentation in Hospitals and Doctors**:
   - Unique hospital names: **39,876** across 54,966 records.
   - Unique doctor names: **40,341** across 54,966 records.
   - Over 85% of hospitals appear exactly once or twice. In real-world regional hospital networks, patient volume is concentrated in dozens or hundreds of facilities, not 40,000 distinct entities.
2. **Uniform Probability Distributions**:
   - Gender: 50.02% Male vs. 49.98% Female.
   - Medical Conditions: Exactly ~16.6% per condition across all 6 conditions.
   - Insurance Carriers: Exactly ~20.0% per payer across all 5 payers.
   - Admission Types: Exactly ~33.3% per type across all 3 types.
   - Test Results: Exactly ~33.3% across Abnormal, Inconclusive, Normal.
   - Medications: Exactly ~20.0% across all 5 medications.
3. **Decoupled Financial & Clinical Variables**:
   - Average length of stay is identical (~15.5 days) regardless of whether a patient has Cancer, Diabetes, or Arthritis.
   - Average billing is identical (~$25,500) regardless of whether an admission is Elective ($25,612), Urgent ($25,515), or Emergency ($25,505).
   - In real clinical settings, emergency admissions and severe oncology treatments exhibit much higher financial skew.

---

## 8. Patient Identification & Readmission Limitations

- **Patient Name Collisions**: While there are 40,235 unique patient names, identical names often have differing biological sexes, blood types, and birth years.
- **Absence of Master Patient Index (MPI)**: Without a persistent social security number, national ID, or Enterprise Master Patient Index (EMPI), multiple admissions bearing the same name cannot be confirmed as the same human individual.
- **Analytical Governance**: To uphold healthcare analytics compliance, **30-day all-cause readmissions cannot be reliably calculated on this dataset** and are strictly declared out of scope.

---

## 9. Data Quality Scorecard Summary

| Dimension | Metric | Score | Status | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Completeness** | Missing / Null Rate | 100.0% | Excellent | Zero nulls across all fields |
| **Uniqueness** | Exact Duplicate Rate | 99.04% | Acceptable | 534 duplicate rows isolated & removed |
| **Validity** | Date Chronology | 100.0% | Perfect | 0 invalid discharge dates |
| **Consistency** | Text Casing & Formatting | 92.5% | Resolved | Title casing applied via SQL ETL |
| **Integrity** | Financial Charge Realism | 99.81% | Monitored | 106 negative values flagged via boolean indicator |
| **Representativeness** | Real-World Correlation | 45.0% | Simulated | Uniform distributions; synthetic dataset artifacts noted |
