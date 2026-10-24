# Data Dictionary — Healthcare Analytical Database

## Schema: `healthcare`

This dictionary documents the schema transformation from the raw staging table (`healthcare.staging_admissions`) to the production analytical table (`healthcare.admissions`).

---

## 1. Production Table: `healthcare.admissions`

| # | Standardized Column | Raw Column Name | PostgreSQL Data Type | Nullable | Primary / Foreign Key | Description & Business Meaning | Transformation & Data Quality Rules |
|---|---|---|---|---|---|---|---|
| 1 | `admission_record_id` | *(Generated)* | `BIGINT` (or `BIGSERIAL`) | `NOT NULL` | `PRIMARY KEY` | Unique technical surrogate key assigned to each unique admission encounter. | Generated monotonically during staging-to-production ETL. Guarantees deterministic record identification. |
| 2 | `patient_name` | `Name` | `VARCHAR(150)` | `NOT NULL` | None | Full reported name of the admitted patient. | Trimmed of leading/trailing whitespace. Normalized to Title Case via `INITCAP(TRIM(Name))`. Contains erratic casing in raw source (e.g., `'Bobby JacksOn'`). Note: Not unique. |
| 3 | `age` | `Age` | `SMALLINT` | `NOT NULL` | None | Age of patient in completed years at admission. | Cast from string to integer. Validated range: 13 to 89 years. No null or negative values detected. |
| 4 | `gender` | `Gender` | `VARCHAR(10)` | `NOT NULL` | None | Biological sex of the patient. | Trimmed. Validated values: `'Male'`, `'Female'`. Clean 50.02% / 49.98% split. |
| 5 | `blood_type` | `Blood Type` | `VARCHAR(5)` | `NOT NULL` | None | ABO blood group with Rh factor. | Trimmed. Validated against standard 8 serotypes: `'A+'`, `'A-'`, `'B+'`, `'B-'`, `'AB+'`, `'AB-'`, `'O+'`, `'O-'`. |
| 6 | `medical_condition` | `Medical Condition` | `VARCHAR(50)` | `NOT NULL` | None | Primary admitting diagnosis or chronic condition. | Trimmed. 6 distinct values: `'Arthritis'`, `'Asthma'`, `'Cancer'`, `'Diabetes'`, `'Hypertension'`, `'Obesity'`. |
| 7 | `date_of_admission` | `Date of Admission` | `DATE` | `NOT NULL` | None | Calendar date of inpatient hospital admission. | Converted to ISO-8601 `YYYY-MM-DD`. Validated range: `2019-05-08` to `2024-05-07`. |
| 8 | `doctor_name` | `Doctor` | `VARCHAR(150)` | `NOT NULL` | None | Attending or admitting physician name. | Trimmed of whitespace. Synthetic dataset exhibits very high cardinality (40,341 distinct names across 54,966 records). |
| 9 | `hospital_name` | `Hospital` | `VARCHAR(150)` | `NOT NULL` | None | Name of treating hospital or medical center. | Trimmed. High cardinality synthetic attribute (39,876 distinct facility names). |
| 10 | `insurance_provider` | `Insurance Provider` | `VARCHAR(50)` | `NOT NULL` | None | Commercial or government healthcare insurance carrier. | Trimmed. 5 distinct values: `'Aetna'`, `'Blue Cross'`, `'Cigna'`, `'Medicare'`, `'UnitedHealthcare'`. |
| 11 | `billing_amount` | `Billing Amount` | `NUMERIC(12, 2)` | `NOT NULL` | None | Total gross billed chargemaster charges for the encounter (USD). | Cast from floating point string; rounded to 2 decimal places. 106 records contain negative amounts (-$2,008.49 to -$0.37) flagged for audit. |
| 12 | `room_number` | `Room Number` | `INTEGER` | `NOT NULL` | None | Inpatient room number allocated during encounter. | Cast to integer. Range: 101 to 500. |
| 13 | `admission_type` | `Admission Type` | `VARCHAR(20)` | `NOT NULL` | None | Clinical urgency classification of admission. | Trimmed. 3 distinct values: `'Elective'`, `'Emergency'`, `'Urgent'`. |
| 14 | `discharge_date` | `Discharge Date` | `DATE` | `NOT NULL` | None | Calendar date when patient was discharged. | Converted to ISO-8601 `YYYY-MM-DD`. Validated range: `2019-05-09` to `2024-06-06`. Must be $\ge$ `date_of_admission`. |
| 15 | `medication` | `Medication` | `VARCHAR(50)` | `NOT NULL` | None | Primary pharmaceutical medication administered/prescribed. | Trimmed. 5 distinct values: `'Aspirin'`, `'Ibuprofen'`, `'Lipitor'`, `'Paracetamol'`, `'Penicillin'`. |
| 16 | `test_results` | `Test Results` | `VARCHAR(20)` | `NOT NULL` | None | Clinical diagnostic test outcome upon evaluation. | Trimmed. 3 distinct values: `'Abnormal'`, `'Inconclusive'`, `'Normal'`. |
| 17 | `length_of_stay_days` | *(Calculated)* | `INTEGER` | `NOT NULL` | None | Number of inpatient bed-days occupied. | Computed as `(discharge_date - date_of_admission)`. Range: 1 to 30 days. No negative or zero values in dataset. |
| 18 | `is_negative_billing` | *(Derived)* | `BOOLEAN` | `NOT NULL` | None | Audit flag identifying negative billing charges. | Computed as `CASE WHEN billing_amount < 0 THEN TRUE ELSE FALSE END`. Used to isolate accounting adjustments. |
| 19 | `age_group` | *(Derived)* | `VARCHAR(20)` | `NOT NULL` | None | Standardized demographic age bracket. | Categorized into `'< 18'`, `'18 - 35'`, `'36 - 50'`, `'51 - 65'`, `'65+'`. Facilitates demographic slicing. |

---

## 2. Staging Table: `healthcare.staging_admissions`

The staging table mirrors the exact format of the raw CSV file to allow unconstrained, lossless data ingestion:

```sql
CREATE TABLE healthcare.staging_admissions (
    raw_name               VARCHAR(255),
    raw_age                VARCHAR(50),
    raw_gender             VARCHAR(50),
    raw_blood_type         VARCHAR(50),
    raw_medical_condition  VARCHAR(255),
    raw_date_of_admission  VARCHAR(50),
    raw_doctor             VARCHAR(255),
    raw_hospital           VARCHAR(255),
    raw_insurance_provider VARCHAR(255),
    raw_billing_amount     VARCHAR(50),
    raw_room_number        VARCHAR(50),
    raw_admission_type     VARCHAR(50),
    raw_discharge_date     VARCHAR(50),
    raw_medication         VARCHAR(255),
    raw_test_results       VARCHAR(255)
);
```

---

## 3. Categorical Encodings & Value Domains

| Field | Allowed / Present Distinct Values | Cardinality |
| :--- | :--- | :--- |
| `gender` | `Female`, `Male` | 2 |
| `blood_type` | `A+`, `A-`, `AB+`, `AB-`, `B+`, `B-`, `O+`, `O-` | 8 |
| `medical_condition` | `Arthritis`, `Asthma`, `Cancer`, `Diabetes`, `Hypertension`, `Obesity` | 6 |
| `admission_type` | `Elective`, `Emergency`, `Urgent` | 3 |
| `insurance_provider` | `Aetna`, `Blue Cross`, `Cigna`, `Medicare`, `UnitedHealthcare` | 5 |
| `medication` | `Aspirin`, `Ibuprofen`, `Lipitor`, `Paracetamol`, `Penicillin` | 5 |
| `test_results` | `Abnormal`, `Inconclusive`, `Normal` | 3 |
| `age_group` | `< 18`, `18 - 35`, `36 - 50`, `51 - 65`, `65+` | 5 |
| `is_negative_billing` | `TRUE`, `FALSE` | 2 |

