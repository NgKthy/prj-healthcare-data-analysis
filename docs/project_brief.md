# Healthcare Data Analysis Using SQL — Project Brief

## 1. Executive Summary & Business Context

In contemporary healthcare administration, understanding operational volume, patient demographics, clinical condition distributions, resource utilization, and billing patterns is critical for sustainable hospital management and payer-provider contracting.

This project delivers a comprehensive, end-to-end analytical data pipeline and SQL analysis based on the **Healthcare Dataset** (originally compiled by Prasad Patil on Kaggle). The dataset simulates 55,500 patient admission records spanning five full calendar years (May 2019 through May 2024), tracking demographics, diagnoses, admissions, attending physicians, facilities, insurers, billing charges, and inpatient lengths of stay.

The objective of this project is to model, clean, profile, audit, and analyze healthcare operational records using **pure PostgreSQL**, establishing production-grade SQL standards, reproducible data transformation pipelines, automated quality assertions, and evidence-based business insights.

---

## 2. Core Business Objectives

1. **Operational Visibility**: Quantify inpatient admission volume, temporal admission trends, seasonality, and discharge patterns across 5 calendar years.
2. **Financial Analysis**: Analyze gross billing distributions across medical conditions, admission types, and insurance carriers, identifying cost concentration and high-cost outliers ($P_{95}$).
3. **Resource Utilization**: Measure inpatient Length of Stay (LOS) across demographic cohorts and clinical conditions to benchmark bed occupancy.
4. **Provider & Payer Dynamics**: Examine payer market share, hospital concentration, and physician workload distributions.
5. **Data Quality & Governance**: Implement robust data staging, automated data quality auditing, surrogate key generation, deduplication, and financial anomaly flags.

---

## 3. Stakeholders & Target Audience

| Stakeholder Role | Primary Interest | Key Decision Supported |
| :--- | :--- | :--- |
| **Hospital Operations Directors** | Admission capacity, length of stay (LOS), room allocation | Staffing, bed management, elective surgery scheduling |
| **Chief Financial Officers (CFO) / Revenue Cycle Managers** | Gross billing amounts, payer concentration, high-cost outlier cases | Payer contract negotiation, cash flow forecasting, reserve allocation |
| **Clinical Quality Committees** | Test result distributions, medication patterns, admission urgency | Care pathway standardization, inpatient safety monitoring |
| **Data Analytics Hiring Managers** | SQL fluency, dimensional modeling, data governance, portfolio rigor | Hiring evaluation for Junior / Mid-Level Data Analyst roles |

---

## 4. Dataset Scope & Boundaries

- **Source**: Kaggle Healthcare Dataset (simulated records for analytical benchmarking).
- **Timeframe**: Admissions from **May 8, 2019** to **May 7, 2024**; Discharges through **June 6, 2024**.
- **Volume**: Exactly 55,500 raw records; 54,966 unique cleaned admission records following deduplication.
- **Attributes**: 15 primary attributes covering patient demographics, clinical diagnosis, hospital encounter, provider/physician, financial billing, and pharmacological regimen.

---

## 5. Six Business Analytical Question Domains

### Domain 1: Patient Demographics & Cohort Profile
- What is the overall age distribution of admitted patients?
- How is admission volume distributed across pediatric (<18), young adult (18-35), adult (36-50), middle-aged (51-65), and senior (65+) cohorts?
- What are the gender and blood type proportions, and are there demographic skews across billing?

### Domain 2: Medical Conditions & Clinical Economics
- What is the volume and billing distribution across the six tracked conditions (Arthritis, Asthma, Cancer, Diabetes, Hypertension, Obesity)?
- Which conditions account for the largest proportion of total gross billing?
- Does average billing significantly diverge from median billing across conditions?

### Domain 3: Admission Patterns & Time Trends
- What is the breakdown of encounters by admission type (Elective, Emergency, Urgent)?
- How does admission volume trend over time by year and month?
- Are there visible seasonal admission spikes or annual fluctuations?

### Domain 4: Hospital & Physician Operations
- What is the distribution of volume and billing across treating hospitals?
- How concentrated is hospital volume, and what is the workload distribution among treating physicians?
- Who are the top 3 doctors by patient volume within each high-volume facility?

### Domain 5: Insurance & Payer Portfolio
- What is the market share and billing contribution of each insurance provider (Aetna, Blue Cross, Cigna, Medicare, UnitedHealthcare)?
- Are certain conditions over-represented in specific insurance payer pools?
- What is the financial exposure per insurance provider?

### Domain 6: Inpatient Length of Stay (LOS) & Resource Consumption
- What is the mean and median length of stay across different medical conditions and admission types?
- Is there a descriptive correlation between inpatient length of stay and total billing amount?
- What proportion of admissions exceed clinical stay thresholds (e.g., >20 days)?

---

## 6. Key Performance Indicators (KPIs)

| KPI Name | Formula / SQL Logic | Business Meaning |
| :--- | :--- | :--- |
| **Total Admissions** | `COUNT(admission_record_id)` | Overall encounter volume handled |
| **Total Gross Billing** | `SUM(billing_amount)` | Aggregate billed charges across all encounters |
| **Average Billing per Encounter** | `AVG(billing_amount)` | Mean financial intensity per admission |
| **Median Billing per Encounter** | `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY billing_amount)` | Robust central tendency resilient to outlier skew |
| **Average Length of Stay (ALOS)** | `AVG(discharge_date - date_of_admission)` | Mean bed-days occupied per encounter |
| **High-Cost Threshold ($P_{95}$)** | `PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY billing_amount)` | Cut-off defining top 5% most expensive admissions |
| **Emergency Encounter Rate** | `COUNT(*) FILTER (WHERE admission_type = 'Emergency') / COUNT(*)` | Proportion of acute, unscheduled admissions |
| **Negative Billing Encounter Rate** | `COUNT(*) FILTER (WHERE billing_amount < 0) / COUNT(*)` | Financial auditing flag for adjustments/reversals |

---

## 7. Technology Stack & Execution Environment

- **Database Engine**: PostgreSQL 16+
- **Dialect**: Pure ANSI SQL with PostgreSQL extensions (`DATE_TRUNC`, Window Functions, `PERCENTILE_CONT`, CTEs)
- **Data Pipeline**: Staging-to-Production ELT pattern
- **Database Client Options**: `psql` CLI, pgAdmin 4, DBeaver Universal Database Tool
- **Verification Engine**: Python 3.13 (Pandas, SQLite3 engine) for cross-verification of mathematical aggregates

---

## 8. Analytical Assumptions

1. **Encounter-Level Data**: Each record represents a distinct inpatient admission encounter.
2. **Surrogate Key Generation**: Due to the absence of a unique natural enterprise ID in the source CSV, an auto-incrementing `admission_record_id` is generated as the primary surrogate key.
3. **Calendar Day Difference for LOS**: Length of stay is calculated as the integer difference in days between `discharge_date` and `date_of_admission` ($LOS = \text{Discharge} - \text{Admission}$). A difference of 0 indicates same-day admission/discharge.
4. **Preservation of Audit Trail**: Negative billing amounts are flagged rather than silently deleted to preserve accounting ledger auditability.

---

## 9. Explicit Out-of-Scope Items

- **Readmission Rate Calculation**: Because patient names in simulated datasets have high collision rates and lack a reliable unique Patient Enterprise Master ID (EMPI) or Social Security Number, computing 30-day readmissions would produce false-positive pairings. Readmissions are formally declared out-of-scope.
- **Clinical Efficacy of Medication**: Observational co-occurrence of medication with discharge test results cannot establish pharmacological efficacy or therapeutic outcomes.
- **Net Hospital Revenue vs. Gross Charges**: Billing amount represents gross hospital chargemaster charges, not actual cash received, contractual allowances, or insurer reimbursement.

